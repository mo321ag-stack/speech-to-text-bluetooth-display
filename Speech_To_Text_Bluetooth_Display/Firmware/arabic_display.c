/* arabic_display.c - page storage, word wrap, CGRAM glyph loading and page cycling. */
#include "arabic_display.h"
#include "lcd_i2c.h"
#include <avr/pgmspace.h>
#include <string.h>

#define MAX_LINES (MAX_TEXT_PAGES * LCD_ROWS)

typedef struct {
    uint8_t n_glyphs;
    uint8_t glyphs[GLYPHS_PER_PAGE][8];
    uint8_t cells[CELLS_PER_PAGE];
} glyph_page_t;

typedef enum { MODE_NONE, MODE_TEXT, MODE_GLYPHS, MODE_LOADING } disp_mode_t;

/* Text and glyph pages are never shown at the same time: share the RAM (2 KB total). */
static union {
    struct {
        char    text[MAX_TEXT_LEN + 1];
        uint8_t start[MAX_LINES];
        uint8_t len[MAX_LINES];
        uint8_t n_lines;
    } t;
    glyph_page_t pages[MAX_GLYPH_PAGES];
} u;

static disp_mode_t   mode = MODE_NONE;
static uint8_t  n_pages, cur_page, dirty;
static uint8_t  received_mask;
static uint16_t page_ms = DEFAULT_PAGE_MS;
static uint32_t last_switch;

/* ---------- built-in Arabic test: "مرحبا" ----------
 * Shaped forms in visual (left-to-right on screen) order:
 *   ALEF final, BEH medial, HAH initial, REH final, MEEM initial.
 * 5x8 bitmaps, bit 4 = leftmost pixel. */
static const uint8_t demo_glyphs[5][8] PROGMEM = {
    { 0x04, 0x04, 0x04, 0x04, 0x04, 0x07, 0x00, 0x00 },  /* alef, final   */
    { 0x00, 0x00, 0x00, 0x00, 0x04, 0x1F, 0x00, 0x04 },  /* beh, medial   */
    { 0x00, 0x00, 0x1C, 0x04, 0x08, 0x1F, 0x00, 0x00 },  /* hah, initial  */
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x04, 0x18 },  /* reh, final    */
    { 0x00, 0x00, 0x00, 0x06, 0x09, 0x1F, 0x00, 0x00 },  /* meem, initial */
};
static const char demo_line2[] PROGMEM = "  Arabic test   ";

void display_init(void)
{
    mode = MODE_NONE;
    n_pages = 0;
}

void display_set_page_time(uint16_t ms) { page_ms = ms < 500 ? 500 : ms; }
uint8_t display_page_count(void) { return n_pages; }

void display_clear(void)
{
    mode = MODE_NONE;
    n_pages = 0;
    lcd_clear();
}

/* ---------- English / ASCII: greedy word wrap into 16-column lines ---------- */
void display_show_text(const char *ascii, uint8_t len)
{
    if (len > MAX_TEXT_LEN) len = MAX_TEXT_LEN;
    memcpy(u.t.text, ascii, len);
    u.t.text[len] = 0;

    uint8_t pos = 0, n = 0;
    while (pos < len && n < MAX_LINES) {
        while (pos < len && u.t.text[pos] == ' ') pos++;      /* no leading spaces */
        if (pos >= len) break;
        uint8_t remaining = (uint8_t)(len - pos);
        uint8_t take = remaining < LCD_COLS ? remaining : LCD_COLS;
        if (remaining > LCD_COLS && u.t.text[pos + LCD_COLS] != ' ') {
            /* the 17th character is inside a word: break at the last space instead */
            for (uint8_t i = LCD_COLS - 1; i > 0; i--) {
                if (u.t.text[pos + i] == ' ') { take = i; break; }
            }
        }
        u.t.start[n] = pos;
        u.t.len[n] = take;
        n++;
        pos = (uint8_t)(pos + take);
    }
    u.t.n_lines = n;
    n_pages = (uint8_t)((n + LCD_ROWS - 1) / LCD_ROWS);
    if (n_pages == 0) n_pages = 1;
    mode = MODE_TEXT;
    cur_page = 0;
    dirty = 1;
}

