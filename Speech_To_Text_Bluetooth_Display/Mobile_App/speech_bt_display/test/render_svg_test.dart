// Renders LCD pages to SVG images for the README, using the real layout + font code.
// Runs only when SVG_DIR is set:  SVG_DIR=../../../docs/images flutter test test/render_svg_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_bt_display/lcd/lcd_layout.dart';

String lcdSvg(LcdPage page, {String caption = ''}) {
  const px = 4.0, gap = 1.0, cellW = 5 * px + 4 * gap, cellH = 8 * px + 7 * gap, cellGap = 3.0, pad = 14.0;
  final w = pad * 2 + kCols * cellW + (kCols - 1) * cellGap;
  final h = pad * 2 + kRows * cellH + (kRows - 1) * cellGap * 2 + (caption.isEmpty ? 0 : 22);
  final b = StringBuffer()
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" width="${w.toInt()}" height="${h.toInt()}" viewBox="0 0 $w $h">')
    ..writeln('<rect width="$w" height="$h" rx="10" fill="#1d3fbf"/>')
    ..writeln('<rect x="6" y="6" width="${w - 12}" height="${h - 12 - (caption.isEmpty ? 0 : 22)}" rx="6" fill="#2e5bff"/>');
  for (var r = 0; r < kRows; r++) {
    for (var c = 0; c < kCols; c++) {
      final ox = pad + c * (cellW + cellGap), oy = pad + r * (cellH + cellGap * 2);
      final code = page.cells[r * kCols + c];
      final glyph = code < 8 && code < page.glyphs.length ? page.glyphs[code] : null;
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 5; x++) {
          final on = glyph != null && (glyph[y] >> (4 - x)) & 1 == 1;
          b.writeln('<rect x="${ox + x * (px + gap)}" y="${oy + y * (px + gap)}" width="$px" height="$px" '
              'fill="${on ? '#eef3ff' : '#4a72ff'}"/>');
        }
      }
      if (glyph == null && code > 0x20 && code <= 0x7E) {
        final ch = String.fromCharCode(code).replaceAll('&', '&amp;').replaceAll('<', '&lt;');
        b.writeln('<text x="${ox + cellW / 2}" y="${oy + cellH * 0.82}" font-family="Consolas,monospace" '
            'font-size="${cellH * 0.95}" font-weight="bold" text-anchor="middle" fill="#eef3ff">$ch</text>');
      }
    }
  }
  if (caption.isNotEmpty) {
    b.writeln('<text x="${w / 2}" y="${h - 9}" font-family="Segoe UI,Arial,sans-serif" font-size="13" '
        'text-anchor="middle" fill="#dbe4ff">$caption</text>');
  }
  b.writeln('</svg>');
  return b.toString();
}

void main() {
  final dir = Platform.environment['SVG_DIR'];
  test('render README images', () {
    Directory(dir!).createSync(recursive: true);
    final samples = {
      'lcd_arabic.svg': ('مرحبا بكم في فلسطين', 'Arabic: shaped 5x8 glyphs, right-to-left'),
      'lcd_mixed.svg': ('مرحبا ESP32', 'Arabic + English in one line'),
      'lcd_russian.svg': ('Привет мир', 'Russian, transliterated for the LCD ROM'),
    };
    samples.forEach((file, s) {
      final res = layout(s.$1);
      File('$dir/$file').writeAsStringSync(lcdSvg(res.pages.first, caption: s.$2));
    });
  }, skip: dir == null ? 'set SVG_DIR to run' : false);
}
