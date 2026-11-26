import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import 'i18n.dart';
import 'lang/languages.dart';
import 'lcd/lcd_layout.dart';
import 'lcd/raster.dart';
import 'protocol/frames.dart';
import 'services/bt_spp.dart';
import 'services/stt_native.dart';
import 'services/translator.dart';
import 'widgets/device_picker.dart';
import 'widgets/lcd_preview.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  AppLang lang = AppLang.ar;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Speech BT Display',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(
        textDirection: lang == AppLang.ar ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: HomePage(lang: lang, onLang: (l) => setState(() => lang = l)),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppLang lang;
  final ValueChanged<AppLang> onLang;
  const HomePage({super.key, required this.lang, required this.onLang});
  @override
  State<HomePage> createState() => _HomePageState();
}

const String kMix = 'mix';

class _HomePageState extends State<HomePage> {
  final bt = BtSpp();
  final stt = SttNative();
  final tr = TranslatorService();
  final text = TextEditingController();
  final translated = TextEditingController();
  final subs = <StreamSubscription>[];

  String speechChoice = 'ar'; // language code, or kMix
  String sttBase = '';
  bool listening = false;

  bool translateOn = false;
  String targetCode = 'en';
  bool translating = false;
  String? trStatus;

  bool connecting = false;
  bool sending = false;
  String? lastReply;

  LayoutResult? preview;
  int previewPage = 0;
  double pageSeconds = 2.5;
  Timer? pageTimer;
  int _previewSeq = 0;

  S get s => S(widget.lang);
  bool get arUi => widget.lang == AppLang.ar;

  /// The text that goes to the LCD.
  String get displayText => translateOn && translated.text.trim().isNotEmpty ? translated.text : text.text;

  @override
  void initState() {
    super.initState();
    bt.start();
    subs.add(bt.connection.listen((_) => setState(() {})));
    subs.add(bt.replies.listen((r) => setState(() => lastReply = r)));
    subs.add(stt.events.listen(_onStt));
    text.addListener(_updatePreview);
    translated.addListener(_updatePreview);
    _restartPageTimer();
  }

  @override
  void dispose() {
    for (final x in subs) {
      x.cancel();
    }
    pageTimer?.cancel();
    bt.dispose();
    tr.dispose();
    text.dispose();
    translated.dispose();
    super.dispose();
  }

  void _restartPageTimer() {
    pageTimer?.cancel();
    pageTimer = Timer.periodic(Duration(milliseconds: (pageSeconds * 1000).round()), (_) {
      final n = preview?.pages.length ?? 1;
      if (n > 1 && mounted) setState(() => previewPage = (previewPage + 1) % n);
    });
  }

