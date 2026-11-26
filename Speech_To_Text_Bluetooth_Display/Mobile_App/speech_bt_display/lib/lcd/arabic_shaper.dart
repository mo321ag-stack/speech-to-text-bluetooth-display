/// Turns text in any language into LCD display units: ASCII cells (shown with the
/// LCD's own font) or custom 5x8 glyphs (Arabic shaping, or rasterised characters).
library;

import 'lcd_font.dart';
import 'raster.dart';
import 'scripts.dart';

/// Joining type (Unicode ArabicShaping.txt): D = joins both sides, R = joins only to
/// the previous letter (on its right), U = does not join.
enum Joining { dual, right, none }

class _Letter {
  final String base;
  final Joining joining;
  const _Letter(this.base, this.joining);
}

const Map<int, _Letter> _letters = {
  0x0621: _Letter('hamza', Joining.none),
  0x0622: _Letter('alef_madda', Joining.right),
  0x0623: _Letter('alef_hamza', Joining.right),
  0x0624: _Letter('waw_hamza', Joining.right),
  0x0625: _Letter('alef_hamza_below', Joining.right),
  0x0626: _Letter('yeh_hamza', Joining.dual),
  0x0627: _Letter('alef', Joining.right),
  0x0628: _Letter('beh', Joining.dual),
  0x0629: _Letter('teh_marbuta', Joining.right),
  0x062A: _Letter('teh', Joining.dual),
  0x062B: _Letter('theh', Joining.dual),
  0x062C: _Letter('jeem', Joining.dual),
  0x062D: _Letter('hah', Joining.dual),
  0x062E: _Letter('khah', Joining.dual),
  0x062F: _Letter('dal', Joining.right),
  0x0630: _Letter('thal', Joining.right),
  0x0631: _Letter('reh', Joining.right),
  0x0632: _Letter('zain', Joining.right),
  0x0633: _Letter('seen', Joining.dual),
  0x0634: _Letter('sheen', Joining.dual),
  0x0635: _Letter('sad', Joining.dual),
  0x0636: _Letter('dad', Joining.dual),
  0x0637: _Letter('tah', Joining.dual),
  0x0638: _Letter('zah', Joining.dual),
  0x0639: _Letter('ain', Joining.dual),
  0x063A: _Letter('ghain', Joining.dual),
  0x0641: _Letter('feh', Joining.dual),
  0x0642: _Letter('qaf', Joining.dual),
  0x0643: _Letter('kaf', Joining.dual),
  0x0644: _Letter('lam', Joining.dual),
  0x0645: _Letter('meem', Joining.dual),
  0x0646: _Letter('noon', Joining.dual),
  0x0647: _Letter('heh', Joining.dual),
  0x0648: _Letter('waw', Joining.right),
  0x0649: _Letter('alef_maksura', Joining.dual),
  0x064A: _Letter('yeh', Joining.dual),
  0x0671: _Letter('alef', Joining.right), // alef wasla
  // Persian
  0x067E: _Letter('peh', Joining.dual),
  0x0686: _Letter('tcheh', Joining.dual),
  0x0698: _Letter('jeh', Joining.right),
  0x06A9: _Letter('kaf', Joining.dual), // keheh
  0x06AF: _Letter('gaf', Joining.dual),
  0x06CC: _Letter('alef_maksura_dotted', Joining.dual), // Farsi yeh: no dots at the end
  // Urdu
  0x0679: _Letter('teh', Joining.dual), // tteh
  0x0688: _Letter('dal', Joining.right), // ddal
  0x0691: _Letter('reh', Joining.right), // rreh
  0x06BA: _Letter('noon_ghunna', Joining.dual),
  0x06BE: _Letter('heh', Joining.dual), // heh doachashmee
  0x06C1: _Letter('heh', Joining.dual), // heh goal
  0x06D2: _Letter('alef_maksura', Joining.right), // yeh barree
};

bool isArabicLetter(int cp) => _letters.containsKey(cp);

bool _isTashkeel(int cp) =>
    (cp >= 0x064B && cp <= 0x065F) || cp == 0x0670 || cp == 0x0640 || (cp >= 0x06D6 && cp <= 0x06ED);

/// Arabic punctuation and digits -> ASCII.
String? _arabicPunct(int cp) {
  if (cp >= 0x0660 && cp <= 0x0669) return String.fromCharCode(0x30 + cp - 0x0660);
  if (cp >= 0x06F0 && cp <= 0x06F9) return String.fromCharCode(0x30 + cp - 0x06F0);
  switch (cp) {
    case 0x060C: return ',';
    case 0x061B: return ';';
    case 0x061F: return '?';
    case 0x066A: return '%';
    case 0x066B: return '.';
    case 0x066C: return ',';
    case 0x06D4: return '.';
  }
  return null;
}

