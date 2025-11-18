@echo off
REM ========================================
REM BioShield - Complete Testing Workflow
REM ========================================
REM Full automated workflow for Pixel 6 testing
REM ========================================

setlocal enabledelayedexpansion

echo ========================================
echo BioShield Complete Testing Workflow
echo ========================================
echo.
echo This script will:
echo   1. Install Frida-repacked APK
echo   2. Grant permissions
echo   3. Launch app
echo   4. Connect Frida
echo   5. Monitor logs in real-time
echo.
echo ========================================
pause
echo.

REM Step 1: Install APK
echo ========================================
echo STEP 1: Installing Frida-repacked APK
echo ========================================
call install_frida_apk.bat
if %errorlevel% neq 0 (
    echo [!] Installation failed
    pause
    exit /b 1
)
echo.

REM Wait for user to interact with app
echo ========================================
echo STEP 2: Manual Testing Required
echo ========================================
echo.
echo [*] The app has been launched on your device
echo [*] Please interact with the app and trigger biometric authentication
echo.
echo [*] When ready, press any key to connect Frida...
pause
echo.

REM Step 2: Connect Frida (in new window)
echo ========================================
echo STEP 3: Connecting Frida
echo ========================================
echo [*] Opening Frida connection in new window...
start "BioShield - Frida Connection" cmd /k connect_frida_gadget.bat
echo [+] Frida connection window opened
echo.

REM Wait before monitoring
timeout /t 5 > nul

REM Step 3: Monitor logs (in new window)
echo ========================================
echo STEP 4: Starting Log Monitor
echo ========================================
echo [*] Opening log monitor in new window...
start "BioShield - Log Monitor" cmd /k monitor_logs.bat
echo [+] Log monitor window opened
echo.

echo ========================================
echo [+] Workflow Setup Complete!
echo ========================================
echo.
echo [*] Active Windows:
echo    - Frida Connection (monitoring hooks)
echo    - Log Monitor (watching for new logs)
echo.
echo [*] Test Steps:
echo    1. Use the app on your Pixel 6
echo    2. Trigger biometric authentication
echo    3. Watch the Frida window for hook output
echo    4. Watch the Log Monitor for new log files
echo.
echo [*] When done testing:
echo    - Close all windows
echo    - Run check_logs.bat to review results
echo.
echo ========================================
pause
