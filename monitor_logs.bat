@echo off
REM ========================================
REM BioShield - Live Log Monitor
REM ========================================
REM Monitors timing logs in real-time
REM ========================================

setlocal enabledelayedexpansion

set LOG_DIR=/storage/emulated/0/BioShield/logs

echo ========================================
echo BioShield Live Log Monitor
echo ========================================
echo [*] Monitoring: %LOG_DIR%
echo [*] Press Ctrl+C to stop
echo ========================================
echo.

REM Check device connection
adb devices | findstr /r "device$" > nul
if %errorlevel% neq 0 (
    echo [!] ERROR: No device connected
    pause
    exit /b 1
)

REM Get initial file count
for /f %%i in ('adb shell "ls %LOG_DIR%/ 2>/dev/null | wc -l"') do set PREV_COUNT=%%i
echo [*] Current log files: %PREV_COUNT%
echo.
echo [*] Waiting for new log entries...
echo ========================================
echo.

:monitor_loop
timeout /t 2 /nobreak > nul

REM Check for new files
for /f %%i in ('adb shell "ls %LOG_DIR%/ 2>/dev/null | wc -l"') do set CURR_COUNT=%%i

if !CURR_COUNT! gtr !PREV_COUNT! (
    echo [+] NEW LOG DETECTED! [%date% %time%]
    echo ========================================

    REM Get latest file
    for /f "delims=" %%i in ('adb shell "ls -t %LOG_DIR%/ | head -n 1"') do set LATEST=%%i
    echo [*] File: !LATEST!
    echo.

    REM Display content
    adb shell cat %LOG_DIR%/!LATEST!
    echo.
    echo ========================================
    echo.
    echo [*] Monitoring continues...
    echo.

    set PREV_COUNT=!CURR_COUNT!
)

goto monitor_loop