/// One LCD cell worth of content.
class Unit {
  /// ASCII code (0x20..0x7E), or null for a custom glyph.
  final int? ascii;

  /// Custom glyph identity: "beh|n|p" (Arabic letter, form) or "ras:CODEPOINT".
  final String? glyphKey;

  /// Part of a right-to-left run (Arabic, Hebrew).
  final bool rtl;

  const Unit.ascii(int this.ascii)
      : glyphKey = null,
        rtl = false;
  const Unit.glyph(String this.glyphKey, {this.rtl = false}) : ascii = null;

  bool get isGlyph => glyphKey != null;
  bool get isSpace => ascii == 0x20;

  List<int> get rows {
    final k = glyphKey!;
    if (k.startsWith('ras:')) return rasterCache[int.parse(k.substring(4))] ?? List.filled(8, 0);
    final parts = k.split('|');
    return glyphRows(parts[0], joinsNext: parts[1] == 'n', joinsPrev: parts[2] == 'p');
  }

  @override
  bool operator ==(Object other) => other is Unit && other.ascii == ascii && other.glyphKey == glyphKey;
  @override
  int get hashCode => Object.hash(ascii, glyphKey);
  @override
  String toString() => ascii != null ? String.fromCharCode(ascii!) : '<$glyphKey>';
}

/// Shapes [text] into units in LOGICAL (reading) order.
/// Characters that cannot be shown become '?', and [unsupported] is called for each.
List<Unit> shape(String text, {void Function(int cp)? unsupported}) {
  final cps = preTransliterate(text).runes.where((c) => !_isTashkeel(c) && !(c >= 0x0300 && c <= 0x036F)).toList();
  final out = <Unit>[];

  // LAM + ALEF variants -> mandatory LAM-ALEF ligature (marker -1)
  final merged = <int>[];
  for (var i = 0; i < cps.length; i++) {
    final c = cps[i];
    if (c == 0x0644 && i + 1 < cps.length && const {0x0622, 0x0623, 0x0625, 0x0627, 0x0671}.contains(cps[i + 1])) {
      merged.add(-1);
      i++;
    } else {
      merged.add(c);
    }
  }

  Joining joiningOf(int c) => c == -1 ? Joining.right : (_letters[c]?.joining ?? Joining.none);

  for (var i = 0; i < merged.length; i++) {
    final c = merged[i];
    if (c == -1 || _letters.containsKey(c)) {
      final j = joiningOf(c);
      final prev = i > 0 ? joiningOf(merged[i - 1]) : Joining.none;
      final next = i + 1 < merged.length ? joiningOf(merged[i + 1]) : Joining.none;
      final joinsPrev = j != Joining.none && prev == Joining.dual;
      final joinsNext = j == Joining.dual && next != Joining.none;
      final base = c == -1 ? 'lam_alef' : _letters[c]!.base;
      out.add(Unit.glyph('$base|${joinsNext ? 'n' : '-'}|${joinsPrev ? 'p' : '-'}', rtl: true));
      continue;
    }
    if (c == 0x09 || c == 0x0A || c == 0x0D) {
      out.add(const Unit.ascii(0x20));
      continue;
    }
    final ascii = _arabicPunct(c) ?? toLcdAscii(c);
    if (ascii != null) {
      for (final a in ascii.codeUnits) {
        out.add(Unit.ascii(a));
      }
      continue;
    }
    if (isDroppable(c)) {
      if (c >= 0x1F000 || (c >= 0x2600 && c <= 0x27BF)) unsupported?.call(c); // emoji: tell the user
      continue;
    }
    if (rasterCache.containsKey(c)) {
      out.add(Unit.glyph('ras:$c', rtl: isHebrew(c)));
      continue;
    }
    unsupported?.call(c);
    out.add(const Unit.ascii(0x3F));
  }
  return out;
}

/// Right-to-left paragraph when the first strong letter is Arabic or Hebrew.
bool isRtlParagraph(String text) {
  for (final c in text.runes) {
    if (isArabicLetter(c) || isHebrew(c)) return true;
    if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0xC0 && c <= 0x24F) || (c >= 0x370 && c <= 0x4FF)) {
      return false;
    }
  }
  return false;
}
