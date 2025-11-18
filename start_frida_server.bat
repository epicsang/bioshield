@echo off
REM Script to start frida-server on emulator if not already running
REM Author: BioShield Team
REM Usage: start_frida_server.bat

echo [*] Checking if frida-server is running...

REM Check if frida-server process exists
adb shell "pidof frida-server" >nul 2>&1

if %errorlevel% equ 0 (
    echo [+] frida-server is already running!
    for /f %%i in ('adb shell "pidof frida-server"') do set PID=%%i
    echo [+] Process ID: %PID%
    exit /b 0
)

echo [-] frida-server is not running. Starting it now...

REM Enable root access
echo [*] Enabling root access...
adb root >nul 2>&1

REM Wait a moment for adb to restart
timeout /t 2 /nobreak >nul

REM Check if frida-server binary exists
echo [*] Checking if frida-server binary exists on device...
adb shell "ls /data/local/tmp/frida-server" >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] ERROR: frida-server binary not found at /data/local/tmp/frida-server
    echo [!] Please push frida-server to the device first:
    echo [!]   adb push frida-server-x86_64 /data/local/tmp/frida-server
    echo [!]   adb shell "chmod 755 /data/local/tmp/frida-server"
    exit /b 1
)

REM Start frida-server in background
echo [*] Starting frida-server...
adb shell "nohup /data/local/tmp/frida-server > /dev/null 2>&1 &"

REM Wait a moment for server to start
timeout /t 2 /nobreak >nul

REM Verify it started successfully
adb shell "pidof frida-server" >nul 2>&1

if %errorlevel% equ 0 (
    for /f %%i in ('adb shell "pidof frida-server"') do set PID=%%i
    echo [+] SUCCESS! frida-server started with PID: %PID%
    exit /b 0
) else (
    echo [!] ERROR: Failed to start frida-server
    exit /b 1
)
