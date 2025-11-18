@echo off
REM ==================================================
REM CLEAN FRIDA GADGET REPACK SCRIPT
REM For Android 12-14, x86_64 emulator
REM ==================================================

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: repack_with_gadget.bat ^<path-to-apk^>
    exit /b 1
)

set INPUT_APK=%~1
set OUTPUT_APK=bioshield_with_gadget.apk
set WORK_DIR=temp_repack

echo.
echo ========================================
echo FRIDA GADGET REPACK - CLEAN SETUP
echo ========================================
echo Input:  %INPUT_APK%
echo Output: %OUTPUT_APK%
echo ========================================
echo.

REM Clean up
if exist "%WORK_DIR%" rd /s /q "%WORK_DIR%"
if exist "%OUTPUT_APK%" del /f "%OUTPUT_APK%"
if exist "%OUTPUT_APK%.idsig" del /f "%OUTPUT_APK%.idsig"

REM Step 1: Decompile APK
echo [1/6] Decompiling APK...
java -jar tools\apktool.jar d "%INPUT_APK%" -o "%WORK_DIR%" -f
if !errorlevel! neq 0 (
    echo ERROR: Failed to decompile APK
    exit /b 1
)

REM Step 2: Download Frida Gadget if not present
set GADGET_LIB=REPACK\frida\libs\libfrida-gadget.so
if not exist "%GADGET_LIB%" (
    echo [2/6] Downloading Frida Gadget x86_64...
    mkdir REPACK\frida\libs 2>nul
    curl -L -o "%GADGET_LIB%.xz" "https://github.com/frida/frida/releases/download/16.5.9/frida-gadget-16.5.9-android-x86_64.so.xz"
    if !errorlevel! neq 0 (
        echo ERROR: Failed to download Frida Gadget
        exit /b 1
    )
    xz -d "%GADGET_LIB%.xz"
) else (
    echo [2/6] Using existing Frida Gadget library
)

REM Step 3: Copy Gadget files to APK
echo [3/6] Copying Frida Gadget files...
mkdir "%WORK_DIR%\lib\x86_64" 2>nul

copy /y "%GADGET_LIB%" "%WORK_DIR%\lib\x86_64\libfrida-gadget.so"
copy /y "REPACK\frida\configs\libfrida-gadget.config.so" "%WORK_DIR%\lib\x86_64\libfrida-gadget.config.so"
copy /y "REPACK\frida\scripts\libfrida-gadget.script.so" "%WORK_DIR%\lib\x86_64\libfrida-gadget.script.so"

echo Files copied:
dir "%WORK_DIR%\lib\x86_64\libfrida-*"

REM Step 4: Modify AndroidManifest.xml - Add extractNativeLibs
echo [4/6] Modifying AndroidManifest.xml...
python REPACK\scripts\patch_manifest.py "%WORK_DIR%\AndroidManifest.xml"

REM Step 5: Modify MainActivity.smali - Force load Gadget
echo [5/6] Patching MainActivity to load Gadget...
python REPACK\scripts\patch_mainactivity.py "%WORK_DIR%"

REM Step 6: Recompile and sign
echo [6/6] Recompiling APK...
java -jar tools\apktool.jar b "%WORK_DIR%" -o "%OUTPUT_APK%"
if !errorlevel! neq 0 (
    echo ERROR: Failed to recompile APK
    exit /b 1
)

echo Signing APK...
"C:\Users\User\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat" sign --ks "C:\Users\User\.android\debug.keystore" --ks-pass pass:android --key-pass pass:android --min-sdk-version 21 "%OUTPUT_APK%"

if !errorlevel! neq 0 (
    echo ERROR: Failed to sign APK
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! APK ready: %OUTPUT_APK%
echo ========================================
echo.
echo Next steps:
echo   1. adb install -r %OUTPUT_APK%
echo   2. adb shell mkdir -p /sdcard/BioShield/logs
echo   3. adb shell am start -n com.fyp.bioshield.bioshield/.MainActivity
echo   4. adb emu finger touch 1
echo   5. adb shell cat /sdcard/BioShield/logs/logs.jsonl
echo.

endlocal
