/* protocol.c - byte-by-byte frame parser with CRC and timeouts. */
#include "config.h"
#include "protocol.h"
#include "uart.h"
#include <avr/pgmspace.h>

typedef enum { ST_IDLE, ST_SYNC2, ST_TYPE, ST_LEN, ST_PAYLOAD, ST_CRC } state_t;

static state_t  st = ST_IDLE;
static uint8_t  f_type, f_len, f_pos, f_crc;
static uint8_t  payload[MAX_PAYLOAD];
static uint32_t last_byte_ms;

static char     line[MAX_TEXT_LEN + 1];
static uint8_t  line_len;
static uint8_t  utf8_skip;          /* continuation bytes left in a non-ASCII character */

static frame_handler_t s_frame;
static line_handler_t  s_line;

uint8_t crc8_update(uint8_t crc, uint8_t data)
{
    crc ^= data;
    for (uint8_t i = 0; i < 8; i++) crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x07) : (uint8_t)(crc << 1);
    return crc;
}

static void nak(uint8_t type, const char *reason_P)
{
    uart_puts_P(PSTR("NAK "));
    uart_put_hex(type);
    uart_putc(' ');
    uart_puts_P(reason_P);
    uart_putc('\n');
}

void protocol_init(frame_handler_t on_frame, line_handler_t on_line)
{
    s_frame = on_frame;
    s_line = on_line;
    st = ST_IDLE;
    line_len = 0;
}

static void flush_line(void)
{
    if (line_len) {
        line[line_len] = 0;
        s_line(line, line_len);
    }
    line_len = 0;
    utf8_skip = 0;
}

/* Plain-text mode: keep ASCII, replace each non-ASCII (UTF-8) character with '?'. */
static void text_byte(uint8_t b)
{
    if (b == '\n') { flush_line(); return; }
    if (b == '\r') return;
    if (utf8_skip) { if ((b & 0xC0) == 0x80) { utf8_skip--; return; } utf8_skip = 0; }
    if (b >= 0xC0) {                                     /* UTF-8 lead byte */
        utf8_skip = (b >= 0xF0) ? 3 : (b >= 0xE0) ? 2 : 1;
        b = '?';
    } else if (b >= 0x80 || b < 0x20) {
        return;                                          /* stray byte: ignore */
    }
    if (line_len < MAX_TEXT_LEN) line[line_len++] = (char)b;
}

void protocol_feed(uint8_t b, uint32_t now)
{
    last_byte_ms = now;
    switch (st) {
    case ST_IDLE:
        /* 0xAA can only start a frame at the beginning of a message; inside UTF-8 text
           it is a continuation byte (e.g. Arabic letter TEH = D8 AA). */
        if (b == FRAME_SYNC1 && line_len == 0 && utf8_skip == 0) st = ST_SYNC2;
        else text_byte(b);
        break;
    case ST_SYNC2:
        st = (b == FRAME_SYNC2) ? ST_TYPE : ST_IDLE;
        break;
    case ST_TYPE:
        f_type = b;
        f_crc = crc8_update(0, b);
        st = ST_LEN;
        break;
    case ST_LEN:
        f_len = b;
        f_crc = crc8_update(f_crc, b);
        f_pos = 0;
        if (f_len > MAX_PAYLOAD) { nak(f_type, PSTR("too_long")); st = ST_IDLE; }
        else st = f_len ? ST_PAYLOAD : ST_CRC;
        break;
    case ST_PAYLOAD:
        payload[f_pos++] = b;
        f_crc = crc8_update(f_crc, b);
        if (f_pos == f_len) st = ST_CRC;
        break;
    case ST_CRC:
        st = ST_IDLE;
        if (b != f_crc) { nak(f_type, PSTR("crc")); break; }
        s_frame(f_type, payload, f_len);
        break;
    }
}

void protocol_poll(uint32_t now)
{
    if (st != ST_IDLE && (now - last_byte_ms) > FRAME_TIMEOUT_MS) {
        nak(f_type, PSTR("timeout"));
        st = ST_IDLE;
    }
    if (st == ST_IDLE && line_len && (now - last_byte_ms) > LINE_TIMEOUT_MS) flush_line();
}
