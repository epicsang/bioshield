@echo off
REM ==================================================
REM VIEW BIOMETRIC LOGS FROM DEVICE
REM ==================================================

set LOG_PATH=/sdcard/BioShield/logs/logs.jsonl

echo ========================================
echo BIOMETRIC EVENT LOGS
echo ========================================
echo.

adb shell "[ -f %LOG_PATH% ] && cat %LOG_PATH% || echo 'No logs found at %LOG_PATH%'"

echo.
echo ========================================
echo LOG COUNT
echo ========================================
adb shell "[ -f %LOG_PATH% ] && wc -l %LOG_PATH% || echo '0'"

echo.
echo Press any key to monitor live Frida output...
pause >nul

adb logcat -s "Frida"
