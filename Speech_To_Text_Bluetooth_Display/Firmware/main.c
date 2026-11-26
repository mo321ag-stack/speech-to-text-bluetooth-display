/*
 * main.c - Speech-to-Text Bluetooth Display (ATmega32A).
 *
 * HC-05  TXD -> PD0/RXD (pin 14)      HC-05 RXD <- PD1/TXD (pin 15) through 1k/2k divider
 * LCD    SDA -> PC1 (pin 23)          LCD SCL  -> PC0 (pin 22)
 *
 * Start-up report on the UART (visible in a Bluetooth terminal):
 *   "BTLCD 1.0 LCD=0x27 RST=xx"
 */
#include "config.h"
#include <avr/interrupt.h>
#include <avr/io.h>
#include <avr/pgmspace.h>
#include <string.h>
#include <util/atomic.h>
#include <util/delay.h>

#include "arabic_display.h"
#include "lcd_i2c.h"
#include "protocol.h"
#include "twi_i2c.h"
#include "uart.h"

/* ---------- 1 ms time base: Timer0 CTC, 8 MHz / 64 / 125 = 1 kHz ---------- */
static volatile uint32_t s_ms;

ISR(TIMER0_COMP_vect) { s_ms++; }

static void timer0_init(void)
{
    TCCR0 = (1 << WGM01) | (1 << CS01) | (1 << CS00);   /* CTC, prescaler 64 */
    OCR0 = (uint8_t)(F_CPU / 64UL / 1000UL - 1UL);      /* 124 at 8 MHz */
    TIMSK |= (1 << OCIE0);
}

static uint32_t millis(void)
{
    uint32_t v;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { v = s_ms; }
    return v;
}

/* ---------- replies ---------- */
static void ack(uint8_t type)
{
    uart_puts_P(PSTR("ACK "));
    uart_put_hex(type);
    uart_putc('\n');
}

static void nak(uint8_t type, const char *reason_P)
{
    uart_puts_P(PSTR("NAK "));
    uart_put_hex(type);
    uart_putc(' ');
    uart_puts_P(reason_P);
    uart_putc('\n');
}

static void print_info(void)
{
    uart_puts_P(PSTR("BTLCD " FW_VERSION " LCD=0x"));
    uart_put_hex(lcd_address());
    uart_puts_P(PSTR(" OVF="));
    uart_put_u16(uart_overflows());
    uart_puts_P(PSTR(" UERR="));
    uart_put_u16(uart_line_errors());
    uart_putc('\n');
}

/* ---------- binary frames from the phone app ---------- */
static void on_frame(uint8_t type, const uint8_t *p, uint8_t len)
{
    switch (type) {
    case MSG_TEXT: {
        /* Only printable ASCII is valid here; anything else is replaced by '?'. */
        char buf[MAX_TEXT_LEN];
        for (uint8_t i = 0; i < len; i++) buf[i] = (p[i] >= 0x20 && p[i] <= 0x7E) ? (char)p[i] : '?';
        display_show_text(buf, len);
        ack(type);
        break;
    }
    case MSG_CLEAR:
        display_clear();
        ack(type);
        break;
    case MSG_PING:
        uart_puts_P(PSTR("PONG " FW_VERSION "\n"));
        break;
    case MSG_BACKLIGHT:
        if (len != 1) { nak(type, PSTR("len")); break; }
        lcd_backlight(p[0]);
        ack(type);
        break;
    case MSG_PAGES_BEGIN:
        if (len != 2 || !display_pages_begin(p[0], (uint16_t)p[1] * 100U)) { nak(type, PSTR("count")); break; }
        ack(type);
        break;
    case MSG_PAGE: {
        if (len < 2) { nak(type, PSTR("len")); break; }
        uint8_t n = p[1];
        if (n > GLYPHS_PER_PAGE || len != (uint8_t)(2 + n * 8 + CELLS_PER_PAGE)) { nak(type, PSTR("len")); break; }
        if (!display_page_set(p[0], n, p + 2, p + 2 + n * 8)) { nak(type, PSTR("page")); break; }
        ack(type);
        break;
    }
    case MSG_PAGES_END:
        if (!display_pages_end()) { nak(type, PSTR("missing_page")); break; }
        ack(type);
        break;
    default:
        nak(type, PSTR("unknown"));
    }
}

/* ---------- plain text lines (Bluetooth terminal testing) ---------- */
static void on_line(const char *line, uint8_t len)
{
    if (line[0] == '#') {
        if (!strcmp_P(line, PSTR("#HELLO"))) display_show_text("HELLO WORLD", 11);
        else if (!strcmp_P(line, PSTR("#AR"))) display_show_arabic_demo();
        else if (!strcmp_P(line, PSTR("#CLR"))) display_clear();
        else if (!strcmp_P(line, PSTR("#INFO"))) { print_info(); return; }
        else { uart_puts_P(PSTR("ERR cmd\n")); return; }
        uart_puts_P(PSTR("OK\n"));
        return;
    }
    display_show_text(line, len);
    uart_puts_P(PSTR("OK\n"));
}

int main(void)
{
    uint8_t reset_cause = MCUCSR;
    MCUCSR = 0;

#if USE_OSCCAL_8MHZ
    OSCCAL = OSCCAL_8MHZ;     /* 8 MHz calibration byte of this chip (see config.h) */
    _delay_ms(1);
#endif

    uart_init(UART_BAUD);
    timer0_init();
    twi_init(TWI_SCL_HZ);
    sei();

    lcd_init();
    display_init();
    protocol_init(on_frame, on_line);

    if (lcd_present()) {
        lcd_set_cursor(0, 0);
        lcd_puts_P(PSTR("BT Display " FW_VERSION));
        lcd_set_cursor(0, 1);
        lcd_puts_P(PSTR("Waiting text..."));
    }
    print_info();
    uart_puts_P(PSTR("RST=0x"));
    uart_put_hex(reset_cause);
    uart_putc('\n');
    if (!lcd_present()) uart_puts_P(PSTR("WARN no LCD on I2C (check SDA pin23, SCL pin22, 5V)\n"));

    for (;;) {
        uint32_t now = millis();
        int16_t c;
        while ((c = uart_read()) >= 0) protocol_feed((uint8_t)c, now);
        protocol_poll(now);
        display_tick(now);
    }
}
