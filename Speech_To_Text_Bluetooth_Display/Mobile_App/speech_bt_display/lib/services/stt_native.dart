/// Android SpeechRecognizer (MainActivity.kt). Supports a "mix" mode where Arabic and
/// English can be spoken in the same sentence (Android 14+, on-device recognizer).
library;

import 'dart:async';

import 'package:flutter/services.dart';

class SttEvent {
  final String type; // ready | partial | final | error | end
  final String text;
  final int? code;
  SttEvent(this.type, this.text, this.code);
}

class SttNative {
  static const _m = MethodChannel('stt/methods');
  static const _e = EventChannel('stt/events');

  Stream<SttEvent>? _events;
  Stream<SttEvent> get events => _events ??= _e.receiveBroadcastStream().map((dynamic ev) {
        final m = Map<String, dynamic>.from(ev as Map);
        return SttEvent(m['type'] as String, (m['text'] as String?) ?? '', m['code'] as int?);
      }).asBroadcastStream();

  Future<bool> mixSupported() async => await _m.invokeMethod<bool>('mixSupported') ?? false;

  /// [locale] e.g. "ar-EG", "fr-FR". With [mix] Arabic and English can be mixed
  /// (Android 14+, on-device). Returns true when mix mode is really active.
  Future<bool> start(String locale, {bool mix = false}) async {
    final r = await _m.invokeMapMethod<String, dynamic>('start', {'lang': locale, 'mix': mix});
    return r?['mix'] == true;
  }

  Future<void> stop() => _m.invokeMethod('stop');

  /// android.speech.SpeechRecognizer error codes.
  static String errorText(int code, bool ar) {
    switch (code) {
      case 1: case 2: return ar ? 'خطأ في الشبكة: التعرف يحتاج إنترنت' : 'Network error: recognition needs internet';
      case 3: return ar ? 'خطأ في الميكروفون' : 'Microphone error';
      case 6: return ar ? 'لم يُسمع كلام' : 'No speech heard';
      case 7: return ar ? 'لم يُفهم الكلام، حاول مرة أخرى' : 'Speech not understood, try again';
      case 8: return ar ? 'المحرك مشغول' : 'Recognizer busy';
      case 9: return ar ? 'لا يوجد إذن للميكروفون' : 'No microphone permission';
      case 12: case 13:
        return ar
            ? 'اللغة غير متاحة. نزّل حزمة اللغة من: الإعدادات ← Google ← التعرف على الكلام دون اتصال'
            : 'Language not available. Download it in Settings → Google → Offline speech recognition';
      default: return ar ? 'خطأ في التعرف ($code)' : 'Recognition error ($code)';
    }
  }
}
