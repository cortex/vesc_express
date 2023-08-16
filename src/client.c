#include "st_types.h"
#include "vesc_c_if.h"

#include <ctype.h>
#include <rb.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
// #include <stddef.h>

HEADER;

#define STM32_UUID_8 ((uint8_t *)0x1FFF7A10)

#define COMMAND_NONE 0
#define COMMAND_PAUSE 1
#define COMMAND_UNPAUSE 2

#define MODE_NONE 0
#define MODE_SIM7000 1
#define MODE_SIM7070 2

#define SEND_BUFFER_UNITS 10  // 50  * 8 = 400 bytes.

#define PWR_GPIO 8
#define PWR_PORT GPIOB

// #define AT_DEBUG_LOG
#define AT_PURGE_TIMEOUT_MS 5
#define AT_READ_TIMEOUT_MS 600
#define AT_FIND_RESPONSE_TRIES 2

#define TCP_BUFFER_SIZE 256

// INT32_MAX = 2147483647
#define INT32_MAX_POW_10 1000000000

typedef struct {
    unsigned char *data;
    unsigned int size;
} send_unit_t;

typedef struct {
    lib_thread thread;
    bool paused;
    bool tcp_connected;

    lib_mutex lock;
    rb_t send_buffer;
    PACKET_STATE_t *p_state;
    volatile uint8_t cmd;
    volatile lbm_cid cmd_thread;

    uint32_t send_fails;
    uint32_t recv_fails;

    int mode;
    //  void (*data_recv_fun)(char *, int);
    //  void (*data_send_fun)(char *, int, send_unit_t *);

    size_t recv_size;
    bool recv_filled;
    char recv_buffer[TCP_BUFFER_SIZE];
} data;

// Called when code is stopped
static void stop(void *arg) {
    data *d = (data *)arg;

    if (!d)
        VESC_IF->printf("d is NULL");
    else if (!d->thread)
        VESC_IF->printf("thread is NULL");
    else {
        VESC_IF->request_terminate(d->thread);
    }
    VESC_IF->printf("Terminated");
}

/* **************************************************
 * UTILS
 */

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) >= (b) ? (a) : (b))

void swap(char *x, char *y) {
    char t = *x;
    *x = *y;
    *y = t;
}

static char *reverse(char *buffer, int i, int j) {
    while (i < j) {
        swap(&buffer[i++], &buffer[j--]);
    }

    return buffer;
}

static inline bool is_char_digit(const char c) { return c >= '0' && c <= '9'; }

//
/**
 * Calculate the amount of characters integer would have if formated as a base
 * 10 string.
 *
 * Potential optimization: https://stackoverflow.com/a/25934909/15507414
 */
static size_t int_base10_str_len(const int32_t value) {
    int32_t value_abs = value > 0 ? value : -value;

    int32_t power = 10;
    size_t len = 0;
    while (true) {
        len++;

        if (value_abs < power) {
            break;
        }

        if (power >= INT32_MAX_POW_10) {
            break;
        }
        power *= 10;
    }

    if (value_abs >= INT32_MAX_POW_10) {
        len++;
    }

    if (value < 0) {
        len++;
    }

    return len;
}

static char *int_to_ascii(int value, char *buffer, int base) {
    if (base < 2 || base > 32) {
        return buffer;
    }

    int n = abs(value);

    int i = 0;
    while (n) {
        int r = n % base;

        if (r >= 10) {
            buffer[i++] = 'A' + (r - 10);
        } else {
            buffer[i++] = '0' + r;
        }
        n = n / base;
    }

    if (i == 0) {
        buffer[i++] = '0';
    }

    if (value < 0 && base == 10) {
        buffer[i++] = '-';
    }
    buffer[i] = '\0';
    reverse(buffer, 0, i - 1);
    return &buffer[i];
}

/**
 * Parse integer from string. Integer string may be prefixed with either '-' or
 * '+'. 0 is returned if string contains invalid characters.
 */
static int ascii_to_int(const char *string) {
    size_t len = strlen(string);
    if (len == 0) {
        return 0;
    }

    size_t len_digits = len;
    if (string[0] == '-' || string[0] == '+') {
        len_digits -= 1;
    }

    int n = 0;
    int power = 1;

    for (size_t i = 0; i < len_digits; i++) {
        char digit = string[len - i - 1];
        if (!is_char_digit(digit)) {
            return 0;
        }

        n += (digit - '0') * power;

        power *= 10;
    }

    if (string[0] == '-') {
        n *= -1;
    }

    return n;
}

static char *uint8_to_hex(uint32_t value, char *buffer) {
    uint32_t n = value;

    for (int i = 0; i < 2; i++) {
        int r = n % 16;

        if (r >= 10) {
            buffer[i] = 65 + (r - 10);
        } else {
            buffer[i] = 48 + r;
        }
        n = n / 16;
    }

    buffer[2] = '\0';
    reverse(buffer, 0, 1);
    return &buffer[2];
}

static bool is_whitespace(char c) {
    return (
        (c == ' ') || (c == '\t') || (c == '\v') || (c == '\f') || (c == '\r')
        || (c == '\n')
    );
}

static bool strneq(const char *str1, const char *str2, const unsigned int n) {
    bool r = true;
    for (unsigned int i = 0; i < n; i++) {
        if (str1[i] != str2[i]) {
            r = false;
            break;
        }
    }
    return r;
}

bool one_of(const char *delims, char c) {
    bool eq = false;
    char curr = delims[0];
    int i = 0;
    while (curr != 0) {
        if (c == curr) {
            eq = true;
            break;
        }
        curr = delims[i++];
    }
    return eq;
}

static inline uint32_t time_now() { return VESC_IF->timer_time_now(); }

static inline float time_secs_since(const uint32_t timestamp) {
    return VESC_IF->timer_seconds_elapsed_since(timestamp);
}

static inline float time_ms_since(const uint32_t timestamp) {
    return VESC_IF->timer_seconds_elapsed_since(timestamp) * 1000.0;
}

/* **************************************************
 * LBM UTILS
 */

static inline lbm_value lbm_enc_bool(bool value) {
    return value ? VESC_IF->lbm_enc_sym_true : VESC_IF->lbm_enc_sym_nil;
}

