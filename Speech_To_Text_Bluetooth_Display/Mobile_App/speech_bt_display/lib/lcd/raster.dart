/// Draws characters that have no hand-made LCD glyph (Chinese, Hindi, Hebrew, ...)
/// into 5x8 pixels using the phone's own fonts. 5x8 is very small, so complex
/// characters lose detail; the app says so in the preview.
library;

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'scripts.dart';

/// code point -> 8 row bytes
final Map<int, List<int>> rasterCache = {};

const int _ss = 6; // supersampling: draw at 30x48, then reduce to 5x8

/// Renders every character of [text] that needs it. Call before layout().
Future<void> prepareRaster(String text) async {
  for (final cp in text.runes) {
    if (needsRaster(cp) && !rasterCache.containsKey(cp)) {
      rasterCache[cp] = await _render(cp);
    }
  }
}

Future<List<int>> _render(int cp) async {
  const w = 5 * _ss, h = 8 * _ss;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(cp),
      style: const TextStyle(fontSize: h * 0.9, color: Color(0xFFFFFFFF), height: 1.0, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  // fit inside the cell, keep aspect ratio, centre
  final scale = [w / tp.width, h / tp.height, 1.0].reduce((a, b) => a < b ? a : b);
  canvas.translate((w - tp.width * scale) / 2, (h - tp.height * scale) / 2);
  canvas.scale(scale);
  tp.paint(canvas, Offset.zero);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  if (data == null) return List.filled(8, 0);

  final rows = <int>[];
  for (var y = 0; y < 8; y++) {
    var v = 0;
    for (var x = 0; x < 5; x++) {
      var sum = 0;
      for (var dy = 0; dy < _ss; dy++) {
        for (var dx = 0; dx < _ss; dx++) {
          final px = ((y * _ss + dy) * w + (x * _ss + dx)) * 4;
          sum += data.getUint8(px + 3); // alpha
        }
      }
      if (sum / (_ss * _ss) > 90) v |= 1 << (4 - x);
    }
    rows.add(v);
  }
  return rows;
}
