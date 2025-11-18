@echo off
REM ========================================
REM BioShield - Install Frida-Repacked APK
REM ========================================
REM Automates installation on Pixel 6
REM ========================================

setlocal enabledelayedexpansion

set APK=app-debug_frida.apk
set PACKAGE=com.fyp.limit.limit_test_app

echo ========================================
echo BioShield Frida APK Installer
echo ========================================
echo [*] APK: %APK%
echo [*] Package: %PACKAGE%
echo ========================================
echo.

REM Check if APK exists
if not exist "%APK%" (
    echo [!] ERROR: %APK% not found!
    echo [!] Please run repack_with_frida_gadget.bat first
    pause
    exit /b 1
)

REM Check device connection
echo [*] Checking device connection...
adb devices | findstr /r "device$" > nul
if %errorlevel% neq 0 (
    echo [!] ERROR: No device connected
    echo [!] Please connect your Pixel 6 and enable USB debugging
    pause
    exit /b 1
)
echo [+] Device connected!
echo.

REM Uninstall old version
echo [*] Uninstalling old version (if exists)...
adb uninstall %PACKAGE% 2>nul
echo.

REM Install Frida-repacked APK
echo [*] Installing Frida-repacked APK...
adb install -r "%APK%"
if %errorlevel% neq 0 (
    echo [!] ERROR: Installation failed
    pause
    exit /b 1
)
echo [+] Installation successful!
echo.

REM Grant storage permissions
echo [*] Granting storage permissions...
adb shell pm grant %PACKAGE% android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant %PACKAGE% android.permission.WRITE_EXTERNAL_STORAGE
echo [+] Permissions granted!
echo.

REM Create log directory
echo [*] Creating log directory on device...
adb shell mkdir -p /storage/emulated/0/BioShield/logs
echo [+] Log directory ready!
echo.

REM Launch app
echo [*] Launching app...
adb shell am start -n %PACKAGE%/.MainActivity
echo [+] App launched!
echo.

echo ========================================
echo [+] SUCCESS! APK installed and launched
echo ========================================
echo.
echo [*] Next steps:
echo    1. Connect Frida: run connect_frida_gadget.bat
echo    2. Test authentication on the app
echo    3. Check logs: run check_logs.bat
echo ========================================
pause
