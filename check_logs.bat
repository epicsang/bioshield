@echo off
REM ========================================
REM BioShield - Check Timing Logs
REM ========================================
REM Pulls and displays timing logs from device
REM ========================================

setlocal enabledelayedexpansion

set LOG_DIR=/storage/emulated/0/BioShield/logs
set LOCAL_DIR=logs_from_device

echo ========================================
echo BioShield Log Checker
echo ========================================
echo [*] Device Log Path: %LOG_DIR%
echo [*] Local Download Path: %LOCAL_DIR%
echo ========================================
echo.

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

REM Check if log directory exists
echo [*] Checking if log directory exists on device...
adb shell "test -d %LOG_DIR% && echo exists || echo missing" | findstr "exists" > nul
if %errorlevel% neq 0 (
    echo [!] WARNING: Log directory does not exist on device
    echo [!] Creating directory...
    adb shell mkdir -p %LOG_DIR%
    echo [+] Directory created!
)
echo.

REM List log files
echo [*] Listing log files on device...
echo ========================================
adb shell ls -lh %LOG_DIR%/ 2>nul
if %errorlevel% neq 0 (
    echo [!] No log files found
    echo.
    echo [*] Possible reasons:
    echo    1. App hasn't been tested yet
    echo    2. Frida hooks haven't triggered
    echo    3. Storage permissions not granted
    echo.
    echo [*] Try:
    echo    - Run the app and trigger biometric authentication
    echo    - Check Frida is connected (connect_frida_gadget.bat)
    echo    - Grant storage permissions manually in Settings
    pause
    exit /b 0
)
echo ========================================
echo.

REM Count log files
for /f %%i in ('adb shell "ls %LOG_DIR%/ | wc -l"') do set LOG_COUNT=%%i
echo [*] Total log files: %LOG_COUNT%
echo.

REM Ask user if they want to pull logs
set /p PULL="Do you want to pull all logs to local PC? (y/n): "
if /i not "%PULL%"=="y" (
    echo [*] Skipping download
    goto :display_latest
)

REM Create local directory
echo [*] Creating local directory: %LOCAL_DIR%
if not exist "%LOCAL_DIR%" (
    mkdir "%LOCAL_DIR%"
) else (
    echo [*] Cleaning existing local directory...
    del /q "%LOCAL_DIR%\*" 2>nul
)
echo.

REM Pull all logs
echo [*] Pulling logs from device...
adb pull %LOG_DIR%/ %LOCAL_DIR%/
if %errorlevel% neq 0 (
    echo [!] ERROR: Failed to pull logs
    pause
    exit /b 1
)
echo [+] Logs downloaded to %LOCAL_DIR%/
echo.

:display_latest
REM Display latest log
echo ========================================
echo [*] Latest Log Entry:
echo ========================================
for /f "delims=" %%i in ('adb shell "ls -t %LOG_DIR%/ | head -n 1"') do set LATEST=%%i
echo [*] File: %LATEST%
echo.
adb shell cat %LOG_DIR%/%LATEST%
echo.
echo ========================================

REM Display statistics
echo.
echo [*] Log Statistics:
echo ========================================
adb shell "cd %LOG_DIR% && cat *.jsonl 2>/dev/null | grep -o '\"success\":true' | wc -l" > temp_success.txt
set /p SUCCESS_COUNT=<temp_success.txt
del temp_success.txt

adb shell "cd %LOG_DIR% && cat *.jsonl 2>/dev/null | grep -o '\"success\":false' | wc -l" > temp_fail.txt
set /p FAIL_COUNT=<temp_fail.txt
del temp_fail.txt

echo [+] Successful authentications: %SUCCESS_COUNT%
echo [+] Failed authentications: %FAIL_COUNT%
echo ========================================
echo.

echo [*] Options:
echo    1. View all logs: type "adb shell cat %LOG_DIR%/*.jsonl"
echo    2. Clear logs: run clear_logs.bat
echo    3. Monitor live: run monitor_logs.bat
echo.
pause
