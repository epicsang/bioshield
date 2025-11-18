@echo off
color 0A
title BioShield - Automated Frida Gadget Repack (Demo Mode)

:: ========================================
:: AUTOMATED FRIDA GADGET REPACK SCRIPT
:: For BioShield FYP Video Demonstration
:: ========================================

echo.
echo ========================================
echo    BIOSHIELD FRIDA GADGET REPACK
echo    Automated Demonstration Script
echo ========================================
echo.
echo This script will:
echo   1. Decompile the APK
echo   2. Inject Frida Gadget library
echo   3. Inject Frida loader code
echo   4. Recompile the APK
echo   5. Sign the APK
echo   6. Install to device
echo.
echo Press any key to start...
pause >nul

:: Check if input APK provided
if "%~1"=="" (
    echo [ERROR] No APK file specified!
    echo Usage: AUTOMATED_REPACK_DEMO.bat path\to\app.apk
    pause
    exit /b 1
)

set "INPUT_APK=%~1"
set "APK_NAME=%~n1"
set "OUTPUT_APK=%APK_NAME%_with_gadget_signed.apk"

echo.
echo ========================================
echo STEP 1/6: Cleaning Previous Build
echo ========================================
if exist temp_repack rd /s /q temp_repack
if exist "%OUTPUT_APK%" del "%OUTPUT_APK%"
echo [OK] Cleaned temp files
timeout /t 1 >nul

echo.
echo ========================================
echo STEP 2/6: Decompiling APK
echo ========================================
echo Input: %INPUT_APK%
echo.
java -jar tools/apktool.jar d "%INPUT_APK%" -o temp_repack -f
if errorlevel 1 (
    echo [ERROR] Decompilation failed!
    pause
    exit /b 1
)
echo [OK] APK decompiled successfully
timeout /t 2 >nul

echo.
echo ========================================
echo STEP 3/6: Injecting Frida Gadget Library
echo ========================================
echo Copying Frida Gadget files to lib/x86_64/
if not exist "temp_repack\lib\x86_64" mkdir "temp_repack\lib\x86_64"
copy /Y "frida\libfrida-gadget-x86_64.so" "temp_repack\lib\x86_64\libfrida-gadget.so"
copy /Y "frida\libfrida-gadget.script.so" "temp_repack\lib\x86_64\libfrida-gadget.script.so"
copy /Y "frida\libfrida-gadget.config.so" "temp_repack\lib\x86_64\libfrida-gadget.config.so"
echo [OK] Frida Gadget library + script + config injected
timeout /t 1 >nul

echo.
echo ========================================
echo STEP 4/6: Injecting Frida Loader Code
echo ========================================
echo Modifying MainActivity.smali to load Frida Gadget...

:: Find MainActivity.smali
for /r "temp_repack\smali_classes7" %%f in (MainActivity.smali) do (
    echo Found: %%f

    :: Backup original
    copy "%%f" "%%f.backup"

    :: Inject loader code using Python
    python inject_frida_loader.py "%%f"

    if errorlevel 1 (
        echo [ERROR] Failed to inject loader code!
        pause
        exit /b 1
    )

    echo [OK] Frida loader injected into MainActivity
    goto :loader_done
)

:loader_done
timeout /t 2 >nul

echo.
echo ========================================
echo STEP 5/6: Recompiling APK
echo ========================================
echo Building modified APK...
echo.
java -jar tools/apktool.jar b temp_repack -o "%APK_NAME%_unsigned.apk"
if errorlevel 1 (
    echo [ERROR] Recompilation failed!
    pause
    exit /b 1
)
echo [OK] APK recompiled successfully
timeout /t 2 >nul

echo.
echo ========================================
echo STEP 6/6: Signing APK
echo ========================================
echo Signing with debug keystore...
"C:\Users\User\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat" sign --ks "C:\Users\User\.android\debug.keystore" --ks-pass pass:android --key-pass pass:android --min-sdk-version 21 --out "%OUTPUT_APK%" "%APK_NAME%_unsigned.apk"
if errorlevel 1 (
    echo [ERROR] Signing failed!
    pause
    exit /b 1
)
echo [OK] APK signed successfully
del "%APK_NAME%_unsigned.apk"
timeout /t 1 >nul

echo.
echo ========================================
echo     REPACK COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo Output APK: %OUTPUT_APK%
echo Size:
dir "%OUTPUT_APK%" | find "apk"
echo.
echo ========================================
echo Installing to Device? (Y/N)
echo ========================================
set /p INSTALL="Install now? (Y/N): "
if /i "%INSTALL%"=="Y" goto :install
if /i "%INSTALL%"=="y" goto :install
goto :end

:install
echo.
echo Installing APK to device...
adb install -r "%OUTPUT_APK%"
if errorlevel 1 (
    echo [ERROR] Installation failed!
    pause
    exit /b 1
)
echo [OK] APK installed successfully!

echo.
echo ========================================
echo Launching App? (Y/N)
echo ========================================
set /p LAUNCH="Launch app now? (Y/N): "
if /i "%LAUNCH%"=="Y" goto :launch
if /i "%LAUNCH%"=="y" goto :launch
goto :end

:launch
echo.
echo Launching app...
adb shell am start -n com.example.biometric_test_app/.MainActivity
echo [OK] App launched!

:end
echo.
echo ========================================
echo        PROCESS COMPLETE!
echo ========================================
echo.
echo Next steps:
echo   1. Trigger biometric authentication in the app
echo   2. Check logs: adb logcat ^| findstr "FRIDA"
echo   3. Open BioShield and process logs
echo.
pause