/* **************************************************
 * UART
 */

// Read from uart until one of the characters in delim is found
// or the length len has been obtained.
// len must be <= the size of the buffer minus one (to account for the
// terminating null byte).
// Doesn't start writing until leading whitspace is passed.
// If buffer is null, then the characters are only read but not written to
// buffer.
static int uart_read_until_trim(
    char *buffer, const char *delim, const int len, const int timeout_ms
) {
    int sleep_count = 0;
    int n = 0;

    bool leading_whitespace = true;

    while (n < len && sleep_count < timeout_ms) {
        if (VESC_IF->should_terminate()) return 0;
        int res = VESC_IF->uart_read();
        if (res < 0) {
            sleep_count++;
            VESC_IF->sleep_ms(1);
            continue;
        }

        if (leading_whitespace && is_whitespace((char)res)) {
            continue;
        }
        leading_whitespace = false;

        if (one_of(delim, res)) {
            if (buffer) {
                buffer[n] = 0;
            }
            break;
        }
        if (buffer) {
            buffer[n] = (char)res;
        }
        if (n == len - 1) {
            if (buffer) {
                buffer[n + 1] = 0;
            }
            break;
        }
        n++;
        sleep_count = 0;
    }
    if (sleep_count == timeout_ms && buffer) {
        buffer[n] = 0;
    }
    return n;
}

// Read from uart until one of the characters in delim is found
// or the length len has been obtained.
// len must be <= the size of the buffer minus one (to account for the
// terminating null byte).
// If buffer is null, then the characters are only read but not stored anywhere.
static int uart_read_until(
    char *buffer, const char *delim, int len, const int timeout_ms
) {
    int sleep_count = 0;
    int n = 0;

    while (n < len && sleep_count < timeout_ms) {
        if (VESC_IF->should_terminate()) return 0;
        int res = VESC_IF->uart_read();
        if (res < 0) {
            sleep_count++;
            VESC_IF->sleep_ms(1);
            continue;
        }

        if (one_of(delim, res)) {
            if (buffer) {
                buffer[n] = 0;
            }
            break;
        }
        if (buffer) {
            buffer[n] = (char)res;
        }
        if (n == len - 1) {
            if (buffer) {
                buffer[n + 1] = 0;
            }
            break;
        }
        n++;
        sleep_count = 0;
    }
    if ((sleep_count == 2000 && buffer) || (len == 0)) {
        buffer[n] = 0;
    }
    return n;
}

static bool uart_write_string(const char *str) {
    return VESC_IF->uart_write((uint8_t *)str, strlen(str));
}

static bool uart_read_timeout(char *res, int timeout_ms) {
    int attempts = 0;
    int c = VESC_IF->uart_read();
    while (c < 0 && attempts < timeout_ms) {
        attempts++;
        VESC_IF->sleep_ms(1);
        c = VESC_IF->uart_read();
    }
    if (c >= 0) {
        *res = (char)c;
        return true;
    }
    return false;
}

/**
 * Read uart until no response has been found and the specified duration has
 * passed.
 *
 * \param timeout_ms The duration that to search for, in milliseconds. If a
 * string is being read while this timer runs out, that string will be read,
 * until no more characters are found.
 */
static void uart_purge(const unsigned int timeout_ms) {
    // while (true) {
    //     if (VESC_IF->uart_read() < 0) {
    //         uint32_t start = time_now();
    //         bool response_found = false;
    //         while ((unsigned int)time_ms_since(start) < timeout_ms) {
    //             if (VESC_IF->uart_read() >= 0) {
    //                 response_found = true;
    //                 break;
    //             }

    //             VESC_IF->sleep_ms(1);
    //         }

    //         if (!response_found) {
    //             break;
    //         }
    //     }
    // }
    uint32_t start = time_now();

    int read_char = -1;

    while (read_char >= 0 || (unsigned int)time_ms_since(start) < timeout_ms) {
        read_char = VESC_IF->uart_read();
        if (read_char < 0) {
            VESC_IF->sleep_ms(1);
        }
    }

#ifdef AT_DEBUG_LOG
    VESC_IF->printf(
        "Purging took %fms", (double)time_ms_since(start)
    );
#endif
}

/* **************************************************
 * AT functions
 */

static bool at_check_response_immediate(
    const char *expect, const int timeout_ms
) {
    size_t len = strlen(expect);
    char response[len + 1];

    uart_read_until_trim(response, "\n", len, timeout_ms);

    if (strneq(response, expect, len)) {
#ifdef AT_DEBUG_LOG
        VESC_IF->printf("found response: '%s'", response);
#endif
        return true;
    }

#ifdef AT_DEBUG_LOG
    VESC_IF->printf(
        "incorrect response found: '%s' (expect: '%s')\n", response, expect
    );
#endif
    return false;
}

static bool at_find_response(
    const char *expect, const int timeout_ms, bool report_errors
) {
    static const char error[] = "ERROR";
    size_t error_index = 0;

    size_t len = strlen(expect);

    bool first = true;
    char response[len + 1];
    char first_response[len + 1];
    size_t i;
    for (i = 1; i <= AT_FIND_RESPONSE_TRIES; i++) {
        int read_len = uart_read_until_trim(response, "\n", len, timeout_ms);

        if (first) {
            first = false;
            memcpy(first_response, response, len + 1);
        }

        if (strneq(response, expect, len)) {
#ifdef AT_DEBUG_LOG
            VESC_IF->printf("found response: '%s'", response);
#endif
            return true;
        }

        // detect 'ERROR' response
        size_t error_search_len = MIN(5 - error_index, len);
        if (strneq(response, error + error_index, error_search_len)) {
            error_index += error_search_len;

            if (error_index >= 5) {
                if (report_errors) {
                    VESC_IF->printf(
                        "found 'ERROR' response (expect: '%s')", expect
                    );
                }
                return false;
            }
        } else {
            error_index = 0;
        }

#ifdef AT_DEBUG_LOG
        VESC_IF->printf("found wrong response: '%s'", response);
#endif

        if (read_len != 0) {
            i = 0;
        }
    }

#ifdef AT_DEBUG_LOG
    VESC_IF->printf(
        "response not found, first was: '%s' (expect: '%s')\n", first_response,
        expect
    );
    VESC_IF->printf("i: %u", i);
#endif

    return false;
}

