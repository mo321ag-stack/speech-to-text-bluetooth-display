/*
 * protocol.h - framing between the phone app and the ATmega32A.
 *
 * Binary frame (sent by the app):
 *   0xAA 0x55 | TYPE | LEN | PAYLOAD[LEN] | CRC8
 *   CRC8 = CRC-8/SMBUS (poly 0x07, init 0x00) over TYPE, LEN and PAYLOAD.
 *
 * Plain-text fallback (for testing with any Bluetooth serial terminal):
 *   ASCII text ending with '\n' (or a 600 ms pause) is shown as English text.
 *   Lines starting with '#' are test commands: #HELLO #AR #CLR #INFO
 *
 * Every frame is answered on the UART:  "ACK tt\n"  or  "NAK tt reason\n".
 */
#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <stdint.h>

/* Frame types */
#define MSG_TEXT          0x01  /* payload: ASCII 0x20..0x7E, shown left-to-right */
#define MSG_CLEAR         0x02  /* no payload */
#define MSG_PING          0x03  /* no payload, answered with "PONG <version>" */
#define MSG_BACKLIGHT     0x04  /* payload: 1 byte, 0 = off, 1 = on */
#define MSG_PAGES_BEGIN   0x10  /* payload: page count, page time in 100 ms units */
#define MSG_PAGE          0x11  /* payload: index, n (0..8), n x 8 glyph rows, 32 cells */
#define MSG_PAGES_END     0x12  /* no payload: start showing the pages */

typedef void (*frame_handler_t)(uint8_t type, const uint8_t *payload, uint8_t len);
typedef void (*line_handler_t)(const char *line, uint8_t len);

void    protocol_init(frame_handler_t on_frame, line_handler_t on_line);
void    protocol_feed(uint8_t byte, uint32_t now_ms);
void    protocol_poll(uint32_t now_ms);     /* timeouts */
uint8_t crc8_update(uint8_t crc, uint8_t data);

#endif
