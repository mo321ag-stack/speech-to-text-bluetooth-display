import 'package:material_ui/material_ui.dart';

import '../lcd/lcd_layout.dart';

/// Draws a 16x2 LCD page: Arabic glyph cells pixel by pixel (exactly what the LCD
/// will show), ASCII cells as text.
class LcdPreview extends StatelessWidget {
  final LcdPage? page;
  const LcdPreview({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // the LCD itself is always addressed left to right
      child: AspectRatio(
        aspectRatio: 16 * 6 / (2 * 9 + 2),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFF2E5BFF), borderRadius: BorderRadius.circular(6)),
          child: CustomPaint(painter: _LcdPainter(page)),
        ),
      ),
    );
  }
}

class _LcdPainter extends CustomPainter {
  final LcdPage? page;
  _LcdPainter(this.page);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / kCols;
    final cellH = size.height / kRows;
    final px = cellW / 6; // 5 pixels + 1 gap
    final pyStep = cellH / 9; // 8 pixels + 1 gap
    final on = Paint()..color = const Color(0xFFF1F5FF);
    final off = Paint()..color = const Color(0x22FFFFFF);

    for (var r = 0; r < kRows; r++) {
      for (var c = 0; c < kCols; c++) {
        final ox = c * cellW;
        final oy = r * cellH;
        final code = page?.cells[r * kCols + c] ?? 0x20;
        if (page != null && code < 8 && code < page!.glyphs.length) {
          final rows = page!.glyphs[code];
          for (var y = 0; y < 8; y++) {
            for (var x = 0; x < 5; x++) {
              final lit = (rows[y] >> (4 - x)) & 1 == 1;
              canvas.drawRect(Rect.fromLTWH(ox + x * px, oy + y * pyStep, px * 0.9, pyStep * 0.9), lit ? on : off);
            }
          }
        } else {
          for (var y = 0; y < 8; y++) {
            for (var x = 0; x < 5; x++) {
              canvas.drawRect(Rect.fromLTWH(ox + x * px, oy + y * pyStep, px * 0.9, pyStep * 0.9), off);
            }
          }
          if (code >= 0x21 && code <= 0x7E) {
            final tp = TextPainter(
              text: TextSpan(
                text: String.fromCharCode(code),
                style: TextStyle(color: on.color, fontSize: pyStep * 7.5, fontFamily: 'monospace', height: 1),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, Offset(ox + (px * 5 - tp.width) / 2, oy + (pyStep * 8 - tp.height) / 2));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LcdPainter old) => old.page != page;
}
