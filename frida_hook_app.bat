@echo off
REM Script to hook an app with Frida and launch it
REM Author: BioShield Team
REM Usage: frida_hook_app.bat [package_name] [agent_script]
REM Example: frida_hook_app.bat com.fyp.limit.limit_test_app REPACK/frida/agent.js

REM Configuration - Edit these if needed
set FRIDA_PATH=C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe
set DEFAULT_PACKAGE=com.fyp.limit.limit_test_app
set DEFAULT_AGENT=REPACK/frida/agent.js

REM Parse arguments
set PACKAGE=%1
set AGENT=%2

REM Use defaults if not provided
if "%PACKAGE%"=="" set PACKAGE=%DEFAULT_PACKAGE%
if "%AGENT%"=="" set AGENT=%DEFAULT_AGENT%

echo ========================================
echo BioShield Frida Hook Script
echo ========================================
echo [*] Target Package: %PACKAGE%
echo [*] Agent Script: %AGENT%
echo ========================================
echo.

REM Step 1: Ensure frida-server is running
echo [Step 1/4] Checking frida-server status...
call start_frida_server.bat
if %errorlevel% neq 0 (
    echo [!] ERROR: Failed to start frida-server
    pause
    exit /b 1
)
echo.

REM Step 2: Check if app is installed
echo [Step 2/4] Verifying app is installed...
adb shell "pm list packages | grep %PACKAGE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] ERROR: Package %PACKAGE% is not installed on the device
    echo [!] Install the app first using: adb install app.apk
    pause
    exit /b 1
)
echo [+] App is installed
echo.

REM Step 3: Check if agent script exists
echo [Step 3/4] Verifying agent script exists...
if not exist "%AGENT%" (
    echo [!] ERROR: Agent script not found: %AGENT%
    pause
    exit /b 1
)
echo [+] Agent script found
echo.

REM Step 4: Launch Frida with spawn mode
echo [Step 4/4] Launching Frida in spawn mode...
echo [*] Command: "%FRIDA_PATH%" -U -f %PACKAGE% -l %AGENT%
echo [*] Press Ctrl+C to stop Frida
echo.
echo ========================================
echo Frida Output:
echo ========================================
echo.

REM Launch Frida
"%FRIDA_PATH%" -U -f %PACKAGE% -l %AGENT%

REM If Frida exits
echo.
echo ========================================
echo [*] Frida session ended
echo ========================================
pause