static const char *at_find_of_responses(
    const size_t count, const char *responses[count], const int timeout_ms
) {
    static const char error[] = "ERROR";
    size_t error_index = 0;

    size_t len = 0;
    for (size_t i = 0; i < count; i++) {
        size_t curr_len = strlen(responses[i]);
        if (curr_len > len) {
            len = curr_len;
        }
    }

    bool first = true;
    char response[len + 1];
    char first_response[len + 1];
    for (size_t i = 1; i <= AT_FIND_RESPONSE_TRIES; i++) {
        int read_len = uart_read_until_trim(response, "\n", len, timeout_ms);

        if (first) {
            first = false;
            memcpy(first_response, response, len + 1);
        }

        for (size_t j = 0; j < count; j++) {
            if (strneq(response, responses[j], strlen(responses[j]))) {
#ifdef AT_DEBUG_LOG
                VESC_IF->printf("found response: '%s'", responses[j]);
#endif
                return responses[j];
            }
        }

        // detect 'ERROR' response
        size_t error_search_len = MIN(5 - error_index, len);
        if (strneq(response, error + error_index, error_search_len)) {
            error_index += error_search_len;

            if (error_index >= 5) {
                VESC_IF->printf(
                    "found 'ERROR' response (expect[0]: '%s)", responses[0]
                );
                return false;
            }
        } else {
            error_index = 0;
        }

        // VESC_IF->printf("found wrong response: '%s'", response);

        if (read_len != 0) {
            i = 0;
        }
    }

#ifdef AT_DEBUG_LOG
    VESC_IF->printf(
        "response not found, first was: '%s' (expect[0]: '%s')\n",
        first_response, responses[0]
    );
#endif

    return false;
}

/* **************************************************
 * AT interface restoration
 */
static bool restore_at_if(void) {
    char linebuffer[20];
    int br;
    while (VESC_IF->uart_read() >= 0)
        ;  // purge
    uart_write_string("AT\r\n");
    br = uart_read_until_trim(linebuffer, "\n", 20, 2000);
    if (br > 0 && strneq("OK", linebuffer, 2)) {
        return true;
    }

    // try writing bytes
    for (int i = 0; i < 100; i++) {
        VESC_IF->uart_write((unsigned char *)"AAAAAAAAAA", 10);
        VESC_IF->uart_write((unsigned char *)"\r\n", 2);

        while (VESC_IF->uart_read() >= 0)
            ;  // purge
        uart_write_string("AT\r\n");
        br = uart_read_until_trim(linebuffer, "\n", 20, 2000);
        if (br > 0 && strneq("OK", linebuffer, 2)) {
            return true;
        }
    }
    return false;
}

/* **************************************************
 * Packet and data processing
 */

static void enqueue_data(unsigned char *payload, unsigned int size) {
    data *d = (data *)ARG;
    send_unit_t su;
    unsigned char *sd = VESC_IF->malloc(size);
    if (!sd) {
        return;
    }
    memcpy(sd, payload, size);
    su.data = sd;
    su.size = size;
    if (!rb_insert(&d->send_buffer, (void *)&su)) {
        d->send_fails++;
        VESC_IF->free(sd);
    }
}

static void send_packet(unsigned char *bytes, unsigned int len) {
    if (VESC_IF->should_terminate()) return;
    data *d = (data *)ARG;
    if (d) {
        VESC_IF->packet_send_packet(bytes, len, d->p_state);
    }
}

static void process_data_tcp(unsigned char *data, unsigned int size) {
    VESC_IF->commands_process_packet(data, size, send_packet);
}

// rb: ring buffer
static void rb_clear(void) {
    data *d = (data *)ARG;
    send_unit_t su;

    while (rb_pop(&d->send_buffer, (void *)&su)) {
        VESC_IF->free(su.data);
    }
}

static int tcp_read_data(uint8_t *buffer, int buffer_size, int n_bytes) {
    int sleep_count = 0;
    int i = 0;
    while (i < n_bytes && i < buffer_size && sleep_count < 100) {
        int res = VESC_IF->uart_read();
        if (res < 0) {
            sleep_count++;
            VESC_IF->sleep_ms(1);
            continue;
        }
        buffer[i] = (uint8_t)res;
        i++;
    }
    return i;
}

static void data_recv_fun(char *linebuffer, int size) {
    data *d = (data *)ARG;

    char buf[10];
    int_to_ascii(size, buf, 10);

    char *delim = "";
    char *response = "";
    int data_size_pos = 0;

    switch (d->mode) {
        case MODE_SIM7000: {
            while (VESC_IF->uart_read() >= 0)
                ;
            uart_write_string("AT+CIPRXGET=2,0,");
            uart_write_string(buf);
            uart_write_string("\r\n");
            delim = "\n";
            response = "+CIPRXGET: 2,";
            data_size_pos = 15;
        } break;
        case MODE_SIM7070: {
            while (VESC_IF->uart_read() >= 0)
                ;
            uart_write_string("AT+CARECV=0,");
            uart_write_string(buf);
            uart_write_string("\r\n");
            delim = ",";
            response = "+CARECV:";
            data_size_pos = 9;
        } break;
        default:
            return;
    }

    int br = uart_read_until_trim(linebuffer, delim, size, 2000);
    if (br > 0) {
        if (strneq(response, linebuffer, strlen(response))) {
            int n_bytes = atoi(&linebuffer[data_size_pos]);
            if (n_bytes > 0) {
                memset(linebuffer, 0, 100);
                int bytes_read =
                    tcp_read_data((unsigned char *)linebuffer, size, n_bytes);
                if (bytes_read == n_bytes) {
                    for (int i = 0; i < bytes_read; i++) {
                        VESC_IF->packet_process_byte(
                            (unsigned char)linebuffer[i], d->p_state
                        );
                    }
                }
            }
            br = uart_read_until_trim(linebuffer, "\n", size, 200);
            if (!strneq("OK", linebuffer, 2)) {
                d->recv_fails++;
                restore_at_if();
            }
        } else if (strneq("ERROR", linebuffer, 5)) {
            d->tcp_connected = false;
        } else {
            restore_at_if();
        }
    }
}

