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

#define AT_TCP_MAX_CID 12

#define TCP_MAX_HOSTNAME_LEN 100

#define TCP_BUFFER_SIZE 256

#define TCP_CMD_TIMEOUT_MS 3000

// INT32_MAX = 2147483647
#define INT32_MAX_POW_10 1000000000

// Utilities

#define PRINT_VAR(value, format) VESC_IF->printf("%s: " format, #value, value)

// Creates a warning containing the size of x. (Works with gcc and the current
// make setup)
#define ALERT_SIZEOF(x)                \
    char(*__kaboom)[sizeof(data)] = 1; \
    void temp() { printf("%d", __kaboom); }

typedef unsigned int uint_t;
typedef signed int int_t;

typedef int8_t tcp_handle_t;

typedef uint16_t port_t;

typedef struct {
    unsigned char *data;
    unsigned int size;
} send_unit_t;

typedef enum {
    TCP_CMD_IDLE = 0,
    TCP_CMD_CHECK_STATUS,
    TCP_CMD_IS_OPEN,
    TCP_CMD_CONNECT_HOST,
    TCP_CMD_WAIT_CONNECTED,
    TCP_CMD_SEND,
    TCP_CMD_WAIT_RECV,
    TCP_CMD_RECV,
    TCP_CMD_CLOSE_CONNECTION,
    TCP_CMD_TEST,
} tcp_cmd_t;

typedef enum {
    TCP_STATE_NOT_CONNECTED = 0,
    TCP_STATE_CONNECTED,
    // TCP_STATE_RECEIVED,
} tcp_state_t;

typedef enum {
    // /** No local connection, closed or open, is present at all. */
    TCP_DISCONNECTED,
    // /**
    //  * Connection has been closed by remote server or an internal error
    //  * (probably internal to the modem...).
    //  * */
    TCP_CLOSED_REMOTE,
    // /** There is an open connection currently. */
    TCP_CONNECTED,
    // /** Currently listening in server mode. */
    TCP_SERVER_MODE,
    // /** An internal at or uart error occurred. */
    TCP_ERROR,
} tcp_status_t;

typedef enum {
    CONNECT_OK = 0,
    CONNECT_ERROR,
} tcp_connect_result_t;

/**
 * Global state
 */
typedef struct {
    lib_thread thread;

    lib_mutex lock;

    // size_t recv_size;
    // // If recv_buffer has been read yet.
    // bool recv_used;
    // // If recv_buffer has been filled yet.
    // bool recv_filled;
    // char recv_buffer[TCP_BUFFER_SIZE];

    tcp_state_t tcp_state;

    tcp_cmd_t tcp_cmd;
    lbm_cid tcp_calling_thread;

    // tcp_cmd arguments
    char tcp_hostname[TCP_MAX_HOSTNAME_LEN + 1];
    port_t tcp_port;
    uint_t tcp_timeout_ms;
    char *tcp_send_buffer;
    lbm_value tcp_test_str;

    lbm_uint symbol_disconnected;
    lbm_uint symbol_closed_remote;
    lbm_uint symbol_connected;
    lbm_uint symbol_server_mode;
    lbm_uint symbol_error;
    lbm_uint symbol_tcp_recv;

    lbm_uint symbol_error_unclosed_quote;
    lbm_uint symbol_error_invalid_char;

    lbm_uint symbol_false_val;
    lbm_uint symbol_null;
    lbm_uint symbol_plus_assoc;

    lbm_uint symbol_tok_true;
    lbm_uint symbol_tok_false;
    lbm_uint symbol_tok_null;

    lbm_uint symbol_tok_comma;
    lbm_uint symbol_tok_colon;
    lbm_uint symbol_tok_left_bracket;
    lbm_uint symbol_tok_right_bracket;
    lbm_uint symbol_tok_left_brace;
    lbm_uint symbol_tok_right_brace;

    lbm_uint symbol_terror;
    lbm_uint symbol_eerror;
    lbm_uint symbol_merror;
} data;

/* **************************************************
 * Symbols
 */

static bool register_symbols() {
    data *d = (data *)ARG;

    bool res =
        VESC_IF->lbm_add_symbol_const("disconnected", &d->symbol_disconnected)
        && VESC_IF->lbm_add_symbol_const(
            "closed-remote", &d->symbol_closed_remote
        )
        && VESC_IF->lbm_add_symbol_const("connected", &d->symbol_connected)
        && VESC_IF->lbm_add_symbol_const("server-mode", &d->symbol_server_mode)
        && VESC_IF->lbm_add_symbol_const("error", &d->symbol_error)
        && VESC_IF->lbm_add_symbol_const("tcp-recv", &d->symbol_tcp_recv)
        && VESC_IF->lbm_add_symbol_const(
            "error-unclosed-quote", &d->symbol_error_unclosed_quote
        )
        && VESC_IF->lbm_add_symbol_const(
            "error-invalid-char", &d->symbol_error_invalid_char
        )
        && VESC_IF->lbm_add_symbol_const("false_val", &d->symbol_false_val)
        && VESC_IF->lbm_add_symbol_const("null", &d->symbol_null)
        && VESC_IF->lbm_add_symbol_const("+assoc", &d->symbol_plus_assoc)
        && VESC_IF->lbm_add_symbol_const("tok-true", &d->symbol_tok_true)
        && VESC_IF->lbm_add_symbol_const("tok-false", &d->symbol_tok_false)
        && VESC_IF->lbm_add_symbol_const("tok-null", &d->symbol_tok_null)
        && VESC_IF->lbm_add_symbol_const("tok-comma", &d->symbol_tok_comma)
        && VESC_IF->lbm_add_symbol_const("tok-colon", &d->symbol_tok_colon)
        && VESC_IF->lbm_add_symbol_const(
            "tok-left-bracket", &d->symbol_tok_left_bracket
        )
        && VESC_IF->lbm_add_symbol_const(
            "tok-right-bracket", &d->symbol_tok_right_bracket
        )
        && VESC_IF->lbm_add_symbol_const(
            "tok-left-brace", &d->symbol_tok_left_brace
        )
        && VESC_IF->lbm_add_symbol_const(
            "tok-right-brace", &d->symbol_tok_right_brace
        );

    d->symbol_terror = VESC_IF->lbm_dec_sym(VESC_IF->lbm_enc_sym_terror);
    d->symbol_eerror = VESC_IF->lbm_dec_sym(VESC_IF->lbm_enc_sym_eerror);
    d->symbol_merror = VESC_IF->lbm_dec_sym(VESC_IF->lbm_enc_sym_merror);

    return res;
}

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

static bool is_char_digit(const char c) { return c >= '0' && c <= '9'; }

static bool is_whitespace(char c) {
    return (
        (c == ' ') || (c == '\t') || (c == '\v') || (c == '\f') || (c == '\r')
        || (c == '\n')
    );
}

