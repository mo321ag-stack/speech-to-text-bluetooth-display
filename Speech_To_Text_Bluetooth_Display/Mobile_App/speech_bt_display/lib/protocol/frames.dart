/// Frames for the ATmega32A firmware (see Firmware/protocol.h).
///   0xAA 0x55 | TYPE | LEN | PAYLOAD | CRC8 (poly 0x07, init 0, over TYPE..PAYLOAD)
library;

import 'dart:typed_data';

import '../lcd/lcd_layout.dart';

class Msg {
  static const text = 0x01;
  static const clear = 0x02;
  static const ping = 0x03;
  static const backlight = 0x04;
  static const pagesBegin = 0x10;
  static const page = 0x11;
  static const pagesEnd = 0x12;
}

const int kMaxPayload = 200;

int crc8(Iterable<int> bytes) {
  var crc = 0;
  for (final b in bytes) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x07) & 0xFF : (crc << 1) & 0xFF;
    }
  }
  return crc;
}

Uint8List frame(int type, [List<int> payload = const []]) {
  if (payload.length > kMaxPayload) throw ArgumentError('payload too long (${payload.length})');
  final body = [type, payload.length, ...payload];
  return Uint8List.fromList([0xAA, 0x55, ...body, crc8(body)]);
}

/// English / ASCII text: the firmware wraps and pages it itself.
Uint8List textFrame(String ascii) {
  final bytes = ascii.codeUnits.map((c) => (c >= 0x20 && c <= 0x7E) ? c : 0x3F).take(kMaxPayload).toList();
  return frame(Msg.text, bytes);
}

/// Arabic / mixed text: one BEGIN, one PAGE per screen, one END.
List<Uint8List> pageFrames(List<LcdPage> pages, {int pageTimeMs = 2500}) {
  final out = <Uint8List>[frame(Msg.pagesBegin, [pages.length, (pageTimeMs ~/ 100).clamp(5, 255)])];
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    out.add(frame(Msg.page, [i, p.glyphs.length, for (final g in p.glyphs) ...g, ...p.cells]));
  }
  out.add(frame(Msg.pagesEnd));
  return out;
}

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
