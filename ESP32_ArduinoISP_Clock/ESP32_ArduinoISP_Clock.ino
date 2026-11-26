// ESP32 ArduinoISP (STK500v1) with a rescue clock output.
// Based on the ArduinoISP protocol (Randall Bohn, BSD licence), rewritten for ESP32.
//
// Wiring (ATmega32A DIP-40):
//   GPIO23 -> pin 6  MOSI
//   GPIO19 <- pin 7  MISO   (through the 1k / 2k divider, ~3.3 V)
//   GPIO18 -> pin 8  SCK
//   GPIO5  -> pin 9  RESET
//   GPIO4  -> pin 13 XTAL1  (rescue clock, 2 MHz square wave)   <-- NEW WIRE
//   GND    -- GND
// avrdude: -c stk500v1 -P COMx -b 19200 -p m32
//
// Why the clock: with LFUSE=0xFF the ATmega32A runs only from an external crystal.
// If the crystal does not oscillate, the chip has no clock and answers 00 00 00.
// Driving XTAL1 from the ESP32 gives it a clock, so ISP works again.

#include <Arduino.h>

#define PIN_MOSI   23
#define PIN_MISO   19
#define PIN_SCK    18
#define PIN_RESET  5
#define PIN_CLKOUT 4
#define CLK_HZ     1000000   // target clock; ISP SCK (5 kHz) is far below CLK/4

#define LED_HB     26
#define LED_ERR    27
#define LED_PMODE  33

#define BAUDRATE   19200
#define SCK_HALF_US 100      // 5 kHz SCK

#define HWVER 2
#define SWMAJ 1
#define SWMIN 18

#define STK_OK      0x10
#define STK_FAILED  0x11
#define STK_UNKNOWN 0x12
#define STK_INSYNC  0x14
#define STK_NOSYNC  0x15
#define CRC_EOP     0x20

struct Param {
  uint8_t devicecode, revision, progtype, parmode, polling, selftimed, lockbytes, fusebytes;
  uint8_t flashpoll;
  uint16_t eeprompoll, pagesize, eepromsize;
  uint32_t flashsize;
} param;

uint8_t buff[256];
uint32_t here;          // word address
bool pmode = false;
bool errorFlag = false;
uint8_t lastPmodeEcho = 0;

// ---------------- bit-banged SPI, mode 0 ----------------
uint8_t spiTransfer(uint8_t b) {
  uint8_t in = 0;
  for (int i = 0; i < 8; i++) {
    digitalWrite(PIN_MOSI, (b & 0x80) ? HIGH : LOW);
    b <<= 1;
    delayMicroseconds(SCK_HALF_US);
    digitalWrite(PIN_SCK, HIGH);
    // Majority of 5 samples: rejects short glitches on the MISO divider.
    int ones = 0;
    for (int k = 0; k < 5; k++) { ones += digitalRead(PIN_MISO); delayMicroseconds(2); }
    in = (in << 1) | (ones >= 3 ? 1 : 0);
    delayMicroseconds(SCK_HALF_US);
    digitalWrite(PIN_SCK, LOW);
  }
  return in;
}

uint8_t spiCmd(uint8_t a, uint8_t b, uint8_t c, uint8_t d) {
  spiTransfer(a);
  spiTransfer(b);
  spiTransfer(c);
  return spiTransfer(d);
}

// ---------------- serial helpers ----------------
uint8_t getch() {
  while (!Serial.available()) delay(0);
  return Serial.read();
}
void fill(int n) { for (int i = 0; i < n; i++) buff[i] = getch(); }

void emptyReply() {
  if (getch() == CRC_EOP) { Serial.write(STK_INSYNC); Serial.write(STK_OK); }
  else { errorFlag = true; Serial.write(STK_NOSYNC); }
}
void breply(uint8_t b) {
  if (getch() == CRC_EOP) { Serial.write(STK_INSYNC); Serial.write(b); Serial.write(STK_OK); }
  else { errorFlag = true; Serial.write(STK_NOSYNC); }
}

// ---------------- programming mode ----------------
void resetTarget(bool active) { digitalWrite(PIN_RESET, active ? LOW : HIGH); }

