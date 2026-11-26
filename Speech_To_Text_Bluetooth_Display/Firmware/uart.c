/* uart.c - ATmega32A USART: RXD = PD0 (pin 14), TXD = PD1 (pin 15). 8N1. */
#include "config.h"
#include "uart.h"
#include <avr/interrupt.h>
#include <avr/io.h>
#include <avr/pgmspace.h>
#include <util/atomic.h>

#define MASK (UART_RX_BUF_SIZE - 1)
#if (UART_RX_BUF_SIZE & MASK) != 0
#error "UART_RX_BUF_SIZE must be a power of two"
#endif

static volatile uint8_t  rx_buf[UART_RX_BUF_SIZE];
static volatile uint8_t  rx_head, rx_tail;
static volatile uint16_t rx_overflows, rx_errors;

ISR(USART_RXC_vect)
{
    uint8_t status = UCSRA;              /* read status BEFORE data */
    uint8_t data = UDR;
    if (status & ((1 << FE) | (1 << DOR))) rx_errors++;
    uint8_t next = (uint8_t)((rx_head + 1) & MASK);
    if (next == rx_tail) { rx_overflows++; return; }   /* buffer full: drop byte, count it */
    rx_buf[rx_head] = data;
    rx_head = next;
}

void uart_init(uint32_t baud)
{
    /* Double speed (U2X) gives the smallest error: 8 MHz / 9600 -> UBRR 103, error 0.2 % */
    uint16_t ubrr = (uint16_t)(((F_CPU + baud * 4UL) / (baud * 8UL)) - 1UL);
    UBRRH = (uint8_t)(ubrr >> 8);
    UBRRL = (uint8_t)ubrr;
    UCSRA = (1 << U2X);
    UCSRB = (1 << RXEN) | (1 << TXEN) | (1 << RXCIE);
    UCSRC = (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0); /* 8 data, no parity, 1 stop */
}

uint8_t uart_available(void)
{
    uint8_t n;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { n = (uint8_t)((rx_head - rx_tail) & MASK); }
    return n;
}

int16_t uart_read(void)
{
    if (rx_head == rx_tail) return -1;
    uint8_t c = rx_buf[rx_tail];
    rx_tail = (uint8_t)((rx_tail + 1) & MASK);
    return c;
}

void uart_putc(char c)
{
    while (!(UCSRA & (1 << UDRE))) { }
    UDR = (uint8_t)c;
}

void uart_puts(const char *s) { while (*s) uart_putc(*s++); }

void uart_puts_P(const char *p)
{
    char c;
    while ((c = (char)pgm_read_byte(p++)) != 0) uart_putc(c);
}

void uart_put_hex(uint8_t v)
{
    static const char hex[] = "0123456789ABCDEF";
    uart_putc(hex[v >> 4]);
    uart_putc(hex[v & 0x0F]);
}

void uart_put_u16(uint16_t v)
{
    char tmp[6];
    uint8_t i = 0;
    do { tmp[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i) uart_putc(tmp[--i]);
}

uint16_t uart_overflows(void)
{
    uint16_t v;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { v = rx_overflows; }
    return v;
}

uint16_t uart_line_errors(void)
{
    uint16_t v;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { v = rx_errors; }
    return v;
}