static void data_send_fun(char *linebuffer, int size, send_unit_t *su) {
    data *d = (data *)ARG;

    char *ok_string = "";
    char buf[10];
    int_to_ascii(su->size, buf, 10);

    switch (d->mode) {
        case MODE_SIM7000: {
            while (VESC_IF->uart_read() >= 0)
                ;
            uart_write_string("AT+CIPSEND=0,");
            uart_write_string(buf);
            uart_write_string("\r\n");
            ok_string = "SEND OK";
        } break;
        case MODE_SIM7070: {
            while (VESC_IF->uart_read() >= 0)
                ;
            uart_write_string("AT+CASEND=0,");
            uart_write_string(buf);
            uart_write_string("\r\n");
            ok_string = "OK";
        } break;
        default:
            return;
    }

    int count = 0;
    bool data_ok = false;
    char c;
    bool b = uart_read_timeout(&c, 100);
    while (b && count < 100) {
        if (c == '>') {
            data_ok = true;
            break;
        }
        count++;
        b = uart_read_timeout(&c, 100);
    }

    if (data_ok) {
        VESC_IF->uart_write(su->data, su->size);
    }

    int br = uart_read_until_trim(linebuffer, "\n", size, 2000);
    if (br > 0) {
        if (strneq(ok_string, linebuffer, strlen(ok_string))) {
        } else {
        }
    }
}

/* **************************************************
 * Thread
 */

static void thd(void *arg) {
    data *d = (data *)arg;
    char linebuffer[100];
    bool prev_connected = false;

    while (!VESC_IF->should_terminate()) {
        if (d->cmd) {
            switch (d->cmd) {
                case COMMAND_PAUSE:
                    d->paused = true;
                    restore_at_if();
                    VESC_IF->lbm_unblock_ctx_unboxed(
                        d->cmd_thread, VESC_IF->lbm_enc_sym_true
                    );
                    d->cmd_thread = -1;
                    d->cmd = 0;
                    break;
                case COMMAND_UNPAUSE: {
                    d->paused = false;
                    restore_at_if();
                    VESC_IF->lbm_unblock_ctx_unboxed(
                        d->cmd_thread, VESC_IF->lbm_enc_sym_true
                    );
                    d->cmd_thread = -1;
                    d->cmd = 0;
                    break;
                }
                default:
                    d->cmd = 0;
                    break;
            }
        }

        if (d->paused) {
            VESC_IF->sleep_ms(1);
            continue;
        }

        if (d->tcp_connected) {
            if (!prev_connected) {
                // VESC_IF->printf("TCP Connected");
            }

            if (!rb_is_empty(&d->send_buffer)) {
                send_unit_t su;
                // VESC_IF->printf("SENDING sendbuffer");
                while (rb_pop(&d->send_buffer, &su)) {
                    data_send_fun(linebuffer, 100, &su);
                    VESC_IF->free(su.data);
                }
            }
            data_recv_fun(linebuffer, 100);
        } else {
            if (prev_connected) {
                // VESC_IF->printf("TCP Disconnected");
            }
        }

        prev_connected = d->tcp_connected;
        VESC_IF->sleep_ms(1);
    }

    VESC_IF->printf("LEAVING THREAD");

    if (d) {
        rb_clear();
        // rb_free(&d->send_buffer);
        VESC_IF->free(d);
    }
}

/* **************************************************
 * TCP library
 */

static bool tcp_is_connected() {
    uart_purge(AT_PURGE_TIMEOUT_MS);

    uart_write_string("AT+CASTATE?\r\n");

    // ex: +CASTATE: 0,1\r
    // char response[15];
    // uart_read_until_trim(response, "\n", 14, AT_READ_TIMEOUT_MS);
    // if (!strneq(response, "+CASTATE: 0,1", 13)) {
    //     return false;
    // }
    const char *responses[] = {"+CASTATE: 0,", "OK"};
    const char *response =
        at_find_of_responses(2, responses, AT_READ_TIMEOUT_MS);
    if (!response || response == responses[1]) {
        if (response == responses[1]) {
            VESC_IF->printf("failed due to 'OK' response");
        }
        return false;
    }
    if (response == responses[0]) {
        char result = VESC_IF->uart_read();
        if (result != '1') {
            if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
                VESC_IF->printf("couldn't find final 'OK' response");
                return false;
            }

            return false;
        }
    }

    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
        VESC_IF->printf("couldn't find final 'OK' response");
        return false;
    }

    return true;
}

/**
 * Wait until a tcp connection has been established, or until the specificed
 * amount of milliseconds have passed.
 *
 * \param timeout_ms How many milliseconds to wait until considering the tcp
 * connection as not established. This is exact, taking the execution time into
 * account (in comparison to many other functions with a timeout_ms
 * argument...).
 *
 * \return bool indicating if `tcp_is_connected` returned true at any point in
 * the specified period.
 */
bool tcp_wait_until_connected(const unsigned int timeout_ms) {
    const float timeout_s = ((float)timeout_ms / 1000.0);

    uint32_t start = VESC_IF->timer_time_now();
    while (VESC_IF->timer_seconds_elapsed_since(start) < timeout_s) {
        if (tcp_is_connected()) {
            return true;
        }

        VESC_IF->sleep_ms(10);
    }

    return false;
}

/**
 * \return bool indicating if operation was successful.
 */
static bool tcp_disconnect() {
    // uart_purge();
    uart_purge(AT_PURGE_TIMEOUT_MS);

    uart_write_string("AT+CACLOSE=0\r\n");

    // char response[16];
    // uart_read_until_trim(response, "\n", 15, AT_READ_TIMEOUT_MS);
    // if (!strneq(response, "OK", 2)) {
    //     return false;
    // }
    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, false)) {
        return false;
    }

    return true;
}

/**
 * Connect to the given host and port.
 * Any currently open connection is automatically closed.
 *
 * \return bool indicating if operation was successful. (Note: a true result
 * does not guarantee a successfull connection, always check with
 * tcp_is_connected!)
 */
