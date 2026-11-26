# Speech BT Display: Android app (Flutter)

Project: `speech_bt_display/`.

## Features

- **Speech recognition:** Arabic or English with the `speech_to_text` package. It uses the phone's Google recognizer, which usually needs internet unless the offline language pack is installed.
- **Editing:** you can correct the recognized text before sending.
- **Bluetooth Classic SPP** to the HC-05. This is the app's own Kotlin code (`MainActivity.kt`), not a plugin. It can:
  - list paired devices
  - scan for nearby ones and pair with them
  - connect and disconnect
  - send data, and show the ATmega's replies
- **Arabic shaping** is done in the app (`lib/lcd/`):
  - picks each letter's joining form, including the لا ligature
  - lays the text out right to left
  - splits it into 16×2 pages with at most 8 different glyphs each
  - draws the 5×8 glyphs (`lcd_font.dart`)
- **Live LCD preview:** shows pixel for pixel what the LCD will display.

## Build

The Android Gradle plugin rejects project paths with non-ASCII (e.g. Arabic) characters on Windows. Copy the folder to an ASCII path first:

```
flutter pub get
flutter test
flutter build apk --release
```

The APK is in `build/app/outputs/flutter-apk/app-release.apk`. It is signed with the debug key, which is fine for installing on your own phone.

## Use

1. Pair the HC-05 (PIN 1234 or 0000) from the app's Connect sheet or from the phone's settings.
2. Connect, choose ع or EN, tap the microphone, speak, edit if needed, and press Send.
3. English is sent as plain text, and the ATmega wraps it itself. Arabic or mixed text is sent as glyph pages.
