@echo off
REM Simulate fingerprint touches for testing

SET DEVICE_ID=emulator-5554

echo ========================================
echo BioShield Fingerprint Test Script
echo ========================================
echo [*] Device: %DEVICE_ID%
echo ========================================
echo.

:menu
echo [1] Send CORRECT fingerprint (ID 1)
echo [2] Send WRONG fingerprint (ID 0)
echo [3] Send 5 correct fingerprints (test batch)
echo [4] Exit
echo.
set /p choice="Select option: "

if "%choice%"=="1" goto correct
if "%choice%"=="2" goto wrong
if "%choice%"=="3" goto batch
if "%choice%"=="4" goto end

echo Invalid choice!
goto menu

:correct
echo [*] Sending CORRECT fingerprint...
adb -s %DEVICE_ID% emu finger touch 1
echo [+] Done!
echo.
goto menu

:wrong
echo [*] Sending WRONG fingerprint...
adb -s %DEVICE_ID% emu finger touch 0
echo [+] Done!
echo.
goto menu

:batch
echo [*] Sending 5 CORRECT fingerprints...
for /L %%i in (1,1,5) do (
    echo [*] Touch %%i/5...
    adb -s %DEVICE_ID% emu finger touch 1
    timeout /t 3 /nobreak >nul
)
echo [+] Batch test complete!
echo.
goto menu

:end
echo Exiting...
pause