void startPmode() {
  pinMode(PIN_MOSI, OUTPUT);
  pinMode(PIN_SCK, OUTPUT);
  pinMode(PIN_MISO, INPUT);
  digitalWrite(PIN_SCK, LOW);
  pinMode(PIN_RESET, OUTPUT);

  // Datasheet serial programming sequence: SCK low, pulse RESET, wait > 20 ms,
  // send Programming Enable; byte 3 must echo 0x53, otherwise pulse RESET and retry.
  for (int attempt = 0; attempt < 8; attempt++) {
    resetTarget(true);
    delay(2);
    resetTarget(false);
    delayMicroseconds(100);
    resetTarget(true);
    delay(100);  // covers 16K CK + 64 ms start-up (fuse SUT=11) at 2 MHz
    spiTransfer(0xAC);
    spiTransfer(0x53);
    lastPmodeEcho = spiTransfer(0x00);
    spiTransfer(0x00);
    if (lastPmodeEcho == 0x53) break;
  }
  pmode = true;
  digitalWrite(LED_PMODE, HIGH);
  errorFlag = (lastPmodeEcho != 0x53);
}

void endPmode() {
  pinMode(PIN_MOSI, INPUT);
  pinMode(PIN_SCK, INPUT);
  resetTarget(false);
  pinMode(PIN_RESET, INPUT);   // release: the 10k pull-up takes RESET high
  pmode = false;
  digitalWrite(LED_PMODE, LOW);
}

// ---------------- STK500v1 commands ----------------
void getVersion(uint8_t c) {
  switch (c) {
    case 0x80: breply(HWVER); break;
    case 0x81: breply(SWMAJ); break;
    case 0x82: breply(SWMIN); break;
    case 0x93: breply('S'); break;  // serial programmer
    default: breply(0);
  }
}

void setParameters() {
  param.devicecode = buff[0];
  param.revision   = buff[1];
  param.progtype   = buff[2];
  param.parmode    = buff[3];
  param.polling    = buff[4];
  param.selftimed  = buff[5];
  param.lockbytes  = buff[6];
  param.fusebytes  = buff[7];
  param.flashpoll  = buff[8];
  param.eeprompoll = (buff[10] << 8) | buff[11];
  param.pagesize   = (buff[12] << 8) | buff[13];
  param.eepromsize = (buff[14] << 8) | buff[15];
  param.flashsize  = ((uint32_t)buff[16] << 24) | ((uint32_t)buff[17] << 16) | (buff[18] << 8) | buff[19];
}

void universal() {
  fill(4);
  breply(spiCmd(buff[0], buff[1], buff[2], buff[3]));
}

uint32_t pageOf(uint32_t addr) {
  if (param.pagesize == 32) return addr & 0xFFFFFFF0;
  if (param.pagesize == 64) return addr & 0xFFFFFFE0;
  if (param.pagesize == 128) return addr & 0xFFFFFFC0;
  if (param.pagesize == 256) return addr & 0xFFFFFF80;
  return addr;
}

void commit(uint32_t addr) {
  spiCmd(0x4C, (addr >> 8) & 0xFF, addr & 0xFF, 0);
  delay(10);  // ATmega32 t_WD_FLASH max 4.5 ms
}

void flashByte(uint8_t hilo, uint32_t addr, uint8_t data) {
  spiCmd(0x40 + 8 * hilo, (addr >> 8) & 0xFF, addr & 0xFF, data);
}

uint8_t writeFlashPages(int length) {
  int x = 0;
  uint32_t page = pageOf(here);
  while (x < length) {
    if (page != pageOf(here)) { commit(page); page = pageOf(here); }
    flashByte(0, here, buff[x++]);
    flashByte(1, here, buff[x++]);
    here++;
  }
  commit(page);
  return STK_OK;
}

uint8_t writeEeprom(int length) {
  uint32_t start = here * 2;
  for (int x = 0; x < length; x++) {
    uint32_t a = start + x;
    spiCmd(0xC0, (a >> 8) & 0xFF, a & 0xFF, buff[x]);
    delay(10);  // t_WD_EEPROM max 9 ms
  }
  return STK_OK;
}

