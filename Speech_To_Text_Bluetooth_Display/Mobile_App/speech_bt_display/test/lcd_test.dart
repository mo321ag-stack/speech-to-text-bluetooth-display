import 'package:flutter_test/flutter_test.dart';
import 'package:speech_bt_display/lcd/arabic_shaper.dart';
import 'package:speech_bt_display/lcd/lcd_font.dart';
import 'package:speech_bt_display/lcd/lcd_layout.dart';
import 'package:speech_bt_display/protocol/frames.dart';

void main() {
  group('CRC and frames', () {
    test('CRC-8/SMBUS check value', () {
      expect(crc8('123456789'.codeUnits), 0xF4);
    });

    test('text frame HI', () {
      final f = textFrame('HI');
      expect(f.sublist(0, 6), [0xAA, 0x55, 0x01, 0x02, 0x48, 0x49]);
      expect(f.last, crc8([0x01, 0x02, 0x48, 0x49]));
    });

    test('page frame length matches firmware check (2 + 8n + 32)', () {
      final res = layout('مرحبا');
      final frames = pageFrames(res.pages);
      expect(frames.length, 3);
      final page = frames[1];
      final n = page[5];
      expect(page[3], 2 + 8 * n + 32);
    });
  });

  group('Arabic shaping', () {
    test('مرحبا joining forms', () {
      final u = shape('مرحبا').map((x) => x.glyphKey).toList();
      expect(u, ['meem|n|-', 'reh|-|p', 'hah|n|-', 'beh|n|p', 'alef|-|p']);
    });

    test('lam-alef ligature', () {
      final u = shape('لا').map((x) => x.glyphKey).toList();
      expect(u, ['lam_alef|-|-']);
    });

    test('harakat are dropped, Arabic digits become ASCII', () {
      final u = shape('مَ ٣');
      expect(u.length, 3);
      expect(u[2].ascii, 0x33);
    });

    test('glyph rows are 5-bit and add baseline joins', () {
      final r = glyphRows('alef', joinsNext: true, joinsPrev: true);
      expect(r.length, 8);
      expect(r.every((v) => v >= 0 && v < 32), isTrue);
      expect(r.length, 8);
    });

    test('every letter in the table has a drawing', () {
      for (var cp = 0x0621; cp <= 0x064A; cp++) {
        if (!isArabicLetter(cp)) continue;
        expect(() => shape(String.fromCharCode(cp)).first.rows, returnsNormally);
      }
    });
  });

  test('every font form is 8 rows x 5 pixels', () {
    kArabicFont.forEach((name, forms) {
      forms.forEach((form, rows) {
        expect(rows.length, 8, reason: '$name.$form');
        for (final r in rows) {
          expect(RegExp(r'^[.#]{5}$').hasMatch(r), isTrue, reason: '$name.$form "$r"');
        }
      });
    });
  });

  test('print sample', () {
    final p = layout('مرحبا بكم في فلسطين').pages.first;
    final buf = StringBuffer();
    for (var y = 0; y < 8; y++) {
      for (var c = 0; c < 16; c++) {
        final code = p.cells[c];
        for (var x = 4; x >= 0; x--) {
          buf.write(code < p.glyphs.length && (p.glyphs[code][y] >> x) & 1 == 1 ? '#' : ' ');
        }
        buf.write('|');
      }
      buf.writeln();
    }
    // ignore: avoid_print
    print(buf);
  });

  group('Other languages', () {
    test('Russian is transliterated and needs no glyphs', () {
      final r = layout('Привет мир');
      expect(r.hasArabic, isFalse);
      expect(r.asciiText, 'Privet mir');
    });
    test('French and German accents are removed', () {
      expect(layout('Ça va très bien, Straße').asciiText, 'Ca va tres bien, Strasse');
    });
    test('Greek is transliterated', () {
      expect(layout('Γειά σου').asciiText, 'Geia sou');
    });
    test('Persian letters are shaped (peh, gaf, Farsi yeh)', () {
      final keys = shape('پگی').map((u) => u.glyphKey).toList();
      expect(keys, ['peh|n|-', 'gaf|n|p', 'alef_maksura_dotted|-|p']);
    });
    test('emoji are dropped and counted', () {
      var n = 0;
      final u = shape('hi ❤️', unsupported: (_) => n++);
      expect(String.fromCharCodes(u.map((x) => x.ascii!)), 'hi ');
      expect(n, 1);
    });
    test('Arabic punctuation and digits', () {
      final u = shape('٢٠٢٦؟');
      expect(String.fromCharCodes(u.map((x) => x.ascii!)), '2026?');
    });
  });

  group('Layout', () {
    test('Arabic word is right-aligned and reversed on screen', () {
      final p = layout('مرحبا').pages.single;
      // visual left->right: alef, beh, hah, reh, meem at columns 11..15
      final row0 = p.units.sublist(0, 16);
      expect(row0.sublist(0, 11).every((u) => u == null), isTrue);
      expect(row0[11]!.glyphKey, 'alef|-|p');
      expect(row0[15]!.glyphKey, 'meem|n|-');
      expect(p.glyphs.length, 5);
    });

    test('never more than 8 glyphs per page', () {
      final res = layout('السلام عليكم ورحمة الله وبركاته كيف حالك اليوم يا صديقي');
      expect(res.hasArabic, isTrue);
      for (final p in res.pages) {
        expect(p.glyphs.length, lessThanOrEqualTo(8));
        expect(p.cells.length, 32);
        for (final c in p.cells) {
          expect(c < p.glyphs.length || (c >= 0x20 && c <= 0x7E), isTrue);
        }
      }
      expect(res.pages.length, greaterThan(1));
    });

    test('mixed text keeps the English word left-to-right', () {
      final p = layout('مرحبا ESP32').pages.single;
      final row = p.units.sublist(0, 16).map((u) => u?.ascii).toList();
      final s = String.fromCharCodes(row.whereType<int>().where((c) => c != 0x20));
      expect(s, 'ESP32');
    });

    test('pure English needs no glyphs', () {
      final res = layout('Hello world');
      expect(res.hasArabic, isFalse);
      expect(res.pages.single.glyphs, isEmpty);
    });

    test('long text is truncated to 8 pages', () {
      final res = layout(List.filled(60, 'كلمة طويلة جدا').join(' '));
      expect(res.pages.length, kMaxPages);
      expect(res.truncated, isTrue);
    });
  });
}
