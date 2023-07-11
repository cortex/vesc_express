#include <ctype.h>
#include <rb.h>
#include <stdlib.h>
#include <string.h>

#include "st_types.h"
#include "vesc_c_if.h"

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

static char *int_to_ascii(int value, char *buffer, int base) {
    if (base < 2 || base > 32) {
        return buffer;
    }

    int n = abs(value);

    int i = 0;
    while (n) {
        int r = n % base;

        if (r >= 10) {
            buffer[i++] = 65 + (r - 10);
        } else {
            buffer[i++] = 48 + r;
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
    return ((c == ' ') || (c == '\t') || (c == '\v') || (c == '\f') ||
            (c == '\r') || (c == '\n'));
}

static bool strneql(char *str1, char *str2, unsigned int n) {
    bool r = true;
    for (unsigned int i = 0; i < n; i++) {
        if (str1[i] != str2[i]) {
            r = false;
            break;
        }
    }
    return r;
}

bool oneof(const char *delims, char c) {
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

/* **************************************************
 * UART
 */

// Read from uart until one of the characters in delim is found
// or the length len has been obtained.
// len must be <= the size of the buffer.
static int uart_read_until(char *buffer, const char *delim, int len) {
    int sleep_count = 0;
    int n = 0;
    bool leading_whitespace = true;

    while (n < len && sleep_count < 2000) {
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

        if (oneof(delim, res) || n == len - 1) {
            buffer[n] = 0;
            break;
        }
        buffer[n] = (char)res;
        n++;
        sleep_count = 0;
    }
    if (sleep_count == 2000) {
        buffer[n] = 0;
    }
    return n;
}

static bool uart_write_string(char *str) {
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

/* **************************************************
 * AT interface restoration
 */
static bool restore_at_if(void) {
    char linebuffer[20];
    int br;
    while (VESC_IF->uart_read() >= 0)
        ;  // purge
    uart_write_string("AT\r\n");
    br = uart_read_until(linebuffer, "\n", 20);
    if (br > 0 && strneql("OK", linebuffer, 2)) {
        return true;
    }

    // try writing bytes
    for (int i = 0; i < 100; i++) {
        VESC_IF->uart_write((unsigned char *)"AAAAAAAAAA", 10);
        VESC_IF->uart_write((unsigned char *)"\r\n", 2);

        while (VESC_IF->uart_read() >= 0)
            ;  // purge
        uart_write_string("AT\r\n");
        br = uart_read_until(linebuffer, "\n", 20);
        if (br > 0 && strneql("OK", linebuffer, 2)) {
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

// rb = ring buffer
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

    int br = uart_read_until(linebuffer, delim, size);
    if (br > 0) {
        if (strneql(response, linebuffer, strlen(response))) {
            int n_bytes = atoi(&linebuffer[data_size_pos]);
            if (n_bytes > 0) {
                memset(linebuffer, 0, 100);
                int bytes_read =
                    tcp_read_data((unsigned char *)linebuffer, size, n_bytes);
                if (bytes_read == n_bytes) {
                    for (int i = 0; i < bytes_read; i++) {
                        VESC_IF->packet_process_byte(
                            (unsigned char)linebuffer[i], d->p_state);
                    }
                }
            }
            br = uart_read_until(linebuffer, "\n", size);
            if (!strneql("OK", linebuffer, 2)) {
                d->recv_fails++;
                restore_at_if();
            }
        } else if (strneql("ERROR", linebuffer, 5)) {
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

    int br = uart_read_until(linebuffer, "\n", size);
    if (br > 0) {
        if (strneql(ok_string, linebuffer, strlen(ok_string))) {
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
                    VESC_IF->lbm_unblock_ctx_unboxed(d->cmd_thread,
                                                     VESC_IF->lbm_enc_sym_true);
                    d->cmd_thread = -1;
                    d->cmd = 0;
                    break;
                case COMMAND_UNPAUSE: {
                    d->paused = false;
                    restore_at_if();
                    VESC_IF->lbm_unblock_ctx_unboxed(d->cmd_thread,
                                                     VESC_IF->lbm_enc_sym_true);
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

/* signature: (ext-set-connected) */
static lbm_value ext_set_connected(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;

    d->tcp_connected = true;
    return VESC_IF->lbm_enc_sym_true;
}

/* signature: (ext-uart-readline string number) */
static lbm_value ext_uart_readline(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_read");
    data *d = (data *)ARG;
    if (!d->paused) {
        return VESC_IF->lbm_enc_sym_nil;
    }
    if (argn != 2 || !VESC_IF->lbm_is_byte_array(args[0]) ||
        !VESC_IF->lbm_is_number(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }
    char *response = VESC_IF->lbm_dec_str(args[0]);
    uint32_t len = VESC_IF->lbm_dec_as_u32(args[1]);

    int r = uart_read_until(response, "\n", len);
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
        if (VESC_IF->lbm_is_byte_array(args[0]) &&
            VESC_IF->lbm_is_number(args[1])) {
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

/* signature: (ext-tcp-send-string string) */
static lbm_value ext_tcp_send_string(lbm_value *args, lbm_uint argn) {
    if (argn == 1) {
        VESC_IF->printf("Enqueueing string");
        if (VESC_IF->lbm_is_byte_array(args[0])) {
            char *str = VESC_IF->lbm_dec_str(args[0]);
            int32_t len = strlen(str);
            enqueue_data((unsigned char *)str, len + 1);
            return VESC_IF->lbm_enc_sym_true;
        }
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/* signature: (ext-is-connected) */
static lbm_value ext_is_connected(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;

    if (d->tcp_connected) {
        return VESC_IF->lbm_enc_sym_true;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/* signature: (ext-is-paused) */
static lbm_value ext_is_paused(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;

    if (d->paused) {
        return VESC_IF->lbm_enc_sym_true;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/* signature: (ext-send-fails) */
static lbm_value ext_send_fails(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;

    return VESC_IF->lbm_enc_u(d->send_fails);
}

/* signature: (ext-recv-fails) */
static lbm_value ext_recv_fails(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;

    return VESC_IF->lbm_enc_u(d->recv_fails);
}

/* signature: (ext-sim7000-mode) */
static lbm_value ext_sim7000_mode(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;
    d->mode = MODE_SIM7000;
    // d->data_send_fun = sim7000_data_send_fun;
    // d->data_recv_fun = sim7000_data_recv_fun;

    return VESC_IF->lbm_enc_sym_true;
}

/* signature: (ext-sim7070-mode) */
static lbm_value ext_sim7070_mode(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    data *d = (data *)ARG;
    d->mode = MODE_SIM7070;
    // d->data_send_fun = sim7070_data_send_fun;
    // d->data_recv_fun = sim7070_data_recv_fun;

    return VESC_IF->lbm_enc_sym_true;
}

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

    VESC_IF->uart_start(115200, false);
    VESC_IF->lbm_add_extension("ext-pause", ext_pause);
    VESC_IF->lbm_add_extension("ext-unpause", ext_unpause);
    VESC_IF->lbm_add_extension("ext-uart-write", ext_uart_write);
    VESC_IF->lbm_add_extension("ext-uart-readline", ext_uart_readline);
    VESC_IF->lbm_add_extension("ext-uart-purge", ext_uart_purge);
    VESC_IF->lbm_add_extension("ext-set-connected", ext_set_connected);
    VESC_IF->lbm_add_extension("ext-get-uuid", ext_get_uuid);
    VESC_IF->lbm_add_extension("ext-tcp-send-string", ext_tcp_send_string);
    VESC_IF->lbm_add_extension("ext-is-connected", ext_is_connected);
    VESC_IF->lbm_add_extension("ext-is-paused", ext_is_paused);
    VESC_IF->lbm_add_extension("ext-send-fails", ext_send_fails);
    VESC_IF->lbm_add_extension("ext-recv-fails", ext_recv_fails);
    VESC_IF->lbm_add_extension("ext-sim7000-mode", ext_sim7000_mode);
    VESC_IF->lbm_add_extension("ext-sim7070-mode", ext_sim7070_mode);
    VESC_IF->lbm_add_extension("ext-pwr-key", ext_pwr_key);

    VESC_IF->set_pad_mode(GPIOD, 8,
                          PAL_STM32_MODE_OUTPUT | PAL_STM32_OTYPE_PUSHPULL);
    VESC_IF->clear_pad(GPIOD, 8);

    // VESC_IF->set_pad_mode(PWR_PORT, PWR_PAD, PAL_MODE_OUTPUT_PUSHPULL);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 0);
    // VESC_IF->sleep_ms(5);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 1);

    d->thread = VESC_IF->spawn(thd, 4096, "VESC-TCP", d);
    VESC_IF->printf("init fun");
    return true;
}
