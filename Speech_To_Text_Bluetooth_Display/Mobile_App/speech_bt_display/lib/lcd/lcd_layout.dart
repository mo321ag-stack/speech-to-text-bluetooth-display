/// Lays shaped text out into 16x2 LCD pages, respecting the HD44780 limit of
/// 8 custom characters per screen.
library;

import 'arabic_shaper.dart';

const int kCols = 16;
const int kRows = 2;
const int kMaxGlyphsPerPage = 8;
const int kMaxPages = 8; // must match MAX_GLYPH_PAGES in the firmware

class LcdPage {
  /// Up to 8 glyphs, each 8 row bytes. Cell code i (0..7) shows glyph i.
  final List<List<int>> glyphs;

  /// 32 cell codes: row 0 then row 1, left to right as seen on the screen.
  final List<int> cells;

  /// Same cells as units, for the on-screen preview.
  final List<Unit?> units;

  LcdPage(this.glyphs, this.cells, this.units);
}

class LayoutResult {
  final List<LcdPage> pages;
  final bool rtl;
  final bool truncated; // more than kMaxPages were needed
  final int unsupportedChars;
  /// True when custom glyphs are needed (Arabic, rasterised scripts).
  final bool hasArabic;
  /// The text as LCD ASCII (accents removed, Cyrillic/Greek transliterated).
  /// Used when no custom glyphs are needed: the ATmega wraps it itself.
  final String asciiText;
  LayoutResult(this.pages, this.rtl, this.truncated, this.unsupportedChars, this.hasArabic, this.asciiText);
}

class _Block {
  final List<Unit> units; // logical order
  _Block(this.units);
  int get width => units.length;
  Set<String> get glyphKeys => {for (final u in units) if (u.isGlyph) u.glyphKey!};
  bool get rtl => units.any((u) => u.rtl);
  List<Unit> get visual => rtl ? units.reversed.toList() : units;
}

/// Splits a word that is too wide or uses too many different glyphs.
List<_Block> _splitBlock(List<Unit> word) {
  final out = <_Block>[];
  var cur = <Unit>[];
  var keys = <String>{};
  for (final u in word) {
    final nextKeys = u.isGlyph ? {...keys, u.glyphKey!} : keys;
    if (cur.length == kCols || nextKeys.length > kMaxGlyphsPerPage) {
      out.add(_Block(cur));
      cur = <Unit>[];
      keys = <String>{};
    }
    cur.add(u);
    if (u.isGlyph) keys.add(u.glyphKey!);
  }
  if (cur.isNotEmpty) out.add(_Block(cur));
  return out;
}

LayoutResult layout(String text) {
  var unsupported = 0;
  final units = shape(text.trim(), unsupported: (_) => unsupported++);
  final rtl = isRtlParagraph(text);
  final hasArabic = units.any((u) => u.isGlyph);
  final asciiText = String.fromCharCodes(units.where((u) => !u.isGlyph).map((u) => u.ascii!));

  // words
  final blocks = <_Block>[];
  var word = <Unit>[];
  for (final u in units) {
    if (u.isSpace) {
      if (word.isNotEmpty) blocks.addAll(_splitBlock(word));
      word = <Unit>[];
    } else {
      word.add(u);
    }
  }
  if (word.isNotEmpty) blocks.addAll(_splitBlock(word));

  // pages -> lines -> blocks
  final pages = <List<List<_Block>>>[];
  final pageKeys = <Set<String>>[];
  void newPage() {
    pages.add([<_Block>[]]);
    pageKeys.add(<String>{});
  }

  newPage();
  for (final b in blocks) {
    if ({...pageKeys.last, ...b.glyphKeys}.length > kMaxGlyphsPerPage) newPage();
    var line = pages.last.last;
    final lineWidth = line.fold<int>(0, (w, x) => w + x.width) + (line.isEmpty ? 0 : line.length - 1);
    final needed = lineWidth + (line.isEmpty ? 0 : 1) + b.width;
    if (needed > kCols) {
      if (pages.last.length < kRows) {
        pages.last.add(<_Block>[]);
      } else {
        newPage();
        if ({...pageKeys.last, ...b.glyphKeys}.length > kMaxGlyphsPerPage) newPage();
      }
      line = pages.last.last;
    }
    line.add(b);
    pageKeys.last.addAll(b.glyphKeys);
  }

  final truncated = pages.length > kMaxPages;
  final used = truncated ? pages.sublist(0, kMaxPages) : pages;

  final result = <LcdPage>[];
  for (final p in used) {
    final slot = <String, int>{};
    final glyphs = <List<int>>[];
    final cells = List<int>.filled(kCols * kRows, 0x20);
    final previewUnits = List<Unit?>.filled(kCols * kRows, null);

    for (var r = 0; r < kRows; r++) {
      final lineBlocks = r < p.length ? p[r] : <_Block>[];
      final ordered = rtl ? lineBlocks.reversed.toList() : lineBlocks;
      final row = <Unit>[];
      for (var i = 0; i < ordered.length; i++) {
        if (i > 0) row.add(const Unit.ascii(0x20));
        row.addAll(ordered[i].visual);
      }
      final start = rtl ? kCols - row.length : 0; // RTL lines are right-aligned
      for (var i = 0; i < row.length; i++) {
        final u = row[i];
        int code;
        if (u.isGlyph) {
          code = slot.putIfAbsent(u.glyphKey!, () {
            glyphs.add(u.rows);
            return glyphs.length - 1;
          });
        } else {
          code = u.ascii!;
        }
        cells[r * kCols + start + i] = code;
        previewUnits[r * kCols + start + i] = u;
      }
    }
    result.add(LcdPage(glyphs, cells, previewUnits));
  }
  if (result.isEmpty) {
    result.add(LcdPage([], List<int>.filled(kCols * kRows, 0x20), List<Unit?>.filled(kCols * kRows, null)));
  }
  return LayoutResult(result, rtl, truncated, unsupported, hasArabic, asciiText);
}
