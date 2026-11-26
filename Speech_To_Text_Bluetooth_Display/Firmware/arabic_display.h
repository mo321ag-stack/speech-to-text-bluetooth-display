/*
 * arabic_display.h - what is on the LCD and how long messages are paged.
 *
 * Two kinds of content:
 *  - ASCII text (English): laid out here, word-wrapped into 16x2 pages.
 *  - Glyph pages (Arabic, or Arabic mixed with English): the phone does the Arabic
 *    shaping (isolated / initial / medial / final forms), right-to-left ordering and
 *    page layout, and sends for each page up to 8 custom 5x8 glyphs plus the 32 cell
 *    codes. This module stores the pages, loads the glyphs into the LCD's CGRAM and
 *    cycles through them.
 *
 * Hardware limit: an HD44780 has only 8 user-definable characters at a time, so one
 * screen can show at most 8 DIFFERENT Arabic letter shapes. The phone splits longer
 * Arabic text into several pages so that no page needs more than 8.
 */
#ifndef ARABIC_DISPLAY_H
#define ARABIC_DISPLAY_H

#include <stdint.h>
#include "config.h"

#define CELLS_PER_PAGE  (LCD_COLS * LCD_ROWS)
#define GLYPHS_PER_PAGE 8

void    display_init(void);
void    display_show_text(const char *ascii, uint8_t len);     /* English / ASCII */
void    display_clear(void);
void    display_set_page_time(uint16_t ms);
/* Glyph pages (Arabic). Returns 1 on success, 0 on a bad argument. */
uint8_t display_pages_begin(uint8_t count, uint16_t page_ms);
uint8_t display_page_set(uint8_t index, uint8_t n_glyphs, const uint8_t *glyph_rows, const uint8_t *cells);
uint8_t display_pages_end(void);
void    display_show_arabic_demo(void);   /* built-in test: "مرحبا" */
void    display_tick(uint32_t now_ms);    /* call often: advances pages */
uint8_t display_page_count(void);

#endif
