/* uart.h - interrupt-driven USART receive with a ring buffer, blocking transmit. */
#ifndef UART_H
#define UART_H

#include <stdint.h>

void     uart_init(uint32_t baud);
uint8_t  uart_available(void);
int16_t  uart_read(void);             /* -1 when empty */
void     uart_putc(char c);
void     uart_puts(const char *s);
void     uart_puts_P(const char *progmem_s);
void     uart_put_hex(uint8_t v);
void     uart_put_u16(uint16_t v);
/* Counters since start-up (read-only diagnostics). */
uint16_t uart_overflows(void);
uint16_t uart_line_errors(void);     /* framing / data-overrun errors */

#endif
