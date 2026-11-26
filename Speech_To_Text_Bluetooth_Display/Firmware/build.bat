@echo off
rem Builds bt_display.hex with the avr-gcc that ships with the Arduino IDE.
rem The toolchain cannot handle non-ASCII (e.g. Arabic) folder names, so the sources
rem are copied to %TEMP%\bt_display_build first.
setlocal
set "BIN=%LOCALAPPDATA%\Arduino15\packages\arduino\tools\avr-gcc\7.3.0-atmel3.6.1-arduino7\bin"
set "OUT=%TEMP%\bt_display_build"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
copy /y "%~dp0*.c" "%OUT%" >nul
copy /y "%~dp0*.h" "%OUT%" >nul
pushd "%OUT%"
"%BIN%\avr-gcc" -mmcu=atmega32a -DF_CPU=8000000UL -Os -std=gnu99 -Wall -Wextra -ffunction-sections -fdata-sections -Wl,--gc-sections -o bt_display.elf *.c || goto :fail
"%BIN%\avr-objcopy" -O ihex -R .eeprom bt_display.elf bt_display.hex || goto :fail
"%BIN%\avr-size" -C --mcu=atmega32a bt_display.elf
popd
copy /y "%OUT%\bt_display.hex" "%~dp0bt_display.hex" >nul
echo.
echo HEX: %~dp0bt_display.hex
echo Flash: avrdude -c stk500v1 -P COM4 -b 19200 -p m32 -U flash:w:"%OUT%\bt_display.hex":i
exit /b 0
:fail
popd
echo BUILD FAILED
exit /b 1
