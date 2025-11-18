@echo off
REM ========================================
REM BioShield - Connect to Frida Gadget
REM ========================================
REM Connects Frida to embedded Gadget
REM ========================================

setlocal enabledelayedexpansion

set FRIDA_PATH=C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe
REM CHANFE APP_PACKAGE TO YOUR PACKAGE NAME
set APP_PACKAGE=com.fyp.limit.limit_test_app 
set AGENT_PATH=REPACK/frida/agent.js

echo ========================================
echo BioShield Frida Gadget Connection
echo ========================================
echo [*] Target Package: %APP_PACKAGE%
echo [*] Agent Script: %AGENT_PATH%
echo [*] Mode: Listen (TCP port 27042)
echo ========================================
echo.

REM Check if Frida exists
if not exist "%FRIDA_PATH%" (
    echo [!] ERROR: Frida not found at %FRIDA_PATH%
    echo [!] Please install frida-tools:
    echo [!] pip install frida-tools
    pause
    exit /b 1
)

REM Check device connection
echo [*] Checking device connection...
adb devices | findstr /r "device$" > nul
if %errorlevel% neq 0 (
    echo [!] ERROR: No device connected
    pause
    exit /b 1
)
echo [+] Device connected!
echo.

REM Check if app is installed
echo [*] Checking if app is installed...
adb shell pm list packages | findstr %APP_PACKAGE% > nul
if %errorlevel% neq 0 (
    echo [!] ERROR: App not installed
    echo [!] Please run install_frida_apk.bat first
    pause
    exit /b 1
)
echo [+] App is installed!
echo.

REM Check if app is running
echo [*] Checking if app is running...
adb shell pidof %APP_PACKAGE% > nul 2>&1
if %errorlevel% neq 0 (
    echo [*] App not running, launching...
    adb shell am start -n %APP_PACKAGE%/.MainActivity
    timeout /t 3 > nul
)
echo [+] App is running!
echo.

echo ========================================
echo [*] Connecting Frida to Gadget...
echo [*] Press Ctrl+C to stop
echo ========================================
echo.

REM Connect to Frida Gadget
"%FRIDA_PATH%" -U -n %APP_PACKAGE% -l %AGENT_PATH% --no-pause

echo.
echo [*] Frida connection closed
pause
