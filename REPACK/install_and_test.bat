@echo off
REM ==================================================
REM INSTALL AND TEST GADGET-ENABLED APK
REM ==================================================

set APK=bioshield_with_gadget.apk

if not exist "%APK%" (
    echo ERROR: %APK% not found
    echo Please run repack_with_gadget.bat first
    exit /b 1
)

echo ========================================
echo INSTALLING GADGET-ENABLED BIOSHIELD
echo ========================================
echo.

echo [1/5] Creating log directory on device...
adb shell mkdir -p /sdcard/BioShield/logs
adb shell chmod 777 /sdcard/BioShield/logs

echo [2/5] Uninstalling old version...
adb uninstall com.fyp.bioshield.bioshield 2>nul

echo [3/5] Installing new APK...
adb install -r "%APK%"

if %errorlevel% neq 0 (
    echo ERROR: Installation failed
    exit /b 1
)

echo [4/5] Launching BioShield...
adb shell am start -n com.fyp.bioshield.bioshield/.MainActivity

echo [5/5] Waiting for app to initialize...
timeout /t 3 /nobreak >nul

echo.
echo ========================================
echo APP LAUNCHED - READY FOR TESTING
echo ========================================
echo.
echo To test biometric events:
echo   1. Trigger fingerprint: adb emu finger touch 1
echo   2. View logs: adb shell cat /sdcard/BioShield/logs/logs.jsonl
echo   3. Monitor logcat: adb logcat -s "Frida"
echo.
echo Press any key to view current logs...
pause >nul

adb shell cat /sdcard/BioShield/logs/logs.jsonl