static bool one_of(const char *delims, char c) {
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

static ssize_t first_not_of(const char *str, const char *delims) {
    for (size_t i = 0; i < strlen(str); i++) {
        if (!one_of(delims, str[i])) {
            return i;
        }
    }
    return -1;
}

static inline bool str_eq(const char *str1, const char *str2) {
    return strcmp(str1, str2) == 0;
}

static bool strneq(const char *str1, const char *str2, const uint_t n) {
    bool r = true;
    for (uint_t i = 0; i < n; i++) {
        if (str1[i] != str2[i]) {
            r = false;
            break;
        }
    }
    return r;
}

static bool str_contains_delim(const char *str, const char *delims) {
    for (size_t i = 0; i < strlen(str); i++) {
        if (one_of(delims, str[i])) {
            return true;
        }
    }

    return false;
}

/**
 * Find the index of the first occurence substring.
 *
 * \param str The string to search in.
 * \param search The substring to search for.
 * \return The found index or -1 if none were found.
 */
static ssize_t str_index_of(const char *str, const char *search) {
    size_t search_len = strlen(search);
    if (search_len == 0) {
        return -1;
    }
    for (size_t i = 0; i < strlen(str) - (search_len - 1); i++) {
        if (strneq(&str[i], search, search_len)) {
            return i;
        }
    }
    return -1;
}

/**
 * Extract a substring of at most length n from a string starting at a specified
 * character.
 *
 * \param dest The string to store the extracted substring in. This needs to
 * have a capacity of n + 1 bytes to account for the null byte. A terminating
 * null byte is always written
 * \param str The string to extract from.
 * \param start The index of str where the substring starts.
 * \param n How many characters to extract at a maximum. This is clamped to the
 * length of str.
 * \return the amount of characters written to dest (excluding the terminating
 * null byte).
 */
static size_t str_extract_n_from(
    char *dest, const char *str, size_t start, size_t n
) {
    size_t len = strlen(str);
    if (start >= len) {
        dest[0] = '\0';
        return 0;
    }

    if (start + n > len) {
        n = len - start;
    }

    memcpy(dest, str + start, n);

    dest[n] = '\0';
    return n;
}

/**
 * Extract a substring from a string until one of the specified characters are
 * found or the specified length is reached.
 *
 * \param dest The string to store the extracted substring in. This needs to
 * have a capacity of n + 1 bytes to account for the null byte. A terminating
 * null byte is always written
 * \param n How many characters to extract at a maximum. This is clamped to the
 * length of str.
 * \param str The string to extract from.
 * \param delims A string with the characters which cause the search to end. The
 * delim character is *not* written to dest.
 * \param start The index of str where the substring starts.
 * \return the amount of characters written to dest (excluding the terminating
 * null byte).
 */
static size_t str_extract_n_until(
    char *dest, size_t n, const char *str, const char *delims,
    const size_t start
) {
    size_t len = strlen(str);
    if (start >= len || n > len) {
        dest[0] = '\0';
        return 0;
    }

    if (start + n > len) {
        n = len - start;
    }

    for (size_t i = 0; i < n; i++) {
        if (one_of(delims, str[start + i])) {
            dest[i] = '\0';

            return i;
        }
        dest[i] = str[start + i];
    }

    dest[n] = '\0';
    return n;
}

static size_t str_extract_n_until_skip(
    char *dest, const size_t n, const char *str, const char *delims,
    const char *skip, size_t start
) {
    if (start >= n) {
        dest[0] = '\0';
        return 0;
    }
    ssize_t start_skipped = first_not_of(str + start, skip);
    if (start_skipped == -1) {
        dest[0] = '\0';
        return 0;
    }
    start += (size_t)start_skipped;

    return str_extract_n_until(dest, n, str, delims, start);
}

/**
 * Extract the longest substring from a string that contains only the specified
 * characters and is not longer than the specified length, starting at an index.
 *
 * \param dest The string to store the extracted substring in. This needs to
 * have a capacity of n + 1 bytes to account for the null byte. A terminating
 * null byte is always written
 * \param n How many characters to extract at a maximum. This is clamped to the
 * length of str.
 * \param str The string to extract from.
 * \param delims A string with the characters which dest will consist of
 * entirely.
 * \param start The index of str where the substring starts.
 * \return the amount of characters written to dest (excluding the terminating
 * null byte).
 */
static size_t str_extract_n_while(
    char *dest, size_t n, const char *str, const char *delims, size_t start
) {
    size_t len = strlen(str);
    if (start >= len || n > len) {
        dest[0] = '\0';
        return 0;
    }

    if (start + n > len) {
        n = len - start;
    }

    for (size_t i = 0; i < n; i++) {
        if (!one_of(delims, str[start + i])) {
            dest[i] = '\0';

            return i;
        }
        dest[i] = str[start + i];
    }

    dest[n] = '\0';
    return n;
}

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

static inline uint32_t time_now() { return VESC_IF->timer_time_now(); }

static inline float time_secs_since(const uint32_t timestamp) {
    return VESC_IF->timer_seconds_elapsed_since(timestamp);
}

static inline float time_ms_since(const uint32_t timestamp) {
    return VESC_IF->timer_seconds_elapsed_since(timestamp) * 1000.0;
}

static inline uint32_t time_ms_since_i(const uint32_t timestamp) {
    return (uint32_t)(VESC_IF->timer_seconds_elapsed_since(timestamp) * 1000.0);
}

static void puts_long(const char *str) {
    size_t len = strlen(str);
    while (len > 0) {
        // limit seems to be more like 399
        if (len <= 100) {
            VESC_IF->printf("%s", str);
            len = 0;
        } else {
            ssize_t break_index = str_index_of(str, "\n");
            
            if (break_index == -1) {
                break_index = 100;
            } else {
                // we also want to include the newline.
                break_index += 1;
            }
            
            char buffer[break_index + 1];
            memcpy(buffer, str, break_index);
            buffer[break_index] = '\0';
         
            VESC_IF->printf("%s", buffer);
            str = str + break_index;
            len -= break_index;
        }
    }
}

/**
 * Access the global state struct.
 */
static inline data *use_state() { return (data *)ARG; }

/* **************************************************
 * Copied LBM UTILS
 */

#define LBM_ADDRESS_SHIFT 2
#define LBM_VAL_SHIFT 4

#define LBM_PTR_MASK 0x00000001u
#define LBM_PTR_BIT 0x00000001u
#define LBM_PTR_VAL_MASK 0x03FFFFFCu
#define LBM_PTR_TYPE_MASK 0xFC000000u

// The address is an index into the const heap.
#define LBM_PTR_TO_CONSTANT_BIT 0x04000000u
#define LBM_PTR_TO_CONSTANT_MASK ~LBM_PTR_TO_CONSTANT_BIT
#define LBM_PTR_TO_CONSTANT_SHIFT 26

#define LBM_VAL_TYPE_MASK 0x0000000Cu

#define LBM_TYPE_U32 0x28000000u
#define LBM_TYPE_I32 0x38000000u
#define LBM_TYPE_I64 0x48000000u
#define LBM_TYPE_U64 0x58000000u
#define LBM_TYPE_FLOAT 0x68000000u
#define LBM_TYPE_DOUBLE 0x78000000u
#define LBM_TYPE_CHAR 0x00000004u
#define LBM_TYPE_U 0x00000008u
#define LBM_TYPE_I 0x0000000Cu

static inline lbm_type lbm_type_of_functional(lbm_value x) {
    return (x & LBM_PTR_MASK)
               ? (x & (LBM_PTR_TO_CONSTANT_MASK & LBM_PTR_TYPE_MASK))
               : (x & LBM_VAL_TYPE_MASK);
}

/* **************************************************
 * LBM UTILS
 */

static bool lbm_is_int(lbm_value value) {
    switch (lbm_type_of_functional(value)) {
        case LBM_TYPE_CHAR:
            return true;
        case LBM_TYPE_I:
            return true;
        case LBM_TYPE_U:
            return true;
        case LBM_TYPE_I32:
            return true;
        case LBM_TYPE_U32:
            return true;
        case LBM_TYPE_I64:
            return true;
        case LBM_TYPE_U64:
            return true;
        default:
            return false;
    }
}

static bool lbm_is_float(lbm_value value) {
    switch (lbm_type_of_functional(value)) {
        case LBM_TYPE_FLOAT:
            return true;
        case LBM_TYPE_DOUBLE:
            return true;
        default:
            return false;
    }
}

static inline lbm_value lbm_enc_bool(bool value) {
    return value ? VESC_IF->lbm_enc_sym_true : VESC_IF->lbm_enc_sym_nil;
}

static lbm_value lbm_create_str(const char *str) {
    size_t size = strlen(str) + 1;

    lbm_value result;
    if (!VESC_IF->lbm_create_byte_array(&result, size)) {
        return VESC_IF->lbm_enc_sym_merror;
    }

    char *result_str = VESC_IF->lbm_dec_str(result);

    memcpy(result_str, str, size);

    return result;
}

static void lbm_free_flat_value(lbm_flat_value_t *flat_value) {
    VESC_IF->free(flat_value->buf);
}

static bool lbm_flatten_str(lbm_flat_value_t *flat_value, const char *str) {
    size_t data_size = strlen(str) + 1;

    size_t buff_size = data_size + 1  // type header
                       + 4;           // num_byte header

    if (!VESC_IF->lbm_start_flatten(flat_value, buff_size)) {
        return false;
    }

    if (!VESC_IF->f_lbm_array(flat_value, data_size, (uint8_t *)str)) {
        lbm_free_flat_value(flat_value);
        return false;
    }

    if (!VESC_IF->lbm_finish_flatten(flat_value)) {
        lbm_free_flat_value(flat_value);
        return false;
    }

    return true;
}

// static bool lbm_flatten_simple_value(lbm_flat_value_t *flat_value, const
// lbm_value value) {
//     if
// }

static bool lbm_flatten_sym(lbm_flat_value_t *flat_value, const lbm_uint sym) {
    size_t buff_size = 1     // type header
                       + 4;  // value

    if (!VESC_IF->lbm_start_flatten(flat_value, buff_size)) {
        return false;
    }

    if (!VESC_IF->f_sym(flat_value, sym)) {
        lbm_free_flat_value(flat_value);
        return false;
    }

    if (!VESC_IF->lbm_finish_flatten(flat_value)) {
        lbm_free_flat_value(flat_value);
        return false;
    }

    return true;
}

static bool lbm_is_specific_symbol(lbm_value value, lbm_uint symbol) {
    return VESC_IF->lbm_is_symbol(value)
           && VESC_IF->lbm_dec_sym(value) == symbol;
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
    if ((sleep_count == timeout_ms || len == 0) && buffer) {
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
    if ((sleep_count == timeout_ms || (len == 0)) && buffer) {
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
static void uart_purge(const uint_t timeout_ms) {
    uint32_t start = time_now();

    int read_char = -1;

    while (read_char >= 0 || (uint_t)time_ms_since(start) < timeout_ms) {
        read_char = VESC_IF->uart_read();
        if (read_char < 0) {
            VESC_IF->sleep_ms(1);
        }
    }

#ifdef AT_DEBUG_LOG
    VESC_IF->printf("Purging took %fms", (double)time_ms_since(start));
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
                return NULL;
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
        "response not found, first was: '%s' (expect[0]: '%s')\n",
        first_response, responses[0]
    );
#endif

    return NULL;
}

/**
 * Run a simple at command with a single expected response.
 */
static bool at_command(
    const char *command, const char *expect, bool find_extra_ok,
    const uint_t timeout
) {
    uart_write_string(command);

    if (!at_find_response(expect, timeout, true)) {
        char buffer[strlen(command) + 1];
        str_extract_n_until(buffer, strlen(command), command, "\r\n", 0);
        VESC_IF->printf(
            "couldn't find response '%s' (for: %s)", expect, buffer
        );
        return false;
    }

    if (find_extra_ok && !at_find_response("OK", timeout, true)) {
        char buffer[strlen(command) + 1];
        str_extract_n_until(buffer, strlen(command), command, "\r\n", 0);
        VESC_IF->printf("couldn't find response 'OK' (for: %s)", buffer);
        return false;
    }

    return true;
}

/**
 * Run a simple at command with a multiple expected response.
 */
static bool at_command_responses(
    const char *command, const size_t count, const char *responses[count],
    const uint_t timeout
) {
    uart_write_string(command);

    const char *response = at_find_of_responses(count, responses, timeout);
    if (response == NULL) {
        VESC_IF->printf("couldn't find any valid response (for: %s)", command);
        return false;
    }

    if (!strneq(response, "OK", 2)) {
        if (!at_find_response("OK", timeout, true)) {
            VESC_IF->printf("couldn't find find 'OK' (for: %s)", command);
            return false;
        }
    }

    return true;
}

static bool at_init() {
    uart_purge(AT_PURGE_TIMEOUT_MS);

    // Disable echo mode
    {
        uart_write_string("ATE0\r\n");

        const char *response_ok = "OK";
        const char *response_echo = "ATE0";
        if (!at_command_responses(
                "ATE0\r\n", 2, (const char *[]){response_ok, response_echo},
                AT_READ_TIMEOUT_MS
            )) {
            // modem might need more time at startup
            VESC_IF->sleep_ms(3000);
            if (!at_command_responses(
                    "ATE0\r\n", 2, (const char *[]){response_ok, response_echo},
                    AT_READ_TIMEOUT_MS
                )) {
                return false;
            }
        }
    }

    // Check if pin is required
    if (!at_command("AT+CPIN?\r\n", "+CPIN: READY", true, AT_READ_TIMEOUT_MS)) {
        return false;
    }

    // Select text mode for sms messages
    if (!at_command("AT+CMGF=1\r\n", "OK", false, AT_READ_TIMEOUT_MS)) {
        return false;
    }

    // Set preferred mode to LTE only
    if (!at_command("AT+CNMP=38\r\n", "OK", false, AT_READ_TIMEOUT_MS)) {
        return false;
    }

    // Attach GPRS
    if (!at_command("AT+CGATT=1\r\n", "OK", false, 2000)) {
        return false;
    }

    // Check that GPRS is attached
    if (!at_command("AT+CGATT?\r\n", "+CGATT: 1", true, AT_READ_TIMEOUT_MS)) {
        return false;
    }

    // ; Print current operator mode
    // (at-command-parse-result "AT+COPS?\r\n" print 100)

    // ; Get and print network APN
    // (at-command-parse-result "AT+CGNAPN\r\n" print 100)

    // Configure PDP with Internet Protocol Version 4 and the Access Point Name
    // "internet.telenor.se"
    // The result is then printed.
    if (!at_command(
            "AT+CNCFG=0,1,\"internet.telenor.se\"\r\n", "OK", false,
            AT_READ_TIMEOUT_MS
        )) {
        return false;
    }

    // Activate APP Network
    {
        uart_write_string("AT+CNACT=0,1\r\n");
        const char *response_ok = "OK";
        const char *response_error = "ERROR";
        const char *response = at_find_of_responses(
            2, (const char *[]){response_ok, response_error}, AT_READ_TIMEOUT_MS
        );
        if (!response) {
            VESC_IF->printf("failed to find 'OK' or 'ERROR' (for AT+CNACT=0,1)"
            );
            return false;
        }
    }

    return true;
}

/* **************************************************
 * AT interface restoration
 */
// static bool restore_at_if(void) {
//     char linebuffer[20];
//     int br;
//     while (VESC_IF->uart_read() >= 0)
//         ;  // purge
//     uart_write_string("AT\r\n");
//     br = uart_read_until_trim(linebuffer, "\n", 20, 2000);
//     if (br > 0 && strneq("OK", linebuffer, 2)) {
//         return true;
//     }

//     // try writing bytes
//     for (int i = 0; i < 100; i++) {
//         VESC_IF->uart_write((unsigned char *)"AAAAAAAAAA", 10);
//         VESC_IF->uart_write((unsigned char *)"\r\n", 2);

//         while (VESC_IF->uart_read() >= 0)
//             ;  // purge
//         uart_write_string("AT\r\n");
//         br = uart_read_until_trim(linebuffer, "\n", 20, 2000);
//         if (br > 0 && strneq("OK", linebuffer, 2)) {
//             return true;
//         }
//     }
//     return false;
// }

/* **************************************************
 * Modem power on/off
 */

static void modem_pwr_key(bool grounded) {
    if (grounded) {
        VESC_IF->set_pad(GPIOD, 8);
    } else {
        VESC_IF->clear_pad(GPIOD, 8);
    }
}

static void modem_pwr_on() {
    uint32_t start = time_now();

    VESC_IF->printf("powering on...");

    modem_pwr_key(false);
    // Spec doesn't specify how long too wait here, urgh...
    // Any lower doesn't seem very reliable.
    VESC_IF->sleep_ms(800);

    modem_pwr_key(true);
    VESC_IF->sleep_ms(1000);
    modem_pwr_key(false);

    // checking takes forever (adds ~1400ms)
    // if (!at_find_response("RDY", AT_READ_TIMEOUT_MS, true)) {
    //     VESC_IF->printf("couldn't find 'RDY' response");
    //     return;
    // }

    // // purge remaining lines, including:
    // // +CFUN: 1
    // // +CPIN: READY
    // // SMS Ready
    // uart_purge(AT_PURGE_TIMEOUT_MS);

    VESC_IF->printf("ready, took %ums", time_ms_since_i(start));
}

static bool modem_pwr_off() {
    VESC_IF->printf("powering off...");

    uart_purge(AT_PURGE_TIMEOUT_MS);

    // should power off normally
    uart_write_string("AT+CPOWD=1\r\n");

    if (!at_find_response("NORMAL POWER DOWN", AT_READ_TIMEOUT_MS, true)) {
        return false;
    }

    VESC_IF->printf("finished");

    return true;
}

/* **************************************************
 * TCP library
 */

static inline const char *stringify_tcp_status(const tcp_status_t status) {
    switch (status) {
        case TCP_DISCONNECTED: {
            return "TCP_DISCONNECTED";
        }
        case TCP_CLOSED_REMOTE: {
            return "TCP_CLOSED_REMOTE";
        }
        case TCP_CONNECTED: {
            return "TCP_CONNECTED";
        }
        case TCP_SERVER_MODE: {
            return "TCP_SERVER_MODE";
        }
        case TCP_ERROR: {
            return "TCP_ERROR";
        }
        default: {
            return "invalid status";
        }
    }
}

static tcp_status_t tcp_status(tcp_handle_t cid) {
    uart_purge(AT_PURGE_TIMEOUT_MS);

    uart_write_string("AT+CASTATE?\r\n");

    // ex: +CASTATE: <cid>,1\r
    const char *response_ok = "OK";
    const char *response_state = "+CASTATE: ";
    const char *responses[] = {response_state, response_ok};
    const char *response = NULL;

    tcp_status_t found_status = TCP_ERROR;

    // should in theory go 13 times at a maximum (there are 12 cids + 1 'OK')
    // 20 is just to be safe
    for (size_t i = 0; i < 20; i++) {
        // uint32_t start = time_now();
        response = at_find_of_responses(2, responses, AT_READ_TIMEOUT_MS);

        if (response == response_ok) {
            if (found_status == TCP_ERROR) {
                found_status = TCP_DISCONNECTED;
            }
            break;
        }

        if (response == response_state) {
            // ex response: 12
            char response[3];
            int read_length =
                uart_read_until(response, ",", 2, AT_READ_TIMEOUT_MS);
            // VESC_IF->printf("cid response: '%s'", response);
            for (size_t j = 0; j < strlen(response); j++) {
                if (!is_char_digit(response[j])) {
                    VESC_IF->printf(
                        "found non digit character '%c' in <cid> (ascii %hhd)",
                        response[j], response[j]
                    );
                    return TCP_ERROR;
                }
            }
            tcp_handle_t found_cid = (tcp_handle_t)ascii_to_int(response);

            if (found_cid == cid) {
                bool has_read_comma = read_length == 1;
                if (!has_read_comma) {
                    char comma = -1;
                    if (!uart_read_timeout(&comma, 20) || comma != ',') {
                        VESC_IF->printf(
                            "found '%c' character (ascii %hhd), expect: ',' "
                            "after '+CASTATE: <cid>'",
                            comma, comma
                        );
                        return TCP_ERROR;
                    }
                }

                char status_char = -1;
                if (!uart_read_timeout(&status_char, 20)
                    || !is_char_digit(status_char)) {
                    VESC_IF->printf(
                        "found non digit character '%c' searching for status "
                        "(ascii %hhd)",
                        status_char, status_char
                    );
                    return TCP_ERROR;
                }

                switch (status_char) {
                    case '0': {
                        found_status = TCP_CLOSED_REMOTE;
                        break;
                    }
                    case '1': {
                        found_status = TCP_CONNECTED;
                        break;
                    }
                    case '2': {
                        found_status = TCP_SERVER_MODE;
                        break;
                    }
                    default: {
                        VESC_IF->printf(
                            "found invalid status '%c' (ascii %hhd)",
                            status_char, status_char
                        );
                        return TCP_ERROR;
                    }
                }
            } else {
                // Clear unwanted (potential) comma and status.
                uart_read_until(NULL, "\r", 2, AT_READ_TIMEOUT_MS);
            }
        }
    }

    return found_status;
}

static bool tcp_is_connected(const tcp_handle_t cid) {
    return tcp_status(cid) == TCP_CONNECTED;
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
bool tcp_wait_until_connected(const tcp_handle_t cid, const uint_t timeout_ms) {
    const float timeout_s = ((float)timeout_ms / 1000.0);

    uint32_t start = VESC_IF->timer_time_now();
    while (VESC_IF->timer_seconds_elapsed_since(start) < timeout_s) {
        if (tcp_is_connected(cid)) {
            return true;
        }

        VESC_IF->sleep_ms(10);
    }

    return false;
}

/**
 * Disconnect a tcp connection.
 *
 * \return bool indicating if operation was successful.
 */
static bool tcp_disconnect(const tcp_handle_t cid) {
    // uart_purge();
    uart_purge(AT_PURGE_TIMEOUT_MS);

    char cid_str[int_base10_str_len(cid) + 1];
    int_to_ascii(cid, cid_str, 10);

    uart_write_string("AT+CACLOSE=");
    uart_write_string(cid_str);
    uart_write_string("\r\n");

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
 * Connect to the given host and port, using the specified connection id on the
 * modem. Any currently open connection is automatically closed.
 *
 * \return the opened handle on success or tcp_connect_error_t on failure.
 */
static tcp_connect_result_t tcp_connect_host(
    tcp_handle_t cid, const char *hostname, const port_t port
) {
    // safety measure
    tcp_disconnect(cid);

    // longest value: 12
    char cid_str[3];
    int_to_ascii((int)cid, cid_str, 10);
    cid_str[2] = '\0';

    // longest value: 65536
    char port_str[6];
    int_to_ascii((int)port, port_str, 10);
    port_str[5] = '\0';

    uart_purge(AT_PURGE_TIMEOUT_MS);

    uart_write_string("AT+CAOPEN=");
    uart_write_string(cid_str);
    uart_write_string(",0,\"TCP\",\"");
    uart_write_string(hostname);
    uart_write_string("\",");
    uart_write_string(port_str);
    uart_write_string("\r\n");

    // potential response: +CAOPEN: <0-12>,<0-27>\r
    if (!at_find_response("+CAOPEN: ", AT_READ_TIMEOUT_MS, true)) {
        VESC_IF->printf("failed to find '+CAOPEN: 0,'");
        return CONNECT_ERROR;
    }
    if (!at_find_response(cid_str, AT_READ_TIMEOUT_MS, true)) {
        VESC_IF->printf("failed to find cid '%s'", cid_str);
        return CONNECT_ERROR;
    }
    if (!at_find_response(",", AT_READ_TIMEOUT_MS, true)) {
        VESC_IF->printf("failed to find ','");
        return CONNECT_ERROR;
    }

    char found = 0;
    uart_read_timeout(
        &found, 10
    );  // this 10 just *feels* like the right number ;)
    if (found != '0') {
        VESC_IF->printf(
            "invalid result '+CAOPEN: %s,%c', (char: %d)", cid_str, found, found
        );
        VESC_IF->printf("next result: %d", VESC_IF->uart_read());
        return CONNECT_ERROR;
    }

    if (!at_find_response("OK", AT_READ_TIMEOUT_MS, true)) {
        return CONNECT_ERROR;
    }

    return CONNECT_OK;
}

/**
 * Send string to the tcp connection referenced by the handle.
 *
 * \return bool indicating if the string was successfully sent.
 */
static bool tcp_send_str(const tcp_handle_t handle, const char *str) {
    char cid_str[4];
    int_to_ascii(handle, cid_str, 10);

    size_t len = strlen(str);
    char len_str[int_base10_str_len(len) + 1];
    int_to_ascii(len, len_str, 10);

    uart_purge(AT_PURGE_TIMEOUT_MS);

    uart_write_string("AT+CASEND=");
    uart_write_string(cid_str);
    uart_write_string(",");
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
static ssize_t tcp_recv(
    const tcp_handle_t handle, char *dest, const size_t dest_size
) {
    char cid_str[4];
    int_to_ascii(handle, cid_str, 10);

    size_t capacity = dest_size - 1;
    size_t capacity_str_len = int_base10_str_len(capacity);
    char capacity_str[capacity_str_len + 1];
    int_to_ascii(capacity, capacity_str, 10);

    uart_purge(AT_PURGE_TIMEOUT_MS);
    uart_write_string("AT+CARECV=");
    uart_write_string(cid_str);
    uart_write_string(",");
    uart_write_string(capacity_str);
    uart_write_string("\r\n");

    // ex: +CARECV: 1460,...<data>...
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
 * Block until there is data to receive on the specified tcp connection.
 *
 * \returns true if received data was found, meaning you can call tcp_recv,
 * false otherwise.
 */
static bool tcp_wait_for_recv(
    const tcp_handle_t handle, const uint_t timeout_ms
) {
    char expect[15] = "+CADATAIND: ";
    int_to_ascii(handle, expect + 12, 10);

    uint32_t start = time_now();
    char response[16];
    while ((uint_t)time_ms_since(start) < timeout_ms) {
        uart_read_until_trim(response, "\n", 15, AT_READ_TIMEOUT_MS);
        if (strneq(response, expect, 13)) {
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
 * TCP Thread
 */

/**
 * Call a tcp command, blocking until the current command is TCP_CMD_IDLE.
 *
 * \return false if calling failed due to the timeout beeing reached while
 * waiting for current command to finish, true otherwise.
 */
static bool lbm_call_tcp_cmd(const tcp_cmd_t cmd, const uint_t timeout_ms) {
    data *d = use_state();

    uint32_t start = time_now();
    while ((uint_t)time_ms_since(start) < timeout_ms) {
        VESC_IF->mutex_lock(d->lock);
        tcp_cmd_t current_cmd = d->tcp_cmd;
        VESC_IF->mutex_unlock(d->lock);

        if (current_cmd == TCP_CMD_IDLE) {
            VESC_IF->mutex_lock(d->lock);
            d->tcp_cmd = cmd;
            d->tcp_calling_thread = VESC_IF->lbm_get_current_cid();
            VESC_IF->mutex_unlock(d->lock);

            VESC_IF->lbm_block_ctx_from_extension();

            return true;
        }
    }

    return false;
}

static void tcp_thd(void *arg) {
    void return_result_unboxed(lbm_value result) {
        data *d = use_state();

        if (!VESC_IF->lbm_unblock_ctx_unboxed(d->tcp_calling_thread, result)) {
            VESC_IF->printf("sending result to calling thread failed");
        }
    }
    void return_flat_result(lbm_flat_value_t * flat_value) {
        data *d = use_state();

        if (!VESC_IF->lbm_unblock_ctx(d->tcp_calling_thread, flat_value)) {
            VESC_IF->printf("sending flat result to calling thread failed");
        }
    }
    void return_result(lbm_value result) {
        if (VESC_IF->lbm_is_symbol(result)) {
            lbm_flat_value_t flat_value;
            if (!lbm_flatten_sym(&flat_value, VESC_IF->lbm_dec_sym(result))) {
                VESC_IF->printf("failed to flatten symbol");
                return_result_unboxed(VESC_IF->lbm_enc_sym_eerror);
            }

            return_flat_result(&flat_value);
        } else {
            return_result_unboxed(result);
        }
    }

    data *d = (data *)arg;

    while (!VESC_IF->should_terminate()) {
        VESC_IF->mutex_lock(d->lock);
        tcp_cmd_t cmd = d->tcp_cmd;
        tcp_state_t state = d->tcp_state;
        VESC_IF->mutex_unlock(d->lock);

        switch (cmd) {
            case TCP_CMD_CHECK_STATUS: {
                // if (state == TCP_STATE_RECEIVING) {
                //     return_result(VESC_IF->lbm_enc_sym_eerror);
                //     break;
                // }

                lbm_uint symbol;
                switch (tcp_status(0)) {
                    case TCP_DISCONNECTED: {
                        symbol = d->symbol_disconnected;
                        break;
                    }
                    case TCP_CLOSED_REMOTE: {
                        symbol = d->symbol_closed_remote;
                        break;
                    }
                    case TCP_CONNECTED: {
                        symbol = d->symbol_connected;
                        break;
                    }
                    case TCP_SERVER_MODE: {
                        symbol = d->symbol_server_mode;
                        break;
                    }
                    default: {
                        symbol = d->symbol_error;
                        break;
                    }
                }
                return_result(VESC_IF->lbm_enc_sym(symbol));
                break;
            }
            case TCP_CMD_IS_OPEN: {
                bool result = d->tcp_state != TCP_STATE_NOT_CONNECTED;

                return_result(lbm_enc_bool(result));
                break;
            }
            case TCP_CMD_CONNECT_HOST: {
                if (state != TCP_STATE_NOT_CONNECTED) {
                    return_result(VESC_IF->lbm_enc_sym_eerror);
                    break;
                }

                const char *hostname = d->tcp_hostname;
                port_t port = d->tcp_port;

                tcp_connect_result_t result =
                    tcp_connect_host(0, hostname, port);

                if (result == CONNECT_OK) {
                    d->tcp_state = TCP_STATE_CONNECTED;
                }

                return_result(lbm_enc_bool(result == CONNECT_OK));
                break;
            }
            case TCP_CMD_WAIT_CONNECTED: {
                if (state == TCP_STATE_NOT_CONNECTED) {
                    return_result(VESC_IF->lbm_enc_sym_nil);
                    break;
                }

                bool result = tcp_wait_until_connected(0, d->tcp_timeout_ms);

                return_result(lbm_enc_bool(result));
                break;
            }
            case TCP_CMD_SEND: {
                char *buffer = d->tcp_send_buffer;

                if (state != TCP_STATE_CONNECTED) {
                    VESC_IF->free(buffer);
                    return_result(VESC_IF->lbm_enc_sym_eerror);
                    break;
                }

                bool result = tcp_send_str(0, buffer);

                VESC_IF->free(buffer);

                return_result(lbm_enc_bool(result));
                break;
            }
            case TCP_CMD_WAIT_RECV: {
                if (state == TCP_STATE_NOT_CONNECTED) {
                    return_result(VESC_IF->lbm_enc_sym_eerror);
                    break;
                }

                bool result = tcp_wait_for_recv(0, d->tcp_timeout_ms);

                return_result(lbm_enc_bool(result));
                break;
            }
            case TCP_CMD_RECV: {
                if (state == TCP_STATE_NOT_CONNECTED) {
                    return_result(VESC_IF->lbm_enc_sym_eerror);
                    break;
                }

                char buffer[TCP_BUFFER_SIZE];

                ssize_t len = tcp_recv(0, buffer, TCP_BUFFER_SIZE);
                if (len == -1) {
                    return_result(VESC_IF->lbm_enc_sym(d->symbol_error));
                    break;
                }

                if (len == 0) {
                    return_result(VESC_IF->lbm_enc_sym_nil);
                    break;
                }

                lbm_flat_value_t result;
                if (!lbm_flatten_str(&result, buffer)) {
                    return_result(VESC_IF->lbm_enc_sym(d->symbol_error));
                    break;
                }

                return_flat_result(&result);
                break;
            }
            case TCP_CMD_TEST: {
                return_result(VESC_IF->lbm_enc_sym_eerror);
                // lbm_uint sym =
                // VESC_IF->lbm_dec_sym(VESC_IF->lbm_enc_sym_eerror);

                // lbm_flat_value_t result;
                // if (!lbm_flatten_sym(&result, sym)) {
                //     return_result(VESC_IF->lbm_enc_sym_nil);
                //     break;
                // }

                // return_flat_result(&result);
                break;
            }
            case TCP_CMD_CLOSE_CONNECTION: {
                if (state == TCP_STATE_NOT_CONNECTED) {
                    return_result(VESC_IF->lbm_enc_sym_nil);
                    break;
                }
                bool result = tcp_disconnect(0);
                d->tcp_state = TCP_STATE_NOT_CONNECTED;

                if (!result) {
                    return_result(VESC_IF->lbm_enc_sym(d->symbol_error));
                    break;
                }

                return_result(VESC_IF->lbm_enc_sym_true);
                break;
            }
            default: {
                break;
            }
        }

        VESC_IF->mutex_lock(d->lock);
        d->tcp_cmd = TCP_CMD_IDLE;
        VESC_IF->mutex_unlock(d->lock);

        switch (d->tcp_state) {
            case TCP_STATE_NOT_CONNECTED: {
                break;
            }
            case TCP_STATE_CONNECTED: {
                break;
            }
            // case TCP_STATE_RECEIVED: {
            //     VESC_IF->mutex_lock(d->lock);
            //     bool recv_used = d->recv_used;
            //     bool recv_filled = d->recv_filled;
            //     VESC_IF->mutex_unlock(d->lock);

            //     if (!recv_used && recv_filled) {
            //         break;
            //     }

            //     char buffer[TCP_BUFFER_SIZE];
            //     ssize_t result = tcp_recv(0, buffer, TCP_BUFFER_SIZE);

            //     if (result == -1) {
            //         VESC_IF->printf("tcp_recv error");
            //         break;
            //     }

            //     VESC_IF->mutex_lock(d->lock);
            //     memcpy(d->recv_buffer, buffer, sizeof(d->recv_buffer));
            //     d->recv_size = (size_t)result;
            //     d->recv_filled = true;
            //     d->recv_used = false;
            //     VESC_IF->mutex_unlock(d->lock);

            //     if (result == 0) {
            //         d->tcp_state = TCP_STATE_CONNECTED;
            //     }

            //     break;
            // }
            default: {
                break;
            }
        }

        VESC_IF->sleep_ms(1);
    }
    VESC_IF->printf("LEAVING THREAD");

    if (d) {
        VESC_IF->free(d);
    }
}

/* **************************************************
 * JSON
 */

typedef enum {
    JSON_OK,
    JSON_UNCLOSED_QUOTE,
    JSON_INVALID_CHAR,
} json_result_t;

typedef struct {
    lbm_value token;
    size_t len;
    json_result_t error;
} json_lex_unit_t;

// /**
//  * \param json_object Should be an associative lbm list, without the first
//  * '+assoc element.
//  */
// static size_t json_object_str_len(lbm_value json_object) {}

// /**
//  * \param json_array Should be an lbm list.
//  */
// static size_t json_array_str_len(lbm_value json_array) {}

// /**
//  * Get the length a lbm json value would have if stringified.
//  *
//  * \param json_value The json value to get the length of. This lbm value follow
//  * the specific rules that are defined in json.lisp, to specify objects vs
//  * arrays. (I.e assoc lists start with '+assoc to specify that they're objects.)
//  */
// static size_t json_get_str_len(const lbm_value json_value) {
//     data *d = use_state();

//     size_t size = 0;

//     if (VESC_IF->lbm_is_symbol_nil(json_value)) {
//         // is an empty list
//         return 2;
//     }
//     if (VESC_IF->lbm_is_cons(json_value)) {
//         lbm_value first = VESC_IF->lbm_car(json_value);

//         if (lbm_is_specific_symbol(first, d->symbol_plus_assoc)) {
//             return json_object_str_len(VESC_IF->lbm_cdr(json_value));
//         } else {
//             return json_array_str_len(json_value);
//         }
//     } else if (false)
//     // TODO
// }

// static size_t json_stringify_object(char *dest, const lbm_value json_object) {
//     size_t offset = 0;

//     dest[offset++] = '{';

//     lbm_value current = json_object;

//     for (size_t i = 0; i < 200; i++) {  // safeguard
//         if (VESC_IF->lbm_is_symbol_nil(current)) {
//             break;
//         }

//         if (!VESC_IF->lbm_is_cons(current)) {
//             break;
//         }

//         lbm_value pair = VESC_IF->lbm_car(current);
//         if (!VESC_IF->lbm_is_cons(pair)) {
//             break;
//         }

//         if (!VESC_IF->lbm_is_byte_array(VESC_IF->lbm_car(pair))) {
//             // field name needs to be a string
//             break;
//         }

//         const char *name = VESC_IF->lbm_dec_str(VESC_IF->lbm_car(pair));

//         dest[offset++] = '"';

//         size_t name_len = strlen(name);
//         memcpy(dest + offset, name, name_len);
//         offset += name_len;

//         dest[offset++] = '"';
//         dest[offset++] = ':';

//         offset += json_stringify(dest + offset, VESC_IF->lbm_cdr(pair));

//         current = VESC_IF->lbm_cdr(current);

//         if (!VESC_IF->lbm_is_symbol_nil(current)) {
//             current[offset++] = ',';
//         }
//     }

//     dest[offset++] = '}';

//     return offset;
// }

// static size_t json_stringify_array(char *dest, const lbm_value json_array) {
//     size_t offset = 0;

//     dest[offset++] = '[';

//     lbm_value current = json_array;

//     for (size_t i = 0; i < 200; i++) {  // safeguard
//         if (VESC_IF->lbm_is_symbol_nil(current)) {
//             break;
//         }

//         if (!VESC_IF->lbm_is_cons(current)) {
//             break;
//         }

//         offset += json_stringify(dest + offset, VESC_IF->lbm_car(current));

//         current = VESC_IF->lbm_cdr(current);

//         if (!VESC_IF->lbm_is_symbol_nil(current)) {
//             current[offset++] = ',';
//         }
//     }

//     dest[offset++] = ']';

//     return offset;
// }

// static size_t json_stringify_str(char *dest, const char *str) {
//     if (!VESC_iF->lbm_is_byte_array(json_str)) {
//         return 0;
//     }
    
//     size_t offset = 0;

//     dest[offset++] = '"';
    
//     size_t len = strlen(name);
//     memcpy(dest + offset, str, len);
//     offset += len;
    
//     dest[offset++] = '"';
    
//     return offset;
// }

// static size_t json_stringify_int(char *dest, const int64_t int) {
//     // unsigned 64 bit integers might overflow here, but I don't feel like
//     // supporting that...
    
//     int_base10_str_len()
// }

// static size_t json_stringify_simple_value(char *dest, const lbm_value json_value) {
    
// }

// static size_t json_stringify(char *dest, const lbm_value json_value) {}

#define JSON_COMMA ','
#define JSON_COLON ':'
#define JSON_LEFT_BRACKET '['
#define JSON_RIGHT_BRACKET ']'
#define JSON_LEFT_BRACE '{'
#define JSON_RIGHT_BRACE '}'
#define JSON_QUOTE '"'
#define JSON_NUMERIC_CHARS "0123456789-+.eE"
#define JSON_SYNTAX_CHARS ",:[]{}"
#define JSON_WHITESPACE_CHARS " \t\n\v\r"

#define JSON_TRUE "true"
#define JSON_FALSE "false"
#define JSON_NULL "null"

#define JSON_TRUE_LEN (sizeof(JSON_TRUE) - 1)
#define JSON_FALSE_LEN (sizeof(JSON_FALSE) - 1)
#define JSON_NULL_LEN (sizeof(JSON_NULL) - 1)

static char json_translate_escape_char(char c) {
    switch (c) {
        case '"':
            return '"';
        case '\\':
            return '\\';
        // I have no idea what they mean with 'solidus' in the JSON docs
        // https://www.json.org/json-en.html
        // case '/': return '/';
        case 'b':
            return '\b';
        case 'f':
            return '\f';
        case 'n':
            return '\n';
        case 'r':
            return '\r';
        case 't':
            return '\t';
        // TODO: Figure out the deal with UTF-16 surrogate pairs...
        // case 'u': return ...;
        default:
            return c;
    }
}

static size_t json_unescape_str(char *dest, const char *str) {
    size_t len = strlen(str);

    size_t dest_i = 0;
    for (size_t i = 0; i < len; i++) {
        if (str[i] == '\\') {
            if (i != len - 1) {
                i++;
                dest[dest_i++] = json_translate_escape_char(str[i]);
            }
            continue;
        }

        dest[dest_i++] = str[i];
    }

    dest[dest_i] = '\0';
    return dest_i;
}

/**
 * \param str Must have a length >= 1.
 */
static json_lex_unit_t json_lex_str(const char *str) {
    if (str[0] != JSON_QUOTE) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym_nil,
            .len = 0,
            .error = JSON_OK,
        };
    } else {
        size_t len = strlen(str);

        for (size_t i = 1; i < len; i++) {
            if (str[i] == JSON_QUOTE) {
                size_t buff_len = i - 1;
                char buff[buff_len + 1];
                str_extract_n_from(buff, str, 1, buff_len);

                return (json_lex_unit_t){
                    .token = lbm_create_str(buff),
                    .len = buff_len + 2,
                    .error = JSON_OK,
                };
            }
        }

        return (json_lex_unit_t){
            .error = JSON_UNCLOSED_QUOTE,
        };
    }
}

static json_lex_unit_t json_lex_number(const char *str) {
    size_t len = strlen(str);

    ssize_t result = first_not_of(str, JSON_NUMERIC_CHARS);
    size_t number_len;
    if (result == -1) {
        number_len = len;
    } else {
        number_len = (size_t)result;
    }

    if (number_len == 0) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym_nil,
            .len = 0,
            .error = JSON_OK,
        };
    }

    char number_str[number_len];
    str_extract_n_from(number_str, str, 0, number_len);

    lbm_value value_lbm;

    if (str_contains_delim(number_str, ".")) {
        // TODO: figure out floating point number parsing.
        value_lbm = VESC_IF->lbm_enc_float(69.0);
    } else {
        int value = ascii_to_int(number_str);
        value_lbm = VESC_IF->lbm_enc_i32(value);
    }

    return (json_lex_unit_t){
        .token = value_lbm,
        .len = number_len,
        .error = JSON_OK,
    };
}

static json_lex_unit_t json_lex_bool_null(const char *str) {
    data *d = use_state();

    size_t len = strlen(str);

    if (len >= JSON_TRUE_LEN && strneq(str, JSON_TRUE, JSON_TRUE_LEN)) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym(d->symbol_tok_true),
            .len = JSON_TRUE_LEN,
            .error = JSON_OK,
        };
    } else if (len >= JSON_FALSE_LEN && strneq(str, JSON_FALSE, JSON_FALSE_LEN)) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym(d->symbol_tok_false),
            .len = JSON_FALSE_LEN,
            .error = JSON_OK,
        };
    } else if (len >= JSON_NULL_LEN && strneq(str, JSON_NULL, JSON_NULL_LEN)) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym(d->symbol_tok_null),
            .len = JSON_NULL_LEN,
            .error = JSON_OK,
        };
    } else {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym_nil,
            .len = 0,
            .error = JSON_OK,
        };
    }
}

