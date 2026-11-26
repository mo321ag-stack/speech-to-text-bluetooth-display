/// Interface strings in English and Arabic.
library;

enum AppLang { ar, en }

class S {
  final AppLang lang;
  const S(this.lang);
  bool get ar => lang == AppLang.ar;

  String get title => ar ? 'تحويل الكلام إلى شاشة بلوتوث' : 'Speech to Text Bluetooth Display';
  String get language => ar ? 'اللغة' : 'Language';
  String get bluetooth => ar ? 'البلوتوث' : 'Bluetooth';
  String get connected => ar ? 'متصل' : 'Connected';
  String get disconnected => ar ? 'غير متصل' : 'Disconnected';
  String get connecting => ar ? 'جارٍ الاتصال…' : 'Connecting…';
  String get connect => ar ? 'اتصال' : 'Connect';
  String get disconnect => ar ? 'قطع الاتصال' : 'Disconnect';
  String get noDevice => ar ? 'لم يتم اختيار جهاز' : 'No device selected';
  String get pairedDevices => ar ? 'الأجهزة المقترنة' : 'Paired devices';
  String get nearbyDevices => ar ? 'الأجهزة القريبة' : 'Nearby devices';
  String get scan => ar ? 'بحث' : 'Scan';
  String get scanning => ar ? 'جارٍ البحث…' : 'Scanning…';
  String get pair => ar ? 'اقتران' : 'Pair';
  String get btSettings => ar ? 'إعدادات البلوتوث' : 'Bluetooth settings';
  String get pairHelp => ar
      ? 'لأول مرة: اقترن بـ HC-05 (الرمز 1234 أو 0000) ثم اختره من القائمة.'
      : 'First time: pair with HC-05 (PIN 1234 or 0000), then pick it from the list.';
  String get btOff => ar ? 'البلوتوث مغلق. شغّله من إعدادات الهاتف.' : 'Bluetooth is off. Turn it on in phone settings.';
  String get btPermission => ar ? 'تم رفض إذن البلوتوث.' : 'Bluetooth permission denied.';
  String get tapToSpeak => ar ? 'اضغط للتحدث' : 'Tap to speak';
  String get listening => ar ? 'أستمع…' : 'Listening…';
  String get recognized => ar ? 'النص (يمكنك تعديله)' : 'Text (you can edit it)';
  String get hint => ar ? 'تكلم أو اكتب هنا…' : 'Speak or type here…';
  String get send => ar ? 'إرسال' : 'Send';
  String get clear => ar ? 'مسح' : 'Clear';
  String get clearLcd => ar ? 'مسح الشاشة' : 'Clear LCD';
  String get preview => ar ? 'معاينة الشاشة 16×2' : '16x2 LCD preview';
  String page(int i, int n) => ar ? 'صفحة $i من $n' : 'Page $i of $n';
  String get sent => ar ? 'تم الإرسال' : 'Sent';
  String get sendFailed => ar ? 'فشل الإرسال' : 'Send failed';
  String get notConnected => ar ? 'اتصل بـ HC-05 أولًا' : 'Connect to the HC-05 first';
  String get empty => ar ? 'لا يوجد نص' : 'Nothing to send';
  String get micDenied => ar ? 'تم رفض إذن الميكروفون' : 'Microphone permission denied';
  String get sttUnavailable => ar
      ? 'التعرف على الكلام غير متاح على هذا الهاتف (يحتاج تطبيق Google).'
      : 'Speech recognition is not available on this phone (needs the Google app).';
  String get langMissing => ar
      ? 'العربية غير مثبتة في محرك التعرف. سيتم استخدام اللغة الافتراضية؛ قد يحتاج إنترنت.'
      : 'This language is not installed in the recognizer; the default will be used. Internet may be needed.';
  String get truncated => ar ? 'النص طويل: سيُعرض أول 8 صفحات فقط.' : 'Text too long: only the first 8 pages will be shown.';
  String unsupported(int n) => ar ? '$n حرف غير مدعوم سيظهر كـ ?' : '$n unsupported character(s) will show as ?';
  String get arabicNote => ar
      ? 'الشاشة 16×2 تعرض 8 أشكال عربية مختلفة فقط في كل صفحة، لذلك قد يُقسم النص إلى صفحات.'
      : 'A 16x2 LCD can show only 8 different Arabic shapes per screen, so text may be split into pages.';
  String get speechAr => ar ? 'عربي' : 'Arabic';
  String get speechEn => 'English';
  String get speechMix => ar ? 'مزيج' : 'Mix';
  String get mixNote => ar
      ? 'مزيج: عربي وإنجليزي في نفس الجملة (أندرويد 14+ مع التعرف على الجهاز).'
      : 'Mix: Arabic and English in the same sentence (Android 14+, on-device recognition).';
  String get mixUnsupported => ar
      ? 'هاتفك لا يدعم المزيج، سيتم التعرف بالعربية فقط.'
      : 'Your phone does not support mix mode; recognizing Arabic only.';
  String get speechLanguage => ar ? 'لغة الكلام' : 'Speech language';
  String get mixLabel => ar ? 'مزيج: عربي + English' : 'Mix: Arabic + English';
  String get translation => ar ? 'الترجمة' : 'Translation';
  String get translateBeforeSend => ar ? 'ترجم قبل الإرسال' : 'Translate before sending';
  String get translateTo => ar ? 'ترجم إلى' : 'Translate to';
  String get translateNow => ar ? 'ترجم' : 'Translate';
  String get translating => ar ? 'جارٍ الترجمة…' : 'Translating…';
  String downloading(String lang) => ar ? 'تنزيل نموذج $lang (مرة واحدة، ~30MB)…' : 'Downloading $lang model (once, ~30 MB)…';
  String get translatedText => ar ? 'النص المترجم (سيظهر على الشاشة)' : 'Translated text (shown on the LCD)';
  String detected(String lang) => ar ? 'اللغة المكتشفة: $lang' : 'Detected: $lang';
  String get translateFailed => ar ? 'فشلت الترجمة' : 'Translation failed';
  String get needInternetOnce => ar
      ? 'الترجمة على الهاتف تحتاج إنترنت أول مرة لتنزيل اللغة ثم تعمل بدونه. إذا فشلت تُستخدم الترجمة عبر الإنترنت (MyMemory).'
      : 'On-device translation needs internet once to download the language, then works offline. If it fails, online translation (MyMemory) is used.';
  String get pageTime => ar ? 'مدة كل صفحة' : 'Time per page';
  String seconds(double v) => ar ? '${v.toStringAsFixed(1)} ث' : '${v.toStringAsFixed(1)} s';
  String get lcdFull => ar ? 'تظهر بوضوح كامل على الشاشة (بدون علامات التشكيل الأجنبية).' : 'Fully readable on the LCD (accents removed).';
  String get lcdTranslit => ar ? 'تظهر على الشاشة بحروف لاتينية مقروءة (Привет ← Privet).' : 'Shown on the LCD in readable Latin letters (Привет -> Privet).';
  String get lcdGlyphs => ar ? 'تُرسم بحروف عربية مخصصة: 8 أشكال مختلفة كحد أقصى في كل صفحة.' : 'Drawn with custom Arabic glyphs: at most 8 different shapes per page.';
  String get lcdRaster => ar ? 'تُرسم تلقائيًا في 5×8 بكسل: الوضوح محدود على شاشة 16×2.' : 'Drawn automatically in 5x8 pixels: limited legibility on a 16x2 LCD.';
  String get displayed => ar ? 'سيُعرض' : 'Will show';
  String get engineDevice => ar ? 'على الهاتف' : 'on device';
  String get engineOnline => ar ? 'عبر الإنترنت (MyMemory)' : 'online (MyMemory)';
  String get usedOnline => ar
      ? 'الترجمة على الهاتف غير متاحة الآن، تم استخدام الترجمة عبر الإنترنت (يُرسل النص إلى MyMemory).'
      : 'On-device translation unavailable; used online translation (text sent to MyMemory).';
  String get lastReply => ar ? 'رد الجهاز' : 'Device reply';
}
