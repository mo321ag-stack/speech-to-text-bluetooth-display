<div align="center">

# 🎙️ Speech-to-Text Bluetooth Display

**Speak in any language, see it on a 16×2 LCD.**
An Android app recognises (and optionally translates) your speech and sends it over Bluetooth to an **ATmega32A**, which renders it on an HD44780 LCD, including **Arabic drawn with hand-made 5×8 glyphs**.

[![CI](https://github.com/mo321ag-stack/speech-to-text-bluetooth-display/actions/workflows/ci.yml/badge.svg)](https://github.com/mo321ag-stack/speech-to-text-bluetooth-display/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/mo321ag-stack/speech-to-text-bluetooth-display?label=APK%20%2B%20HEX)](https://github.com/mo321ag-stack/speech-to-text-bluetooth-display/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![MCU](https://img.shields.io/badge/MCU-ATmega32A-blue)
![App](https://img.shields.io/badge/App-Flutter%20%7C%20Android-02569B)

<img src="docs/images/lcd_arabic.svg" alt="Arabic on the LCD" width="460"/>
<br/>
<img src="docs/images/lcd_mixed.svg" alt="Arabic and English mixed" width="460"/>
<br/>
<img src="docs/images/lcd_russian.svg" alt="Russian transliterated" width="460"/>

<sub>These images are generated from the app's real layout and font code (<code>test/render_svg_test.dart</code>), pixel for pixel what the LCD shows.</sub>

</div>

---

## ✨ Features

| | |
|---|---|
| 🗣️ **Speech recognition** | 59 languages, plus a **Mix** mode for Arabic + English in the same sentence (Android 14+, on-device) |
| 🌍 **Translation** | Translate to any of 59 languages **on the phone** with Google ML Kit (offline after a one-time model download), with an online fallback |
| 🔤 **Arabic on a character LCD** | Contextual shaping (isolated / initial / medial / final, لا ligature), right-to-left layout, Persian & Urdu letters, hand-drawn 5×8 font loaded into CGRAM |
| 🔡 **Other scripts** | Latin accents folded to ASCII, Cyrillic & Greek transliterated, other scripts rasterised automatically |
| 📡 **Robust link** | Framed protocol `AA 55 · type · len · payload · CRC-8` with ACK/NAK, timeouts and overflow counters |
| 📱 **Live preview** | The app shows exactly what the LCD will display, page by page |
| 🧰 **Rescue programmer** | ESP32 ArduinoISP sketch with a clock output that revives an AVR whose fuses point to a dead crystal |

## 🏗️ Architecture

```mermaid
flowchart LR
    subgraph Phone["📱 Android app (Flutter)"]
        STT[Speech recognizer] --> TXT[Editable text]
        TXT --> TR[ML Kit translation]
        TR --> SH[Shaping · transliteration · layout]
        TXT --> SH
        SH --> FR[Frames + CRC-8]
    end
    FR -- Bluetooth Classic SPP --> HC[HC-05]
    HC -- UART 9600 8N1 --> MCU[ATmega32A<br/>8 MHz internal RC]
    MCU -- I2C 100 kHz --> LCD[16×2 LCD<br/>PCF8574 backpack]
    ESP[ESP32 ArduinoISP] -. ISP flashing .-> MCU
```

**Why the phone does the Arabic work:** an HD44780 has no Arabic font and only **8 user-defined characters on screen at once**. The app shapes the text, orders it right to left, splits it into pages with at most 8 distinct glyphs each, and sends the glyph bitmaps with the cell codes. The ATmega stores up to 8 pages, loads each page's glyphs into CGRAM and cycles through them. English is sent as plain text, and the MCU word-wraps it itself. Details: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## 🔌 Hardware

| Part | Notes |
|---|---|
| ATmega32A (DIP-40) | Internal RC 8 MHz (`LFUSE=0xE4`, `HFUSE=0xD9`) |
| HC-05 | TXD → PD0 (pin 14); PD1 (pin 15) → 1 kΩ/2 kΩ divider → RXD |
| 16×2 LCD + PCF8574 | SDA → PC1 (pin 23), SCL → PC0 (pin 22); address auto-detected |
| ESP32 DevKit V1 | ISP programmer (only for flashing) |

Full wiring, fuses and the ISP recovery story: **[docs/HARDWARE.md](docs/HARDWARE.md)**.

## 🚀 Quick start

1. **Flash the firmware.** Download `bt_display_atmega32a.hex` from [Releases](https://github.com/mo321ag-stack/speech-to-text-bluetooth-display/releases/latest):
   ```bash
   avrdude -c stk500v1 -P COM4 -b 19200 -p m32 -U flash:w:bt_display_atmega32a.hex:i
   ```
2. **Install the app** (`SpeechBTDisplay-arm64.apk`), pair the HC-05 (PIN `1234`), and press **Connect**.
3. Pick a language, tap 🎙️, speak, optionally translate, then press **Send**.

> Quick test without the app: any Bluetooth serial terminal works. Send `#HELLO`, `#AR`, `#CLR`, `#INFO`, or plain text.

## 🛠️ Build from source

**Firmware** (avr-gcc):
```bash
cd Speech_To_Text_Bluetooth_Display/Firmware
make            # or build.bat on Windows (uses the Arduino IDE toolchain)
```

**App** (Flutter ≥ 3.50, Android SDK 36):
```bash
cd Speech_To_Text_Bluetooth_Display/Mobile_App/speech_bt_display
flutter test
flutter build apk --release --split-per-abi
```

> On Windows, the Android Gradle plugin rejects project paths with non-ASCII characters. If your path has any, build from a copy in an ASCII path.

## 📁 Repository layout

```
├── Speech_To_Text_Bluetooth_Display/
│   ├── Firmware/                 AVR C: main, uart, twi_i2c, lcd_i2c, protocol, arabic_display
│   └── Mobile_App/speech_bt_display/
│       ├── lib/lcd/              shaping, 5×8 font, transliteration, rasteriser, page layout
│       ├── lib/protocol/         frame builder + CRC-8
│       ├── lib/services/         Bluetooth SPP, speech recognizer, translator
│       ├── android/.../MainActivity.kt   native SPP + SpeechRecognizer
│       └── test/                 unit tests (shaping, layout, protocol)
├── ESP32_ArduinoISP_Clock/       ESP32 STK500v1 programmer with rescue clock
└── docs/                         hardware, protocol, images
```

## ⚠️ Known limitations

- A 16×2 HD44780 can show at most **8 different Arabic letter shapes per screen**, and its cell gaps prevent letters from visually joining. For fluent Arabic, a graphic display (e.g. 128×64 OLED) is the right hardware.
- Chinese, Japanese, Hindi and similar scripts are auto-rasterised into 5×8 pixels, so legibility is limited.
- The MCU → phone reply line (ACK/NAK) depends on the HC-05 RXD divider wiring. Sending works without it.

## 📄 License

[MIT](LICENSE)