void programPage() {
  int length = (getch() << 8) | getch();
  uint8_t memtype = getch();
  fill(length);
  uint8_t result = STK_FAILED;
  if (memtype == 'F') result = writeFlashPages(length);
  else if (memtype == 'E') result = (length <= param.eepromsize) ? writeEeprom(length) : STK_FAILED;
  if (getch() == CRC_EOP) { Serial.write(STK_INSYNC); Serial.write(result); }
  else { errorFlag = true; Serial.write(STK_NOSYNC); }
}

void readPage() {
  int length = (getch() << 8) | getch();
  uint8_t memtype = getch();
  if (getch() != CRC_EOP) { errorFlag = true; Serial.write(STK_NOSYNC); return; }
  Serial.write(STK_INSYNC);
  if (memtype == 'F') {
    for (int x = 0; x < length; x += 2) {
      Serial.write(spiCmd(0x20, (here >> 8) & 0xFF, here & 0xFF, 0));
      Serial.write(spiCmd(0x28, (here >> 8) & 0xFF, here & 0xFF, 0));
      here++;
    }
  } else if (memtype == 'E') {
    uint32_t start = here * 2;
    for (int x = 0; x < length; x++) {
      uint32_t a = start + x;
      Serial.write(spiCmd(0xA0, (a >> 8) & 0xFF, a & 0xFF, 0));
    }
  }
  Serial.write(STK_OK);
}

void readSignature() {
  if (getch() != CRC_EOP) { errorFlag = true; Serial.write(STK_NOSYNC); return; }
  Serial.write(STK_INSYNC);
  Serial.write(spiCmd(0x30, 0, 0, 0));
  Serial.write(spiCmd(0x30, 0, 1, 0));
  Serial.write(spiCmd(0x30, 0, 2, 0));
  Serial.write(STK_OK);
}

void avrisp() {
  uint8_t ch = getch();
  switch (ch) {
    case '0': errorFlag = false; emptyReply(); break;                // sync
    case '1':
      if (getch() == CRC_EOP) { Serial.write(STK_INSYNC); Serial.print("AVR ISP"); Serial.write(STK_OK); }
      else { errorFlag = true; Serial.write(STK_NOSYNC); }
      break;
    case 'A': getVersion(getch()); break;
    case 'B': fill(20); setParameters(); emptyReply(); break;
    case 'E': fill(5); emptyReply(); break;
    case 'P': if (!pmode) startPmode(); emptyReply(); break;
    case 'U': here = getch(); here |= (uint32_t)getch() << 8; emptyReply(); break;
    case 0x60: getch(); getch(); emptyReply(); break;
    case 0x61: getch(); emptyReply(); break;
    case 0x64: programPage(); break;
    case 0x74: readPage(); break;
    case 'V': universal(); break;
    case 'Q': errorFlag = false; endPmode(); emptyReply(); break;
    case 0x75: readSignature(); break;
    case CRC_EOP: errorFlag = true; Serial.write(STK_NOSYNC); break;
    default:
      errorFlag = true;
      if (getch() == CRC_EOP) Serial.write(STK_UNKNOWN);
      else Serial.write(STK_NOSYNC);
  }
}

void setup() {
  Serial.begin(BAUDRATE);
  pinMode(LED_HB, OUTPUT);
  pinMode(LED_ERR, OUTPUT);
  pinMode(LED_PMODE, OUTPUT);
  pinMode(PIN_RESET, INPUT);   // not driven until programming starts

  // Rescue clock on GPIO4 -> XTAL1, 50 % duty, runs all the time.
  bool clockOk = ledcAttach(PIN_CLKOUT, CLK_HZ, 1);
  if (clockOk) ledcWrite(PIN_CLKOUT, 1);  // 1-bit resolution: 1 = 50 %
}

void loop() {
  static uint32_t lastHb = 0;
  if (millis() - lastHb > 500) { lastHb = millis(); digitalWrite(LED_HB, !digitalRead(LED_HB)); }
  digitalWrite(LED_ERR, errorFlag ? HIGH : LOW);
  if (Serial.available()) avrisp();
}