static void render_text_page(uint8_t p)
{
    for (uint8_t r = 0; r < LCD_ROWS; r++) {
        uint8_t li = (uint8_t)(p * LCD_ROWS + r);
        if (li < u.t.n_lines) lcd_write_row(r, (const uint8_t *)&u.t.text[u.t.start[li]], u.t.len[li]);
        else lcd_write_row(r, (const uint8_t *)"", 0);
    }
}

/* ---------- Glyph pages (Arabic) ---------- */
uint8_t display_pages_begin(uint8_t count, uint16_t ms)
{
    if (count == 0 || count > MAX_GLYPH_PAGES) return 0;
    mode = MODE_LOADING;
    n_pages = count;
    received_mask = 0;
    if (ms) display_set_page_time(ms);
    return 1;
}

uint8_t display_page_set(uint8_t index, uint8_t n_glyphs, const uint8_t *glyph_rows, const uint8_t *cells)
{
    if (mode != MODE_LOADING || index >= n_pages || n_glyphs > GLYPHS_PER_PAGE) return 0;
    glyph_page_t *pg = &u.pages[index];
    pg->n_glyphs = n_glyphs;
    memcpy(pg->glyphs, glyph_rows, (uint16_t)n_glyphs * 8);
    memcpy(pg->cells, cells, CELLS_PER_PAGE);
    /* A cell code 0..7 must refer to a glyph that was actually sent. */
    for (uint8_t i = 0; i < CELLS_PER_PAGE; i++) {
        if (pg->cells[i] < 8 && pg->cells[i] >= n_glyphs) pg->cells[i] = ' ';
        else if (pg->cells[i] >= 8 && (pg->cells[i] < 0x20 || pg->cells[i] > 0x7E)) pg->cells[i] = ' ';
    }
    received_mask |= (uint8_t)(1 << index);
    return 1;
}

uint8_t display_pages_end(void)
{
    if (mode != MODE_LOADING) return 0;
    if (received_mask != (uint8_t)((1u << n_pages) - 1)) return 0;   /* a page is missing */
    mode = MODE_GLYPHS;
    cur_page = 0;
    dirty = 1;
    return 1;
}

static void render_glyph_page(uint8_t p)
{
    const glyph_page_t *pg = &u.pages[p];
    for (uint8_t g = 0; g < pg->n_glyphs; g++) lcd_create_char(g, pg->glyphs[g]);
    lcd_write_row(0, pg->cells, LCD_COLS);
    lcd_write_row(1, pg->cells + LCD_COLS, LCD_COLS);
}

void display_show_arabic_demo(void)
{
    uint8_t rows[5][8];
    uint8_t cells[CELLS_PER_PAGE];
    memcpy_P(rows, demo_glyphs, sizeof rows);
    memset(cells, ' ', sizeof cells);
    for (uint8_t i = 0; i < 5; i++) cells[5 + i] = i;       /* centred on row 1 */
    memcpy_P(cells + LCD_COLS, demo_line2, LCD_COLS);
    display_pages_begin(1, 0);
    display_page_set(0, 5, &rows[0][0], cells);
    display_pages_end();
}

void display_tick(uint32_t now)
{
    if (mode != MODE_TEXT && mode != MODE_GLYPHS) return;
    if (!dirty && n_pages > 1 && (now - last_switch) >= page_ms) {
        cur_page = (uint8_t)((cur_page + 1) % n_pages);
        dirty = 1;
    }
    if (dirty) {
        dirty = 0;
        last_switch = now;
        if (mode == MODE_TEXT) render_text_page(cur_page);
        else render_glyph_page(cur_page);
    }
}