/**
 * \param str Must have a length >= 1.
 */
static json_lex_unit_t json_lex_syntax(const char *str) {
    data *d = use_state();

    // if (!one_of(str[0], JSON_SYNTAX_CHARS)) {
    //     return (json_lex_unit_t){
    //         .token = VESC_IF->lbm_enc_sym_nil,
    //         .len = 0,
    //         .error = JSON_OK,
    //     };
    // }

    lbm_uint sym;

    switch (str[0]) {
        case JSON_COMMA: {
            sym = d->symbol_tok_comma;
            break;
        }
        case JSON_COLON: {
            sym = d->symbol_tok_colon;
            break;
        }
        case JSON_LEFT_BRACKET: {
            sym = d->symbol_tok_left_bracket;
            break;
        }
        case JSON_RIGHT_BRACKET: {
            sym = d->symbol_tok_right_bracket;
            break;
        }
        case JSON_LEFT_BRACE: {
            sym = d->symbol_tok_left_brace;
            break;
        }
        case JSON_RIGHT_BRACE: {
            sym = d->symbol_tok_right_brace;
            break;
        }
        default: {
            return (json_lex_unit_t){
                .token = VESC_IF->lbm_enc_sym_nil,
                .len = 0,
                .error = JSON_OK,
            };
        }
    }

    return (json_lex_unit_t){
        .token = VESC_IF->lbm_enc_sym(sym),
        .len = 1,
        .error = JSON_OK,
    };
}

