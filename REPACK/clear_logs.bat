@echo off
REM ==================================================
REM CLEAR BIOMETRIC LOGS ON DEVICE
REM ==================================================

echo Clearing logs at /sdcard/BioShield/logs/logs.jsonl...
adb shell rm -f /sdcard/BioShield/logs/logs.jsonl

echo Done. Logs cleared.