static bool tcp_connect_host(const char *hostname, const uint16_t port) {
    // disconnect in case there was already a connection.
    // if (tcp_is_connected()) {
    //     if (!tcp_disconnect()) {
    //         VESC_IF->printf("tcp_disconnect failed");
    //         return false;
    //     }
    // }
    tcp_disconnect();

    // longest value: 65536
    char port_str[6];
    int_to_ascii((int)port, port_str, 10);
    port_str[5] = '\0';

    // uint32_t start = time_now();
    uart_purge(AT_PURGE_TIMEOUT_MS);
    // at_find_response("OK", AT_READ_TIMEOUT_MS);
    // VESC_IF->printf("Searching for extra 'OK' took %fms",
    // (double)time_ms_since(start));

    // uart_purge();
    uart_write_string("AT+CAOPEN=0,0,\"TCP\",\"");
    uart_write_string(hostname);
    uart_write_string("\",");
    uart_write_string(port_str);
    uart_write_string("\r\n");

    // potential response: +CAOPEN: <0-12>,<0-27>\r
    // char response[16];
    // uart_read_until_trim(response, "\n", 15, AT_READ_TIMEOUT_MS);
    // if (!strneq(response, "+CAOPEN: 0,0", 12)) {
    //     response[15] = 0;
    //     VESC_IF->printf(
    //         "invalid response: '%s' (expect: '+CAOPEN: 0,0')\n", response
    //     );
    //     return false;
    // }
    if (!at_find_response("+CAOPEN: 0,", AT_READ_TIMEOUT_MS, true)) {
        VESC_IF->printf("failed to find '+CAOPEN: 0,'");
        return false;
    }
    char found = 0;
    uart_read_timeout(
        &found, 10
    );  // this 10 just *feels* like the right number ;)
    if (found != '0') {
        VESC_IF->printf(
            "invalid result '+CAOPEN: 0,%c', (char: %d)", found, found
        );
        VESC_IF->printf("next result: %d", VESC_IF->uart_read());
        return false;
    }

    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
        return false;
    }

    return true;
}

/**
 * Send string over the currently active tcp connection.
 *
 * \return bool indicating if the string was successfully sent.
 */
static bool tcp_send_str(const char *str) {
    size_t len = strlen(str);
    char len_str[int_base10_str_len(len) + 1];
    int_to_ascii(len, len_str, 10);

    uart_purge(AT_PURGE_TIMEOUT_MS);
    
    uart_write_string("AT+CASEND=0,");
    uart_write_string(len_str);
    uart_write_string("\r\n");

    // this seems like enough time, might need more though...
    VESC_IF->sleep_ms(10);

    // It seems safe to write send string before the modem has responded with
    // the prompt message.
    uart_write_string(str);

    // expected response: '> \r'
    if (!at_check_response_immediate("> ", AT_READ_TIMEOUT_MS)) {
        return false;
    }
    // char response[4];
    // uart_read_until_trim(response, "\n", 3, AT_READ_TIMEOUT_MS);
    // if (!strneq(response, "> ", 2)) {
    //     VESC_IF->printf("invalid response: '%s' (expect: '> ')\n", response);
    //     return false;
    // }

    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
        return false;
    }

    return true;
}

/**
 * Receive data over tcp if it there currently exist any data to be read,
 * without waiting for data to arrive.
 *
 * \param dest The buffer to store the read data inside. A terminating null byte
 * will always be written, unless an error occurs.
 * \param dest_size The allocated space for `dest`. `dest_size` minus one bytes
 * will be read (to account for the terminating null byte). Values above 1460
 * will be clamped (you can read at most 1459 bytes at once).
 * \return the amount of read bytes (excluding the terminating zero). -1 on
 * error.
 */
static ssize_t tcp_recv(char *dest, size_t dest_size) {
    size_t capacity = dest_size - 1;
    size_t capacity_str_len = int_base10_str_len(capacity);
    char capacity_str[capacity_str_len + 1];
    int_to_ascii(capacity, capacity_str, 10);

    uart_purge(AT_PURGE_TIMEOUT_MS);
    uart_write_string("AT+CARECV=0,");
    uart_write_string(capacity_str);
    uart_write_string("\r\n");

    // ex: +CARECV: 1460,...<data>...
    // char response[10];
    // uart_read_until_trim(response, " ", 9, AT_READ_TIMEOUT_MS);
    // VESC_IF->printf("response (+CARECV): %s", response);
    // if (!strneq(response, "+CARECV:", 8)) {
    //     response[9] = '\0';
    //     VESC_IF->printf(
    //         "invalid response: '%s' (expect: '+CARECV:')\n", response
    //     );
    //     return -1;
    // }
    if (!at_find_response("+CARECV: ", AT_READ_TIMEOUT_MS, true)) {
        return -1;
    }
    char response[10];
    uart_read_until(response, ",\r", 9, AT_READ_TIMEOUT_MS);
    response[9] = 0;

    for (size_t i = 0; i < strlen(response); i++) {
        if (!is_char_digit(response[i])) {
            VESC_IF->printf(
                "non-digit character: '%d' in response '%s'\n", response[i],
                response
            );
            return -1;
        }
    }
    size_t receive_len = ascii_to_int(response);

    if (receive_len >= dest_size) {
        return -1;
    }

    uart_read_until(dest, "", receive_len, AT_READ_TIMEOUT_MS);
    // VESC_IF->printf("response (dest): %s", dest);
#ifdef AT_DEBUG_LOG
    VESC_IF->printf(
        "received len: %u (actual len: %u)", receive_len, strlen(dest)
    );
#endif

    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
        return -1;
    }

    return (ssize_t)receive_len;
}

/**
 * Block until there is data to receive on the current tcp connection.
 *
 * \returns true if received data was found, meaning you can call tcp_recv,
 * false otherwise.
 */
static bool tcp_wait_for_recv(size_t tries) {
    char response[16];
    for (size_t i = 0; i < tries; i++) {
        uart_read_until_trim(response, "\n", 15, AT_READ_TIMEOUT_MS);
        if (strneq(response, "+CADATAIND: 0", 13)) {
            return true;
        }
        VESC_IF->printf("found '%s'\n", response);
        // if (response[0] == '\0') {
        //     return false;
        // }
    }

    return false;
}

// static ssize_t tcp_recv_allocate(char **dest) {

// }

/* **************************************************
 * Extensions
 */