  Future<void> _updatePreview() async {
    final seq = ++_previewSeq;
    final t = displayText;
    if (t.trim().isEmpty) {
      setState(() => preview = null);
      return;
    }
    await prepareRaster(t); // draws Chinese/Hindi/... characters into 5x8 first
    if (!mounted || seq != _previewSeq) return;
    setState(() {
      preview = layout(t);
      previewPage = 0;
    });
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  String _langName(String code) {
    final l = languageByCode(code);
    return l == null ? code : (arUi ? l.nameAr : l.nameEn);
  }

  // ---------------- speech ----------------
  void _onStt(SttEvent e) {
    switch (e.type) {
      case 'partial':
      case 'final':
        if (e.text.isEmpty) return;
        text.text = sttBase.isEmpty ? e.text : '$sttBase ${e.text}';
        text.selection = TextSelection.collapsed(offset: text.text.length);
        if (e.type == 'final' && translateOn) _translate();
        break;
      case 'error':
        _toast(SttNative.errorText(e.code ?? 0, arUi), error: true);
        break;
      case 'end':
        setState(() => listening = false);
        break;
    }
  }

  Future<void> _toggleListen() async {
    if (listening) {
      await stt.stop();
      setState(() => listening = false);
      return;
    }
    if (!(await Permission.microphone.request()).isGranted) {
      _toast(s.micDenied, error: true);
      return;
    }
    sttBase = text.text.trim();
    try {
      final mix = speechChoice == kMix;
      final locale = mix ? 'ar-EG' : (languageByCode(speechChoice)?.speechLocale ?? speechChoice);
      final mixActive = await stt.start(locale, mix: mix);
      if (mix && !mixActive) _toast(s.mixUnsupported);
      setState(() => listening = true);
    } on PlatformException catch (e) {
      _toast(e.code == 'STT_UNAVAILABLE' ? s.sttUnavailable : '${e.message}', error: true);
    }
  }

  // ---------------- translation ----------------
  Future<void> _translate() async {
    final src = text.text.trim();
    if (src.isEmpty) return;
    setState(() {
      translating = true;
      trStatus = null;
    });
    try {
      final from = await tr.detect(src) ?? (speechChoice == kMix ? 'ar' : speechChoice);
      setState(() => trStatus = s.detected(_langName(from)));
      final r = await tr.translate(src, from, targetCode,
          onDownload: (code) => setState(() => trStatus = s.downloading(_langName(code))));
      translated.text = r.text;
      setState(() => trStatus = '${_langName(from)} → ${_langName(targetCode)}  ·  '
          '${r.engine == TranslationEngine.onDevice ? s.engineDevice : s.engineOnline}');
      if (r.engine == TranslationEngine.online) _toast(s.usedOnline);
    } catch (e) {
      setState(() => trStatus = null);
      _toast('${s.translateFailed}:\n$e', error: true);
    } finally {
      if (mounted) setState(() => translating = false);
    }
  }

  // ---------------- bluetooth ----------------
  Future<void> _pickDevice() async {
    if (!await bt.ensurePermissions(scan: true)) {
      _toast(s.btPermission, error: true);
      return;
    }
    if (!await bt.isEnabled()) {
      _toast(s.btOff, error: true);
      return;
    }
    if (!mounted) return;
    final d = await showModalBottomSheet<BtDevice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: arUi ? TextDirection.rtl : TextDirection.ltr,
        child: DevicePicker(bt: bt, s: s),
      ),
    );
    if (d == null) return;
    setState(() => connecting = true);
    try {
      await bt.connect(d);
      _toast('${s.connected}: ${d.label}');
    } catch (e) {
      _toast('${s.disconnected}: $e', error: true);
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> _send() async {
    final t = displayText.trim();
    if (t.isEmpty) return _toast(s.empty);
    if (!bt.isConnected) return _toast(s.notConnected, error: true);
    await prepareRaster(t);
    final res = layout(t);
    setState(() => sending = true);
    try {
      if (!res.hasArabic) {
        // Latin / transliterated text: the ATmega word-wraps it itself.
        await bt.write(textFrame(res.asciiText));
      } else {
        await bt.write(frame(Msg.clear)); // stops page cycling so the receive buffer is free
        await Future.delayed(const Duration(milliseconds: 200));
        await bt.sendFrames(pageFrames(res.pages, pageTimeMs: (pageSeconds * 1000).round()));
      }
      if (res.truncated) _toast(s.truncated);
      _toast(s.sent);
    } catch (e) {
      _toast('${s.sendFailed}: $e', error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _clearLcd() async {
    if (!bt.isConnected) return _toast(s.notConnected, error: true);
    try {
      await bt.clearDisplay();
    } catch (e) {
      _toast('${s.sendFailed}: $e', error: true);
    }
  }

  // ---------------- UI ----------------
  List<DropdownMenuItem<String>> _langItems({bool withMix = false}) => [
        if (withMix)
          DropdownMenuItem(
            value: kMix,
            child: Row(children: [const Icon(Icons.translate, size: 18), const SizedBox(width: 8), Text(s.mixLabel)]),
          ),
        for (final l in kLanguages)
          DropdownMenuItem(value: l.code, child: Text(l.label(arUi), overflow: TextOverflow.ellipsis)),
      ];

  String _lcdNote() {
    final code = translateOn ? targetCode : (speechChoice == kMix ? 'ar' : speechChoice);
    switch (languageByCode(code)?.lcd ?? LcdSupport.full) {
      case LcdSupport.full:
        return s.lcdFull;
      case LcdSupport.transliterated:
        return s.lcdTranslit;
      case LcdSupport.glyphs:
        return s.lcdGlyphs;
      case LcdSupport.raster:
        return s.lcdRaster;
    }
  }

  Widget _section(String title, IconData icon, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  TextDirection? _dirOf(String t) {
    if (t.isEmpty) return null;
    return RegExp(r'[֐-ۿ]').hasMatch(t) ? TextDirection.rtl : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pv = preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title, style: const TextStyle(fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<AppLang>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AppLang.ar, label: Text('ع')),
                ButtonSegment(value: AppLang.en, label: Text('EN')),
              ],
              selected: {widget.lang},
              onSelectionChanged: (v) => widget.onLang(v.first),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ---------- Bluetooth ----------
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (bt.isConnected ? Colors.greenAccent : cs.error).withValues(alpha: 0.15),
                      ),
                      child: Icon(bt.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: bt.isConnected ? Colors.greenAccent : cs.error),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(connecting ? s.connecting : (bt.isConnected ? s.connected : s.disconnected),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(bt.device?.label ?? s.noDevice, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (bt.isConnected)
                      OutlinedButton(onPressed: () => bt.disconnect(), child: Text(s.disconnect))
                    else
                      FilledButton(onPressed: connecting ? null : _pickDevice, child: Text(s.connect)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Speech ----------
            _section(
              s.speechLanguage,
              Icons.record_voice_over,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: speechChoice,
                    isExpanded: true,
                    items: _langItems(withMix: true),
                    onChanged: listening ? null : (v) => setState(() => speechChoice = v!),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                  if (speechChoice == kMix)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(s.mixNote, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: _toggleListen,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: listening ? 104 : 88,
                        height: listening ? 104 : 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: listening ? [Colors.redAccent, Colors.deepOrange] : [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (listening ? Colors.redAccent : cs.primary).withValues(alpha: 0.45),
                              blurRadius: listening ? 30 : 14,
                              spreadRadius: listening ? 4 : 0,
                            ),
                          ],
                        ),
                        child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, size: 44, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text(listening ? s.listening : s.tapToSpeak, style: TextStyle(color: cs.onSurfaceVariant))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: text,
                    minLines: 2,
                    maxLines: 5,
                    textDirection: _dirOf(text.text),
                    decoration: InputDecoration(
                      labelText: s.recognized,
                      hintText: s.hint,
                      border: const OutlineInputBorder(),
                      suffixIcon: text.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: s.clear,
                              onPressed: () {
                                text.clear();
                                translated.clear();
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Translation ----------
            _section(
              s.translation,
              Icons.g_translate,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.translateBeforeSend),
                    value: translateOn,
                    onChanged: (v) {
                      setState(() => translateOn = v);
                      if (v && text.text.trim().isNotEmpty) _translate();
                      _updatePreview();
                    },
                  ),
                  if (translateOn) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: targetCode,
                            isExpanded: true,
                            items: _langItems(),
                            onChanged: (v) {
                              setState(() => targetCode = v!);
                              if (text.text.trim().isNotEmpty) _translate();
                            },
                            decoration: InputDecoration(labelText: s.translateTo, border: const OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: translating ? null : _translate,
                          icon: translating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.translate),
                          label: Text(translating ? s.translating : s.translateNow),
                        ),
                      ],
                    ),
                    if (trStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(trStatus!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: translated,
                      minLines: 2,
                      maxLines: 5,
                      textDirection: _dirOf(translated.text),
                      decoration: InputDecoration(labelText: s.translatedText, border: const OutlineInputBorder()),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(s.needInternetOnce, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- LCD ----------
            _section(
              s.preview,
              Icons.tv,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LcdPreview(page: pv == null ? null : pv.pages[previewPage.clamp(0, pv.pages.length - 1)]),
                  if (pv != null && pv.pages.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(s.page(previewPage + 1, pv.pages.length),
                          textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  if (pv != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_lcdNote(), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ),
                  if (pv != null && pv.unsupportedChars > 0)
                    Text(s.unsupported(pv.unsupportedChars), style: TextStyle(color: cs.error, fontSize: 12)),
                  if (pv != null && pv.truncated) Text(s.truncated, style: TextStyle(color: cs.error, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(s.pageTime),
                      Expanded(
                        child: Slider(
                          value: pageSeconds,
                          min: 1,
                          max: 6,
                          divisions: 10,
                          label: s.seconds(pageSeconds),
                          onChanged: (v) {
                            setState(() => pageSeconds = v);
                            _restartPageTimer();
                          },
                        ),
                      ),
                      Text(s.seconds(pageSeconds)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---------- Actions ----------
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(s.send, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  onPressed: _clearLcd,
                  tooltip: s.clearLcd,
                  icon: const Icon(Icons.layers_clear),
                ),
              ],
            ),
            if (lastReply != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${s.lastReply}: $lastReply', style: TextStyle(color: cs.onSurfaceVariant, fontFamily: 'monospace')),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