/**
 * \param tokens a reference to a lbm linked lists containing the extracted
 * tokens. \return struct with the amount of characters consumed. Error field is
 * set to some other value than JSON_OK in case of an error. The token field is
 * set to nil except when an memory error has occurred, in which case the
 * 'out_of_memory symbol is returned (this is totally not convoluted).
 */
static json_lex_unit_t json_tokenize_step(const char *str, lbm_value *tokens) {
    size_t consumed = 0;

    {
        json_lex_unit_t result = json_lex_str(str);
        if (result.error != JSON_OK) {
            result.token = VESC_IF->lbm_enc_sym_nil;
            return result;
        }
        if (result.token == VESC_IF->lbm_enc_sym_merror) {
            return result;
        }

        if (result.token != VESC_IF->lbm_enc_sym_nil) {
            *tokens = VESC_IF->lbm_cons(result.token, *tokens);
        }
        str = str + result.len;
        consumed += result.len;
    }

    {
        json_lex_unit_t result = json_lex_number(str);
        if (result.error != JSON_OK) {
            result.token = VESC_IF->lbm_enc_sym_nil;
            return result;
        }

        if (result.token != VESC_IF->lbm_enc_sym_nil) {
            *tokens = VESC_IF->lbm_cons(result.token, *tokens);
        }
        str = str + result.len;
        consumed += result.len;
    }

    {
        json_lex_unit_t result = json_lex_bool_null(str);

        if (result.token != VESC_IF->lbm_enc_sym_nil) {
            *tokens = VESC_IF->lbm_cons(result.token, *tokens);
        }
        str = str + result.len;
        consumed += result.len;
    }

    bool char_valid = false;
    {
        json_lex_unit_t result = json_lex_syntax(str);

        if (result.token != VESC_IF->lbm_enc_sym_nil) {
            *tokens = VESC_IF->lbm_cons(result.token, *tokens);
            char_valid = true;
        }
        str = str + result.len;
        consumed += result.len;
    }

    {
        ssize_t count = first_not_of(str, JSON_WHITESPACE_CHARS);
        if (count == -1) {
            count = (ssize_t)strlen(str);
        }
        if (count > 0) {
            char_valid = true;
        }
        str = str + count;
        consumed += (size_t)count;
    }

    if (consumed == 0 && !char_valid) {
        return (json_lex_unit_t){
            .token = VESC_IF->lbm_enc_sym_nil,
            .error = JSON_INVALID_CHAR,
        };
    }

    return (json_lex_unit_t){
        .token = VESC_IF->lbm_enc_sym_nil,
        .len = consumed,
        .error = JSON_OK,
    };
}

