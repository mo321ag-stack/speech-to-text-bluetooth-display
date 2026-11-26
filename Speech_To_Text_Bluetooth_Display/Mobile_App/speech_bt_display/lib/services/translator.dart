/// Translation.
///  1. On the phone with Google ML Kit (no key; each language model is downloaded
///     once, about 30 MB, then it works offline).
///  2. If that fails (model download blocked, Google Play services missing, ...),
///     online through the free MyMemory service (api.mymemory.translated.net).
///     The text is then sent over the internet to that service.
library;

import 'dart:convert';

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;

import '../lang/languages.dart';

enum TranslationEngine { onDevice, online }

class TranslationResult {
  final String text;
  final TranslationEngine engine;
  final String? onDeviceError; // why on-device translation was not used
  TranslationResult(this.text, this.engine, [this.onDeviceError]);
}

class TranslatorService {
  final _id = LanguageIdentifier(confidenceThreshold: 0.35);
  final _models = OnDeviceTranslatorModelManager();

  /// Detected language code, or null when unsure.
  Future<String?> detect(String text) async {
    try {
      final code = await _id.identifyLanguage(text);
      if (code == 'und') return null;
      return languageByCode(code)?.code ?? code;
    } catch (_) {
      return null;
    }
  }

  Future<TranslationResult> translate(String text, String from, String to,
      {void Function(String code)? onDownload}) async {
    if (from == to) return TranslationResult(text, TranslationEngine.onDevice);
    String? deviceError;
    try {
      return TranslationResult(await _onDevice(text, from, to, onDownload), TranslationEngine.onDevice);
    } catch (e) {
      deviceError = e.toString();
    }
    try {
      return TranslationResult(await _online(text, from, to), TranslationEngine.online, deviceError);
    } catch (e) {
      throw TranslationException('on-device: $deviceError\nonline: $e');
    }
  }

  Future<String> _onDevice(String text, String from, String to, void Function(String code)? onDownload) async {
    final src = BCP47Code.fromRawValue(from);
    final dst = BCP47Code.fromRawValue(to);
    if (src == null || dst == null) throw TranslationException('language not supported on device ($from→$to)');
    for (final code in {from, to}) {
      if (!await _models.isModelDownloaded(code)) {
        onDownload?.call(code);
        final ok = await _models.downloadModel(code, isWifiRequired: false);
        if (!ok) throw TranslationException('model download failed ($code)');
      }
    }
    final t = OnDeviceTranslator(sourceLanguage: src, targetLanguage: dst);
    try {
      return await t.translateText(text);
    } finally {
      await t.close();
    }
  }

  /// MyMemory accepts up to 500 bytes per request, so long text is split on sentences.
  Future<String> _online(String text, String from, String to) async {
    final parts = _chunks(text, 450);
    final out = <String>[];
    for (final p in parts) {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {'q': p, 'langpair': '$from|$to'});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw TranslationException('HTTP ${res.statusCode}');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final status = body['responseStatus'];
      final t = (body['responseData'] as Map?)?['translatedText'] as String?;
      if ((status != 200 && status != '200') || t == null) {
        throw TranslationException('${body['responseDetails'] ?? 'no translation'}');
      }
      out.add(t);
    }
    return out.join(' ');
  }

  static List<String> _chunks(String text, int maxBytes) {
    final sentences = text.split(RegExp(r'(?<=[.!?؟。])\s+'));
    final out = <String>[];
    var cur = '';
    for (final s in sentences) {
      final cand = cur.isEmpty ? s : '$cur $s';
      if (utf8.encode(cand).length <= maxBytes) {
        cur = cand;
      } else {
        if (cur.isNotEmpty) out.add(cur);
        cur = s;
        while (utf8.encode(cur).length > maxBytes) {
          var cut = cur.length;
          while (utf8.encode(cur.substring(0, cut)).length > maxBytes) {
            cut--;
          }
          out.add(cur.substring(0, cut));
          cur = cur.substring(cut);
        }
      }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  Future<void> dispose() => _id.close();
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  @override
  String toString() => message;
}
