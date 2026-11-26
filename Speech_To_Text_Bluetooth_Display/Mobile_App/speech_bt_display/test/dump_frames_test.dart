// Writes the exact frames the app sends, as hex lines, for the firmware host simulator.
// Only runs when FRAME_DUMP is set:  FRAME_DUMP=out.txt flutter test test/dump_frames_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_bt_display/lcd/lcd_layout.dart';
import 'package:speech_bt_display/protocol/frames.dart';

void main() {
  final out = Platform.environment['FRAME_DUMP'];
  test('dump frames', () {
    final text = Platform.environment['FRAME_TEXT'] ?? 'مرحبا';
    final res = layout(text);
    final lines = <String>['# $text'];
    lines.add(hex(frame(Msg.clear)));
    for (final f in pageFrames(res.pages)) {
      lines.add(hex(f));
    }
    File(out!).writeAsStringSync('${lines.join('\n')}\n');
  }, skip: out == null ? 'set FRAME_DUMP to run' : false);
}
