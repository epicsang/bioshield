@echo off
REM ========================================
REM BioShield - Clear Device Logs
REM ========================================
REM Clears timing logs from device storage
REM ========================================

setlocal enabledelayedexpansion

set LOG_DIR=/storage/emulated/0/BioShield/logs

echo ========================================
echo BioShield Log Cleaner
echo ========================================
echo [*] Log Directory: %LOG_DIR%
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

REM Count current log files
echo [*] Counting log files...
for /f %%i in ('adb shell "ls %LOG_DIR%/ 2>/dev/null | wc -l"') do set LOG_COUNT=%%i
echo [*] Found %LOG_COUNT% log files
echo.

if "%LOG_COUNT%"=="0" (
    echo [*] No logs to clear
    pause
    exit /b 0
)

REM Confirm deletion
set /p CONFIRM="Are you sure you want to delete all %LOG_COUNT% log files? (y/n): "
if /i not "%CONFIRM%"=="y" (
    echo [*] Operation cancelled
    pause
    exit /b 0
)

REM Delete logs
echo [*] Deleting log files...
adb shell rm -f %LOG_DIR%/timing_*.jsonl
if %errorlevel% neq 0 (
    echo [!] ERROR: Failed to delete logs
    pause
    exit /b 1
)
echo [+] All logs deleted!
echo.

REM Verify deletion
for /f %%i in ('adb shell "ls %LOG_DIR%/ 2>/dev/null | wc -l"') do set NEW_COUNT=%%i
echo [*] Remaining files: %NEW_COUNT%
echo.

echo ========================================
echo [+] Log directory cleared successfully!
echo ========================================
pause