/* signature: (ext-pause) */
static lbm_value ext_pause(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;
    lbm_value r_val = VESC_IF->lbm_enc_sym_nil;

    if (!d->cmd) {
        d->cmd = COMMAND_PAUSE;
        d->cmd_thread = VESC_IF->lbm_get_current_cid();
        VESC_IF->lbm_block_ctx_from_extension();
        r_val = VESC_IF->lbm_enc_sym_true;
    }

    return r_val;
}

/* signature: (ext-unpause) */
static lbm_value ext_unpause(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;
    lbm_value r_val = VESC_IF->lbm_enc_sym_nil;

    if (!d->cmd) {
        d->cmd = COMMAND_UNPAUSE;
        d->cmd_thread = VESC_IF->lbm_get_current_cid();
        VESC_IF->lbm_block_ctx_from_extension();
        r_val = VESC_IF->lbm_enc_sym_true;
    }
    return r_val;
}

/* signature: (ext-uart-write string) */
static lbm_value ext_uart_write(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_write");

    data *d = (data *)ARG;
    if (!d->paused) {
        return VESC_IF->lbm_enc_sym_nil;
    }

    if (argn != 1 || !VESC_IF->lbm_is_byte_array(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    char *command = VESC_IF->lbm_dec_str(args[0]);
    // VESC_IF->printf("Start writing");
    VESC_IF->uart_write((uint8_t *)command, strlen(command));
    // VESC_IF->printf("DONE writing");
    return VESC_IF->lbm_enc_sym_true;
}

// /* signature: (ext-set-connected) */
// static lbm_value ext_set_connected(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;

//     d->tcp_connected = true;
//     return VESC_IF->lbm_enc_sym_true;
// }

// Read line or at most `number` characters.
// Includes newline character.
/* signature: (ext-uart-readline dest len) */
static lbm_value ext_uart_readline(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_read");
    data *d = (data *)ARG;
    if (!d->paused) {
        return VESC_IF->lbm_enc_sym_nil;
    }
    if (argn != 2
        || !(
            VESC_IF->lbm_is_byte_array(args[0])
            || VESC_IF->lbm_is_symbol_nil(args[0])
        )
        || !VESC_IF->lbm_is_number(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }
    char *response = NULL;
    if (VESC_IF->lbm_is_byte_array(args[0])) {
        response = VESC_IF->lbm_dec_str(args[0]);
    }
    uint32_t len = VESC_IF->lbm_dec_as_u32(args[1]);

    int r = uart_read_until(response, "\n", len, 1000);
    return VESC_IF->lbm_enc_i(r);
}

// Read line or at most `number` characters, automatically trimming leading
// whitspace. Includes newline character.
/* signature: (ext-uart-readline dest len) */
static lbm_value ext_uart_readline_trim(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_read");
    data *d = (data *)ARG;
    if (!d->paused) {
        return VESC_IF->lbm_enc_sym_nil;
    }
    if (argn != 2
        || !(
            VESC_IF->lbm_is_byte_array(args[0])
            || VESC_IF->lbm_is_symbol_nil(args[0])
        )
        || !VESC_IF->lbm_is_number(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }
    char *response = NULL;
    if (VESC_IF->lbm_is_byte_array(args[0])) {
        response = VESC_IF->lbm_dec_str(args[0]);
    }
    uint32_t len = VESC_IF->lbm_dec_as_u32(args[1]);

    int r = uart_read_until_trim(response, "\n", len, 1000);
    return VESC_IF->lbm_enc_i(r);
}

// Read until encountering any charcater from `delim` or at most `delim`
// characters.
// Includes the found delim character.
/* signature: (ext-uart-read-until dest delim len) */
static lbm_value ext_uart_read_until(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_read");
    data *d = (data *)ARG;
    if (!d->paused) {
        return VESC_IF->lbm_enc_sym_nil;
    }
    if (argn != 3
        || !(
            VESC_IF->lbm_is_byte_array(args[0])
            || VESC_IF->lbm_is_symbol_nil(args[0])
        )
        || !VESC_IF->lbm_is_byte_array(args[1])
        || !VESC_IF->lbm_is_number(args[2])) {
        return VESC_IF->lbm_enc_sym_terror;
    }
    char *response = NULL;
    if (VESC_IF->lbm_is_byte_array(args[0])) {
        response = VESC_IF->lbm_dec_str(args[0]);
    }
    char *delim = VESC_IF->lbm_dec_str(args[1]);
    uint32_t len = VESC_IF->lbm_dec_as_u32(args[2]);

    int r = uart_read_until(response, delim, len, 1000);
    return VESC_IF->lbm_enc_i(r);
}

/* signature: (ext-uart-purge) */
static lbm_value ext_uart_purge(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    // VESC_IF->printf("uart_purge");
    while (VESC_IF->uart_read() >= 0) {
        // VESC_IF->printf("Purge");
    }
    return VESC_IF->lbm_enc_sym_true;
}

/* signature: (ext-get-uuid string number) */
static lbm_value ext_get_uuid(lbm_value *args, lbm_uint argn) {
    if (argn == 2) {
        if (VESC_IF->lbm_is_byte_array(args[0])
            && VESC_IF->lbm_is_number(args[1])) {
            int32_t array_n = VESC_IF->lbm_dec_as_i32(args[1]);
            char *array = VESC_IF->lbm_dec_str(args[0]);
            char *rest = array;
            if (array_n < 25) {
                return VESC_IF->lbm_enc_sym_nil;
            }
            for (int i = 0; i < 12; i++) {
                rest = uint8_to_hex(STM32_UUID_8[i], rest);
            }
            return args[0];
        }
    }
    return VESC_IF->lbm_enc_sym_terror;
}

// /* signature: (ext-tcp-send-string string) */
// static lbm_value ext_tcp_send_string(lbm_value *args, lbm_uint argn) {
//     if (argn == 1) {
//         VESC_IF->printf("Enqueueing string");
//         if (VESC_IF->lbm_is_byte_array(args[0])) {
//             char *str = VESC_IF->lbm_dec_str(args[0]);
//             int32_t len = strlen(str);
//             enqueue_data((unsigned char *)str, len + 1);
//             return VESC_IF->lbm_enc_sym_true;
//         }
//     }
//     return VESC_IF->lbm_enc_sym_nil;
// }

// /* signature: (ext-is-connected) */
// static lbm_value ext_is_connected(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;

//     if (d->tcp_connected) {
//         return VESC_IF->lbm_enc_sym_true;
//     }
//     return VESC_IF->lbm_enc_sym_nil;
// }

// /* signature: (ext-is-paused) */
// static lbm_value ext_is_paused(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;

//     if (d->paused) {
//         return VESC_IF->lbm_enc_sym_true;
//     }
//     return VESC_IF->lbm_enc_sym_nil;
// }

// /* signature: (ext-send-fails) */
// static lbm_value ext_send_fails(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;

//     return VESC_IF->lbm_enc_u(d->send_fails);
// }

// /* signature: (ext-recv-fails) */
// static lbm_value ext_recv_fails(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;

//     return VESC_IF->lbm_enc_u(d->recv_fails);
// }

// /* signature: (ext-sim7000-mode) */
// static lbm_value ext_sim7000_mode(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;
//     d->mode = MODE_SIM7000;
//     // d->data_send_fun = sim7000_data_send_fun;
//     // d->data_recv_fun = sim7000_data_recv_fun;

//     return VESC_IF->lbm_enc_sym_true;
// }

// /* signature: (ext-sim7070-mode) */
// static lbm_value ext_sim7070_mode(lbm_value *args, lbm_uint argn) {
//     (void)args;
//     (void)argn;
//     data *d = (data *)ARG;
//     d->mode = MODE_SIM7070;
//     // d->data_send_fun = sim7070_data_send_fun;
//     // d->data_recv_fun = sim7070_data_recv_fun;

//     return VESC_IF->lbm_enc_sym_true;
// }

static lbm_value ext_pwr_key(lbm_value *args, lbm_uint argn) {
    if (argn == 1 && VESC_IF->lbm_is_number(args[0])) {
        lbm_int pwr = VESC_IF->lbm_dec_as_i32(args[0]);
        if (pwr) {
            VESC_IF->set_pad(GPIOD, 8);
        } else {
            VESC_IF->clear_pad(GPIOD, 8);
        }
        return VESC_IF->lbm_enc_sym_true;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-is-connected)
 */
static lbm_value ext_tcp_is_connected(lbm_value *args, lbm_uint argn) {
    (void)args;

    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (tcp_is_connected()) {
        return VESC_IF->lbm_enc_sym_true;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-wait-until-connected timeout-ms)
 */
static lbm_value ext_tcp_wait_until_connected(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_number(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    unsigned int timeout_ms = VESC_IF->lbm_dec_as_u32(args[0]);
    bool result = tcp_wait_until_connected(timeout_ms);

    return lbm_enc_bool(result);
}

/**
 * signature: (tcp-disconnect hostname port)
 */
static lbm_value ext_tcp_disconnect(lbm_value *args, lbm_uint argn) {
    (void)args;

    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (tcp_disconnect()) {
        return VESC_IF->lbm_enc_sym_true;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-connect-host hostname port)
 */
static lbm_value ext_tcp_connect_host(lbm_value *args, lbm_uint argn) {
    if (argn != 2 || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_number(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    char *hostname = VESC_IF->lbm_dec_str(args[0]);
    uint16_t port = (uint16_t)VESC_IF->lbm_dec_as_u32(args[1]);

    bool result = tcp_connect_host(hostname, port);

    if (result) {
        return VESC_IF->lbm_enc_sym_true;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-send-str string)
 *
 * Send string over current tcp connection, returning bool indicating success.
 */
static lbm_value ext_tcp_send_str(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_byte_array(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    char *str = VESC_IF->lbm_dec_str(args[0]);

    bool result = tcp_send_str(str);

    return lbm_enc_bool(result);
}

/**
 * signature: (tcp-recv-single len)
 *
 * Receive single up to `len` bytes long string from the current tcp connection.
 * Does not wait for data to come in.
 */
static lbm_value ext_tcp_recv_single(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_number(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    size_t size = VESC_IF->lbm_dec_as_u32(args[0]) + 1;

    if (size > TCP_BUFFER_SIZE) {
        return VESC_IF->lbm_enc_sym_eerror;
    }

    data *d = (data *)ARG;

    char str[size];
    str[0] = '\0';
    ssize_t len;

    // bool used_buffered_result = false;
    if (d->recv_size != 0) {
        d->recv_size = 0;
        // used_buffered_result = true;

        if (d->recv_size > size) {
            return VESC_IF->lbm_enc_sym_eerror;
        }

        memcpy(str, d->recv_buffer, d->recv_size);
        len = d->recv_size - 1;
    } else {
        len = tcp_recv(str, size);
    }

    // VESC_IF->printf("returned len: %d, str: '%s'", len, str);
    if (len == -1) {
        return VESC_IF->lbm_enc_sym_eerror;
    }

    lbm_value result_str_lbm;
    if (!VESC_IF->lbm_create_byte_array(&result_str_lbm, len + 1)) {
        VESC_IF->printf("memory error, create_byte_array failed");

        d->recv_size = len + 1;
        memcpy(d->recv_buffer, str, len + 1);

        return VESC_IF->lbm_enc_sym_merror;
    }
    // VESC_IF->printf("after lbm_create_byte_array");

    if (!VESC_IF->lbm_is_byte_array(result_str_lbm)) {
        // VESC_IF->printf("result_str_lbm wasn't a byte array!");
        return VESC_IF->lbm_enc_sym_merror;
    }
    char *result_str = VESC_IF->lbm_dec_str(result_str_lbm);
    memcpy(result_str, str, len + 1);
    result_str[len] = '\0';

    // VESC_IF->printf("before return :)");

    return result_str_lbm;
}

/**
 * signature: (tcp-wait-for-recv tries)
 *
 * Wait until there is data to receive using tcp-recv-single.
 * Will look for "+CADATAIND: 0" `tries` times.
 * Returns bool indicating if any data was found.
 */
static lbm_value ext_tcp_wait_for_recv(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_number(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    size_t tries = VESC_IF->lbm_dec_as_u32(args[0]) + 1;

    return lbm_enc_bool(tcp_wait_for_recv(tries));
}

// /**
//  * signature: (tcp-recv)
//  *
//  * Receive entire string available from the current tcp connection.
//  * Dynamically concatenates multiple results from tcp-recv-single until the
//  * entire reveived string has been read.
//  */
// static lbm_value ext_tcp_recv(lbm_value *args, lbm_uint argn) {
//     const size_t size = 50;

// }

#define TEST_INT_BASE10_STR_LEN(n) \
    VESC_IF->printf("%d -> %u\n", n, int_base10_str_len(n))

#define TEST_ASCII_TO_INT(n) VESC_IF->printf("'%s' -> %d\n", n, ascii_to_int(n))

static lbm_value ext_tcp_test(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;

    return VESC_IF->lbm_enc_sym_merror;

    // TEST_ASCII_TO_INT("0");
    // TEST_ASCII_TO_INT("1");
    // TEST_ASCII_TO_INT("5");
    // TEST_ASCII_TO_INT("10");
    // TEST_ASCII_TO_INT("1526");
    // TEST_ASCII_TO_INT("5024");
    // TEST_ASCII_TO_INT("-1");
    // TEST_ASCII_TO_INT("-10");
    // TEST_ASCII_TO_INT("-100");
    // TEST_ASCII_TO_INT("-1000000");
    // TEST_ASCII_TO_INT("12345678");

    // TEST_INT_BASE10_STR_LEN(0);
    // TEST_INT_BASE10_STR_LEN(1);
    // TEST_INT_BASE10_STR_LEN(10);
    // TEST_INT_BASE10_STR_LEN(15);
    // TEST_INT_BASE10_STR_LEN(1568);
    // TEST_INT_BASE10_STR_LEN(10000);
    // TEST_INT_BASE10_STR_LEN(999999999);
    // TEST_INT_BASE10_STR_LEN(1000000000);
    // TEST_INT_BASE10_STR_LEN(2000000000);

    return VESC_IF->lbm_enc_sym_true;
}

/* ------------------------------------------------------------
   INIT_FUN
   ------------------------------------------------------------ */

INIT_FUN(lib_info *info) {
    INIT_START;

    data *d = VESC_IF->malloc(sizeof(data));
    if (!d) return false;

    info->stop_fun = stop;
    info->arg = d;

    unsigned char *buffer =
        VESC_IF->malloc(SEND_BUFFER_UNITS * sizeof(send_unit_t));
    if (!buffer) {
        VESC_IF->free(d);
        return false;
    }
    rb_init(&d->send_buffer, buffer, sizeof(send_unit_t), SEND_BUFFER_UNITS);

    d->p_state = VESC_IF->malloc(sizeof(PACKET_STATE_t));
    if (d->p_state == NULL) {
        VESC_IF->free(buffer);
        VESC_IF->free(d);
        return false;
    }

    VESC_IF->packet_init(enqueue_data, process_data_tcp, d->p_state);

    d->paused = true;
    d->tcp_connected = false;
    d->cmd = 0;
    d->cmd_thread = -1;
    d->lock = VESC_IF->mutex_create();
    d->send_fails = 0;
    d->recv_fails = 0;
    d->mode = MODE_NONE;
    d->recv_filled = false;
    d->recv_size = 0;

    VESC_IF->uart_start(115200, false);
    VESC_IF->lbm_add_extension("ext-pause", ext_pause);
    VESC_IF->lbm_add_extension("ext-unpause", ext_unpause);
    VESC_IF->lbm_add_extension("ext-uart-write", ext_uart_write);
    VESC_IF->lbm_add_extension("ext-uart-readline", ext_uart_readline);
    VESC_IF->lbm_add_extension(
        "ext-uart-readline-trim", ext_uart_readline_trim
    );
    VESC_IF->lbm_add_extension("ext-uart-read-until", ext_uart_read_until);
    VESC_IF->lbm_add_extension("ext-uart-purge", ext_uart_purge);
    // VESC_IF->lbm_add_extension("ext-set-connected", ext_set_connected);
    VESC_IF->lbm_add_extension("ext-get-uuid", ext_get_uuid);
    // VESC_IF->lbm_add_extension("ext-tcp-send-string", ext_tcp_send_string);
    // VESC_IF->lbm_add_extension("ext-is-connected", ext_is_connected);
    // VESC_IF->lbm_add_extension("ext-is-paused", ext_is_paused);
    // VESC_IF->lbm_add_extension("ext-send-fails", ext_send_fails);
    // VESC_IF->lbm_add_extension("ext-recv-fails", ext_recv_fails);
    // VESC_IF->lbm_add_extension("ext-sim7000-mode", ext_sim7000_mode);
    // VESC_IF->lbm_add_extension("ext-sim7070-mode", ext_sim7070_mode);
    VESC_IF->lbm_add_extension("ext-pwr-key", ext_pwr_key);
    VESC_IF->lbm_add_extension("tcp-is-connected", ext_tcp_is_connected);
    VESC_IF->lbm_add_extension(
        "tcp-wait-until-connected", ext_tcp_wait_until_connected
    );
    VESC_IF->lbm_add_extension("tcp-disconnect", ext_tcp_disconnect);
    VESC_IF->lbm_add_extension("tcp-connect-host", ext_tcp_connect_host);
    VESC_IF->lbm_add_extension("tcp-send-str", ext_tcp_send_str);
    VESC_IF->lbm_add_extension("tcp-recv-single", ext_tcp_recv_single);
    VESC_IF->lbm_add_extension("tcp-wait-for-recv", ext_tcp_wait_for_recv);
    VESC_IF->lbm_add_extension("tcp-test", ext_tcp_test);

    VESC_IF->set_pad_mode(
        GPIOD, 8, PAL_STM32_MODE_OUTPUT | PAL_STM32_OTYPE_PUSHPULL
    );
    VESC_IF->clear_pad(GPIOD, 8);

    // VESC_IF->set_pad_mode(PWR_PORT, PWR_PAD, PAL_MODE_OUTPUT_PUSHPULL);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 0);
    // VESC_IF->sleep_ms(5);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 1);

    d->thread = VESC_IF->spawn(thd, 4096, "VESC-TCP", d);
    VESC_IF->printf("init fun");
    return true;
}
