# Speech-to-Text Bluetooth Display

Speak into an Android phone (Arabic, English, or 59 languages, with optional on-device translation). The text goes over Bluetooth (HC-05) to an **ATmega32A**, which shows it on a **16x2 I2C LCD**, including Arabic drawn with custom 5×8 glyphs.

| Folder | What |
|---|---|
| [`Speech_To_Text_Bluetooth_Display/Firmware`](Speech_To_Text_Bluetooth_Display/Firmware) | AVR C firmware (ATmega32A, internal RC 8 MHz): UART, TWI, LCD driver, framed protocol with CRC-8, Arabic glyph pages |
| [`Speech_To_Text_Bluetooth_Display/Mobile_App`](Speech_To_Text_Bluetooth_Display/Mobile_App) | Flutter Android app: speech recognition (incl. Arabic+English mix), ML Kit translation, Arabic shaping, LCD preview, Bluetooth Classic SPP |
| [`ESP32_ArduinoISP_Clock`](ESP32_ArduinoISP_Clock) | ESP32 as an STK500v1 ISP programmer with a rescue clock output, used to recover the ATmega32A after the fuses were set to an external crystal that did not oscillate |

Ready-made APK and HEX: see **Releases**.

Details: [`Speech_To_Text_Bluetooth_Display/README.md`](Speech_To_Text_Bluetooth_Display/README.md).
