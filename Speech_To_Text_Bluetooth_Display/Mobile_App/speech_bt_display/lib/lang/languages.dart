/// Languages for speech recognition, translation and the LCD.
library;

/// How well a language can be shown on the 16x2 HD44780 LCD.
enum LcdSupport {
  full, // ASCII after removing accents: perfectly readable, no page limit
  transliterated, // Cyrillic / Greek turned into Latin letters: readable, no page limit
  glyphs, // Arabic script: custom glyphs, max 8 different shapes per screen
  raster, // drawn automatically into 5x8: limited legibility
}

class Language {
  final String code; // BCP-47 code used by ML Kit translation
  final String speechLocale; // Android speech recognizer locale
  final String nameEn;
  final String nameAr;
  final String nameNative;
  final LcdSupport lcd;
  const Language(this.code, this.speechLocale, this.nameEn, this.nameAr, this.nameNative, this.lcd);

  String label(bool arabicUi) => arabicUi ? '$nameAr · $nameNative' : '$nameEn · $nameNative';
}

/// All languages that Google ML Kit can translate on the device.
const List<Language> kLanguages = [
  Language('ar', 'ar-EG', 'Arabic', 'العربية', 'العربية', LcdSupport.glyphs),
  Language('en', 'en-US', 'English', 'الإنجليزية', 'English', LcdSupport.full),
  Language('fr', 'fr-FR', 'French', 'الفرنسية', 'Français', LcdSupport.full),
  Language('es', 'es-ES', 'Spanish', 'الإسبانية', 'Español', LcdSupport.full),
  Language('de', 'de-DE', 'German', 'الألمانية', 'Deutsch', LcdSupport.full),
  Language('it', 'it-IT', 'Italian', 'الإيطالية', 'Italiano', LcdSupport.full),
  Language('pt', 'pt-BR', 'Portuguese', 'البرتغالية', 'Português', LcdSupport.full),
  Language('tr', 'tr-TR', 'Turkish', 'التركية', 'Türkçe', LcdSupport.full),
  Language('ru', 'ru-RU', 'Russian', 'الروسية', 'Русский', LcdSupport.transliterated),
  Language('uk', 'uk-UA', 'Ukrainian', 'الأوكرانية', 'Українська', LcdSupport.transliterated),
  Language('el', 'el-GR', 'Greek', 'اليونانية', 'Ελληνικά', LcdSupport.transliterated),
  Language('fa', 'fa-IR', 'Persian', 'الفارسية', 'فارسی', LcdSupport.glyphs),
  Language('ur', 'ur-PK', 'Urdu', 'الأردية', 'اردو', LcdSupport.glyphs),
  Language('zh', 'zh-CN', 'Chinese', 'الصينية', '中文', LcdSupport.raster),
  Language('ja', 'ja-JP', 'Japanese', 'اليابانية', '日本語', LcdSupport.raster),
  Language('ko', 'ko-KR', 'Korean', 'الكورية', '한국어', LcdSupport.raster),
  Language('hi', 'hi-IN', 'Hindi', 'الهندية', 'हिन्दी', LcdSupport.raster),
  Language('he', 'he-IL', 'Hebrew', 'العبرية', 'עברית', LcdSupport.raster),
  Language('nl', 'nl-NL', 'Dutch', 'الهولندية', 'Nederlands', LcdSupport.full),
  Language('sv', 'sv-SE', 'Swedish', 'السويدية', 'Svenska', LcdSupport.full),
  Language('no', 'nb-NO', 'Norwegian', 'النرويجية', 'Norsk', LcdSupport.full),
  Language('da', 'da-DK', 'Danish', 'الدنماركية', 'Dansk', LcdSupport.full),
  Language('fi', 'fi-FI', 'Finnish', 'الفنلندية', 'Suomi', LcdSupport.full),
  Language('pl', 'pl-PL', 'Polish', 'البولندية', 'Polski', LcdSupport.full),
  Language('cs', 'cs-CZ', 'Czech', 'التشيكية', 'Čeština', LcdSupport.full),
  Language('sk', 'sk-SK', 'Slovak', 'السلوفاكية', 'Slovenčina', LcdSupport.full),
  Language('ro', 'ro-RO', 'Romanian', 'الرومانية', 'Română', LcdSupport.full),
  Language('hu', 'hu-HU', 'Hungarian', 'المجرية', 'Magyar', LcdSupport.full),
  Language('hr', 'hr-HR', 'Croatian', 'الكرواتية', 'Hrvatski', LcdSupport.full),
  Language('sl', 'sl-SI', 'Slovenian', 'السلوفينية', 'Slovenščina', LcdSupport.full),
  Language('lt', 'lt-LT', 'Lithuanian', 'الليتوانية', 'Lietuvių', LcdSupport.full),
  Language('lv', 'lv-LV', 'Latvian', 'اللاتفية', 'Latviešu', LcdSupport.full),
  Language('et', 'et-EE', 'Estonian', 'الإستونية', 'Eesti', LcdSupport.full),
  Language('id', 'id-ID', 'Indonesian', 'الإندونيسية', 'Bahasa Indonesia', LcdSupport.full),
  Language('ms', 'ms-MY', 'Malay', 'الملايوية', 'Bahasa Melayu', LcdSupport.full),
  Language('vi', 'vi-VN', 'Vietnamese', 'الفيتنامية', 'Tiếng Việt', LcdSupport.full),
  Language('tl', 'fil-PH', 'Filipino', 'الفلبينية', 'Filipino', LcdSupport.full),
  Language('sw', 'sw-KE', 'Swahili', 'السواحلية', 'Kiswahili', LcdSupport.full),
  Language('af', 'af-ZA', 'Afrikaans', 'الأفريكانية', 'Afrikaans', LcdSupport.full),
  Language('sq', 'sq-AL', 'Albanian', 'الألبانية', 'Shqip', LcdSupport.full),
  Language('ca', 'ca-ES', 'Catalan', 'الكتالونية', 'Català', LcdSupport.full),
  Language('gl', 'gl-ES', 'Galician', 'الجاليكية', 'Galego', LcdSupport.full),
  Language('ga', 'ga-IE', 'Irish', 'الأيرلندية', 'Gaeilge', LcdSupport.full),
  Language('cy', 'cy-GB', 'Welsh', 'الويلزية', 'Cymraeg', LcdSupport.full),
  Language('is', 'is-IS', 'Icelandic', 'الآيسلندية', 'Íslenska', LcdSupport.full),
  Language('mt', 'mt-MT', 'Maltese', 'المالطية', 'Malti', LcdSupport.full),
  Language('eo', 'eo', 'Esperanto', 'الإسبرانتو', 'Esperanto', LcdSupport.full),
  Language('ht', 'ht-HT', 'Haitian Creole', 'الكريولية الهايتية', 'Kreyòl', LcdSupport.full),
  Language('bg', 'bg-BG', 'Bulgarian', 'البلغارية', 'Български', LcdSupport.transliterated),
  Language('be', 'be-BY', 'Belarusian', 'البيلاروسية', 'Беларуская', LcdSupport.transliterated),
  Language('mk', 'mk-MK', 'Macedonian', 'المقدونية', 'Македонски', LcdSupport.transliterated),
  Language('bn', 'bn-BD', 'Bengali', 'البنغالية', 'বাংলা', LcdSupport.raster),
  Language('ta', 'ta-IN', 'Tamil', 'التاميلية', 'தமிழ்', LcdSupport.raster),
  Language('te', 'te-IN', 'Telugu', 'التيلوغوية', 'తెలుగు', LcdSupport.raster),
  Language('mr', 'mr-IN', 'Marathi', 'الماراثية', 'मराठी', LcdSupport.raster),
  Language('gu', 'gu-IN', 'Gujarati', 'الغوجاراتية', 'ગુજરાતી', LcdSupport.raster),
  Language('kn', 'kn-IN', 'Kannada', 'الكانادية', 'ಕನ್ನಡ', LcdSupport.raster),
  Language('th', 'th-TH', 'Thai', 'التايلاندية', 'ไทย', LcdSupport.raster),
  Language('ka', 'ka-GE', 'Georgian', 'الجورجية', 'ქართული', LcdSupport.raster),
];

Language? languageByCode(String code) {
  final c = code.toLowerCase();
  final norm = c == 'iw' ? 'he' : (c == 'fil' ? 'tl' : (c == 'nb' || c == 'nn' ? 'no' : c));
  for (final l in kLanguages) {
    if (l.code == norm) return l;
  }
  return null;
}