/* **************************************************
 * Extensions
 */

/**
 * signature: (str-index-of str search [from-index])
 *
 * \return the found index or -1 if no match was found.
 */
static lbm_value ext_str_index_of(lbm_value *args, lbm_uint argn) {
    if ((argn != 2 && argn != 3) || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_byte_array(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    size_t from_index = 0;
    if (argn == 3) {
        if (!VESC_IF->lbm_is_number(args[2])) {
            return VESC_IF->lbm_enc_sym_terror;
        }

        from_index = (size_t)VESC_IF->lbm_dec_as_u32(args[2]);
    }

    const char *str = VESC_IF->lbm_dec_str(args[0]);
    const char *search = VESC_IF->lbm_dec_str(args[1]);

    if (from_index >= strlen(str)) {
        return VESC_IF->lbm_enc_sym_eerror;
    }

    ssize_t index = str_index_of(str + from_index, search);

    return VESC_IF->lbm_enc_i(index);
}

/**
 * signature: (str-n-eq str-a str-b n)
 */
static lbm_value ext_str_n_eq(lbm_value *args, lbm_uint argn) {
    if (argn != 3 || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_byte_array(args[1])
        || !VESC_IF->lbm_is_number(args[2])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    const char *a = VESC_IF->lbm_dec_str(args[0]);
    const char *b = VESC_IF->lbm_dec_str(args[1]);

    size_t n = (size_t)VESC_IF->lbm_dec_as_u32(args[2]);

    bool result = strneq(a, b, n);

    return lbm_enc_bool(result);
}

/**
 * signature: (str-extract-until str delims [skip-chars] start)
 */
static lbm_value ext_str_extract_until(lbm_value *args, lbm_uint argn) {
    if ((argn != 3 && argn != 4) || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_byte_array(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    lbm_value skip_chars_lbm;
    lbm_value start_lbm;
    if (argn == 3) {
        if (!VESC_IF->lbm_is_number(args[2])) {
            return VESC_IF->lbm_enc_sym_terror;
        }
        start_lbm = args[2];
    }
    if (argn == 4) {
        if (!VESC_IF->lbm_is_byte_array(args[2])
            || !VESC_IF->lbm_is_number(args[3])) {
            return VESC_IF->lbm_enc_sym_terror;
        }
        start_lbm = args[3];
    }

    const char *str = VESC_IF->lbm_dec_str(args[0]);
    const char *delims = VESC_IF->lbm_dec_str(args[1]);
    const char *skip = "";

    // placed here to make compiler shut up about "may be used uninitialized"
    if (argn == 4) {
        skip_chars_lbm = args[2];
    }

    if (argn == 4) {
        skip = VESC_IF->lbm_dec_str(skip_chars_lbm);
    }

    size_t n = strlen(str);
    size_t start = (size_t)VESC_IF->lbm_dec_as_u32(start_lbm);

    char dest[n + 1];

    str_extract_n_until_skip(dest, n, str, delims, skip, start);

    return lbm_create_str(dest);
}

/**
 * signature: (str-extract-while str delims [start])
 *
 * Extract the longest substring from a string that contains only the specified
 * characters, starting at index.
 *
 * \param str The string to extract from.
 * \param delims A string with the characters which dest will consist of
 * entirely.
 * \param start (option) The index of str where the substring starts. Default is
 * 0. \return the extracted substring.
 */
static lbm_value ext_str_extract_while(lbm_value *args, lbm_uint argn) {
    if ((argn != 2 && argn != 3) || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_byte_array(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    size_t start = 0;
    if (argn == 3) {
        if (!VESC_IF->lbm_is_number(args[2])) {
            return VESC_IF->lbm_enc_sym_terror;
        }
        start = VESC_IF->lbm_dec_as_u32(args[2]);
    }

    const char *str = VESC_IF->lbm_dec_str(args[0]);
    const char *delims = VESC_IF->lbm_dec_str(args[1]);

    size_t n = strlen(str);

    char dest[n + 1];

    str_extract_n_while(dest, n, str, delims, start);

    return lbm_create_str(dest);
}

/* signature: (puts ...values) */
static lbm_value ext_puts(lbm_value *args, lbm_uint argn) {
    if (argn == 0) {
        return VESC_IF->lbm_enc_sym_true;
    }

    const char *strings[argn];
    size_t res_len = 0;
    for (size_t i = 0; i < argn; i++) {
        if (!VESC_IF->lbm_is_byte_array(args[i])) {
            return VESC_IF->lbm_enc_sym_terror;
        }

        strings[i] = VESC_IF->lbm_dec_str(args[i]);
        res_len += strlen(strings[i]) + 1;
    }
    res_len -= 1;

    size_t offset = 0;
    char result[res_len + 1];
    for (size_t i = 0; i < argn; i++) {
        size_t len = strlen(strings[i]);
        memcpy(result + offset, strings[i], len);
        offset += len;
        result[offset++] = ' ';
    }
    result[res_len] = '\0';

    // VESC_IF->printf("%s", result);
    puts_long(result);

    return VESC_IF->lbm_enc_sym_true;
}

// /**
//  * signature: (rethrow value)
//  *
//  * Pass value throw, throwing an error if the value was one of the error
//  * symbols:
//  * - 'type_error
//  * - 'eval_error
//  * - 'out_of_memory
//  * - 'fatal_error
//  * - 'out_of_stack
//  * - 'division_by_zero
//  * - 'variable_not_bound
//  *
//  * \param value The value to pass through.
//  * \return the value if it wasn't one of the error symbols.
//  */
// static lbm_value ext_rethrow(lbm_value *args, lbm_uint argn) {
//     if (argn != 1) {
//         return VESC_IF->lbm_enc_sym_terror;
//     }

//     lbm_value value = args[0];
//     return value;
// }

/* signature: (ext-uart-write string) */
static lbm_value ext_uart_write(lbm_value *args, lbm_uint argn) {
    // VESC_IF->printf("uart_write");

    // data *d = (data *)ARG;
    // if (!d->paused) {
    //     return VESC_IF->lbm_enc_sym_nil;
    // }

    if (argn != 1 || !VESC_IF->lbm_is_byte_array(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    char *command = VESC_IF->lbm_dec_str(args[0]);
    // VESC_IF->printf("Start writing");
    VESC_IF->uart_write((uint8_t *)command, strlen(command));
    // VESC_IF->printf("DONE writing");
    return VESC_IF->lbm_enc_sym_true;
}

// Read line or at most `number` characters.
// Includes newline character.
/* signature: (ext-uart-readline dest len) */
static lbm_value ext_uart_readline(lbm_value *args, lbm_uint argn) {
    // data *d = (data *)ARG;
    // if (!d->paused) {
    //     return VESC_IF->lbm_enc_sym_nil;
    // }
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
    // data *d = (data *)ARG;
    // if (!d->paused) {
    //     return VESC_IF->lbm_enc_sym_nil;
    // }
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
    // data *d = (data *)ARG;
    // if (!d->paused) {
    //     return VESC_IF->lbm_enc_sym_nil;
    // }
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

static lbm_value ext_modem_pwr_on(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    modem_pwr_on();

    return VESC_IF->lbm_enc_sym_true;
}

static lbm_value ext_modem_pwr_off(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    bool result = modem_pwr_off();

    return lbm_enc_bool(result);
}

static lbm_value ext_at_init(lbm_value *args, lbm_uint argn) {
    (void)args;

    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    return lbm_enc_bool(at_init());
}

/* **************************************************
 * TCP Extensions
 * These must only be called by a single lbm thread.
 */

/**
 * signature: (tcp-status)
 *
 * \return one of the following symbols corresponding to the different statuses:
 * - 'disconnected
 * - 'closed-remote
 * - 'connected
 * - 'server-mode
 * Or 'error in the case of an internal AT or UART error.
 */
static lbm_value ext_tcp_status(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (!lbm_call_tcp_cmd(TCP_CMD_CHECK_STATUS, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-is-open)
 *
 * Check if there is a connection opened by `tcp-connect-host` that hasn't been
 * closed by `tcp-close-connection`.
 *
 * \return bool indicating if a connection is open.
 */
static lbm_value ext_tcp_is_open(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (!lbm_call_tcp_cmd(TCP_CMD_IS_OPEN, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-wait-until-connected timeout-ms)
 *
 * Wait until a connection is confirmed to be established. If no connection has
 * been opened before calling this through `tcp-connect-host`, this function
 * returns nil immediately.
 *
 * \return a bool specifying if a connection was confirmed within the timeout.
 */
static lbm_value ext_tcp_wait_until_connected(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_number(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    data *d = use_state();

    uint_t timeout_ms = VESC_IF->lbm_dec_as_u32(args[0]);

    // TODO: This assignment isn't really thread safe. This logic should be
    // placed inside lbm_call_tcp_cmd, with proper locks around it, but that
    // isn't possible as this logic is unique to this place, urgh..
    d->tcp_timeout_ms = timeout_ms;

    if (!lbm_call_tcp_cmd(TCP_CMD_WAIT_CONNECTED, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-close-connection)
 *
 * Close a connection opened by `tcp-connect-host`.
 *
 * Note: You always need to call this at least once for each call to
 * tcp-connect-host no matter what, as a connection is still considered open
 * even if the remote has disconnected.
 *
 * \return a bool specifying if a connection was open. 'error is returned when
 * an internal AT or UART error occurs.
 */
static lbm_value ext_tcp_close_connection(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (!lbm_call_tcp_cmd(TCP_CMD_CLOSE_CONNECTION, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }
    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-connect-host hostname port)
 *
 *
 *
 * \param hostname The hostname to connect to. Must not be longer than 100
 * characters (excluding terminating null byte).
 * \param port The tcp port of the host to connect to.
 * \return bool indicating if the connection was opened successfully
 * \throw Returns eval_error if hostname is too long, or if there was already an
 * open connection not closed by `tcp-close-connection`.
 */
static lbm_value ext_tcp_connect_host(lbm_value *args, lbm_uint argn) {
    if (argn != 2 || !VESC_IF->lbm_is_byte_array(args[0])
        || !VESC_IF->lbm_is_number(args[1])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    data *d = use_state();

    char *hostname = VESC_IF->lbm_dec_str(args[0]);
    uint16_t port = (uint16_t)VESC_IF->lbm_dec_as_u32(args[1]);

    if (strlen(hostname) > TCP_MAX_HOSTNAME_LEN) {
        return VESC_IF->lbm_enc_sym_eerror;
    }
    VESC_IF->mutex_lock(d->lock);
    strcpy(d->tcp_hostname, hostname);
    d->tcp_port = port;
    VESC_IF->mutex_unlock(d->lock);

    if (!lbm_call_tcp_cmd(TCP_CMD_CONNECT_HOST, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-send-str string)
 *
 * Send string over current tcp connection
 *
 * \return bool indicating success.
 * \throw Returns eval_error if there wasn't an open connection.
 */
static lbm_value ext_tcp_send_str(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_byte_array(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    data *d = use_state();

    char *str = VESC_IF->lbm_dec_str(args[0]);
    size_t len = strlen(str);

    char *send_buffer = VESC_IF->malloc(len + 1);
    if (!send_buffer) {
        return VESC_IF->lbm_enc_sym_merror;
    }
    strcpy(send_buffer, str);

    VESC_IF->mutex_lock(d->lock);
    d->tcp_send_buffer = send_buffer;
    VESC_IF->mutex_unlock(d->lock);

    if (!lbm_call_tcp_cmd(TCP_CMD_SEND, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        VESC_IF->free(send_buffer);
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-recv-single)
 *
 * Receive single string up to 100 characters long from the current tcp
 * connection. This function receives data available in this instant. You can
 * wait for data using `tcp-wait-for-recv`
 *
 * \return one of these possibilities:
 * - The received string,
 * - nil if no string was available,
 * - 'error in case of an internal AT or UART error.
 * \throw Returns memory_error if allocating the result string failed. If this
 * is returned, simply run gc and rerun the command. \throw Returns eval_error
 * if no connection was opened.
 */
static lbm_value ext_tcp_recv_single(lbm_value *args, lbm_uint argn) {
    (void)args;
    if (argn != 0) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    if (!lbm_call_tcp_cmd(TCP_CMD_RECV, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (tcp-wait-for-recv timeout_ms)
 *
 * Wait until there is data to receive using tcp-recv-single.
 * Will look for "+CADATAIND: <cid>" until it has been found or timeout has ran
 * out.
 *
 * \param timeout_ms How many milliseconds to search for at least.
 * \return bool indicating if any data was found.
 * \throw Returns eval_error if no connection was opened.
 */
static lbm_value ext_tcp_wait_for_recv(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_number(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    data *d = use_state();

    uint_t timeout_ms = VESC_IF->lbm_dec_as_u32(args[0]);

    // TODO: This assignment isn't really thread safe. This logic should be
    // placed inside lbm_call_tcp_cmd, with proper locks around it, but that
    // isn't possible as this logic is unique to this place, urgh..
    d->tcp_timeout_ms = timeout_ms;

    if (!lbm_call_tcp_cmd(TCP_CMD_WAIT_RECV, TCP_CMD_TIMEOUT_MS)) {
        VESC_IF->printf("lbm_call_tcp_cmd timeout");
        return VESC_IF->lbm_enc_sym_eerror;
    }

    return VESC_IF->lbm_enc_sym_nil;
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

// static void testing(const char *responses[]) {
//     VESC_IF->printf("responses: %p", responses);
//     VESC_IF->printf("responses[0]: (%p)", responses[0]);
//     VESC_IF->printf("responses[1]: (%p)", responses[1]);
// }

#define TCP_TEST_TIMES 10000
static lbm_value ext_tcp_test(lbm_value *args, lbm_uint argn) {
    (void)args;
    (void)argn;
    uint32_t start = time_now();

    for (size_t i = 0; i < TCP_TEST_TIMES; i++) {
        char delims[] = "0123456789";
        // char str[] = "\"foo\": [1, 2, {\"bar\": 2}]}";
        char str[] = "12345612, 2, {\"bar\": 2}]}";
        char dest[sizeof(str)];

        str_extract_n_while(dest, strlen(str), str, delims, 0);
    }

    float ms = time_ms_since(start);

    VESC_IF->printf("ran str_extract_n_while %d times", TCP_TEST_TIMES);
    VESC_IF->printf(
        "total: %fms, avg: %fms", (double)ms, (double)(ms / TCP_TEST_TIMES)
    );

    // data *d = use_state();

    // lbm_value argument = VESC_IF->lbm_enc_sym_nil;
    // if (argn >= 1) {
    //     argument = args[0];
    // }

    // d->tcp_test_str = argument;

    // if (!lbm_call_tcp_cmd(TCP_CMD_TEST, TCP_CMD_TIMEOUT_MS)) {
    //     VESC_IF->printf("lbm_call_tcp_cmd timeout");
    //     return VESC_IF->lbm_enc_sym_eerror;
    // }

    return VESC_IF->lbm_enc_sym_nil;
}

/**
 * signature: (json-tokenize str tokens)
 *
 * Perform a single step in the json tokenization loop
 *
 * \param str the current json string to tokenize.
 * \param tokens the current list of tokens.
 * \return list of three values:
 * 1. the new list of tokens,
 * 2. the new string,
 * 3. and the amount of characters consumed,
 * or an error symbol:
 * - 'error-unclosed-quote
 * - 'error-invalid-char
 */
static lbm_value ext_json_tokenize_step(lbm_value *args, lbm_uint argn) {
    if (argn != 2 || !VESC_IF->lbm_is_byte_array(args[0])
        || !(
            VESC_IF->lbm_is_cons(args[1]) || VESC_IF->lbm_is_symbol_nil(args[1])
        )) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    data *d = use_state();

    const char *str = VESC_IF->lbm_dec_str(args[0]);
    lbm_value tokens = args[1];

    json_lex_unit_t result = json_tokenize_step(str, &tokens);
    if (result.error != JSON_OK) {
        lbm_uint error_sym;
        switch (result.error) {
            case JSON_UNCLOSED_QUOTE: {
                error_sym = d->symbol_error_unclosed_quote;
                break;
            }
            case JSON_INVALID_CHAR: {
                error_sym = d->symbol_error_invalid_char;
                break;
            }
            default: {
                return VESC_IF->lbm_enc_sym_eerror;
            }
        }
        return VESC_IF->lbm_enc_sym(error_sym);
    }
    if (result.token == VESC_IF->lbm_enc_sym_merror) {
        return VESC_IF->lbm_enc_sym_merror;
    }

    lbm_value len = VESC_IF->lbm_enc_i(result.len);
    lbm_value result_str = lbm_create_str(str + result.len);
    if (result_str == VESC_IF->lbm_enc_sym_merror) {
        return VESC_IF->lbm_enc_sym_merror;
    }

    return VESC_IF->lbm_cons(
        tokens, VESC_IF->lbm_cons(
                    result_str, VESC_IF->lbm_cons(len, VESC_IF->lbm_enc_sym_nil)
                )
    );
}

static lbm_value ext_json_unescape_str(lbm_value *args, lbm_uint argn) {
    if (argn != 1 || !VESC_IF->lbm_is_byte_array(args[0])) {
        return VESC_IF->lbm_enc_sym_terror;
    }

    const char *str = VESC_IF->lbm_dec_str(args[0]);
    size_t len = strlen(str);
    char unescaped_str[len + 1];

    json_unescape_str(unescaped_str, str);

    return lbm_create_str(unescaped_str);
}

/* ------------------------------------------------------------
   INIT_FUN
   ------------------------------------------------------------ */

INIT_FUN(lib_info *info) {
    INIT_START;

    data *d = VESC_IF->malloc(sizeof(data));
    if (!d) return false;
    memset(d, 0, sizeof(data));

    info->stop_fun = stop;
    info->arg = d;

    d->lock = VESC_IF->mutex_create();
    // d->recv_filled = false;
    // d->recv_size = 0;
    d->tcp_state = TCP_STATE_NOT_CONNECTED;

    if (!register_symbols()) {
        VESC_IF->printf("register_symbols failed");
    };

    VESC_IF->uart_start(115200, false);

    VESC_IF->lbm_add_extension("str-index-of", ext_str_index_of);
    VESC_IF->lbm_add_extension("str-n-eq", ext_str_n_eq);
    VESC_IF->lbm_add_extension("str-extract-until", ext_str_extract_until);
    VESC_IF->lbm_add_extension("str-extract-while", ext_str_extract_while);
    VESC_IF->lbm_add_extension("puts", ext_puts);

    VESC_IF->lbm_add_extension("ext-uart-write", ext_uart_write);
    VESC_IF->lbm_add_extension("ext-uart-readline", ext_uart_readline);
    VESC_IF->lbm_add_extension(
        "ext-uart-readline-trim", ext_uart_readline_trim
    );
    VESC_IF->lbm_add_extension("ext-uart-read-until", ext_uart_read_until);
    VESC_IF->lbm_add_extension("ext-uart-purge", ext_uart_purge);
    VESC_IF->lbm_add_extension("ext-get-uuid", ext_get_uuid);
    VESC_IF->lbm_add_extension("ext-pwr-key", ext_pwr_key);
    VESC_IF->lbm_add_extension("modem-pwr-on", ext_modem_pwr_on);
    VESC_IF->lbm_add_extension("modem-pwr-off", ext_modem_pwr_off);
    VESC_IF->lbm_add_extension("at-init", ext_at_init);
    VESC_IF->lbm_add_extension("tcp-status", ext_tcp_status);
    VESC_IF->lbm_add_extension("tcp-is-open", ext_tcp_is_open);
    VESC_IF->lbm_add_extension(
        "tcp-wait-until-connected", ext_tcp_wait_until_connected
    );
    VESC_IF->lbm_add_extension(
        "tcp-close-connection", ext_tcp_close_connection
    );
    VESC_IF->lbm_add_extension("tcp-connect-host", ext_tcp_connect_host);
    VESC_IF->lbm_add_extension("tcp-send-str", ext_tcp_send_str);
    VESC_IF->lbm_add_extension("tcp-recv-single", ext_tcp_recv_single);
    VESC_IF->lbm_add_extension("tcp-wait-for-recv", ext_tcp_wait_for_recv);
    VESC_IF->lbm_add_extension("tcp-test", ext_tcp_test);

    VESC_IF->lbm_add_extension("json-tokenize-step", ext_json_tokenize_step);
    VESC_IF->lbm_add_extension("json-unescape-str", ext_json_unescape_str);

    VESC_IF->set_pad_mode(
        GPIOD, 8, PAL_STM32_MODE_OUTPUT | PAL_STM32_OTYPE_PUSHPULL
    );
    VESC_IF->clear_pad(GPIOD, 8);

    // VESC_IF->set_pad_mode(PWR_PORT, PWR_PAD, PAL_MODE_OUTPUT_PUSHPULL);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 0);
    // VESC_IF->sleep_ms(5);
    // VESC_IF->set_pad(PWR_PORT, PWR_PAD, 1);

    d->thread = VESC_IF->spawn(tcp_thd, 4096, "VESC-TCP", d);
    VESC_IF->printf("init fun");
    return true;
}
