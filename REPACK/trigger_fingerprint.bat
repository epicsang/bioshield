@echo off
REM ==================================================
REM TRIGGER FINGERPRINT ON EMULATOR
REM ==================================================

echo Triggering fingerprint event (finger ID: 1)...
adb emu finger touch 1

timeout /t 1 /nobreak >nul

echo.
echo Checking logs...
adb shell cat /sdcard/BioShield/logs/logs.jsonl | tail -n 5

echo.
echo Done. Run view_logs.bat to see all events.
