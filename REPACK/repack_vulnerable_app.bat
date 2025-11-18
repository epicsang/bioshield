@echo off
REM Automated Repackaging for Vulnerable Test App
REM Package: com.bioshield.test.secure_notes_test

title BioShield - Repackaging Vulnerable App

echo ======================================================================
echo          BioShield APK Repackager
echo      Repackaging: Secure Notes Test App
echo ======================================================================
echo.

REM Set variables
set PACKAGE=com.bioshield.test.secure_notes_test
set APP_NAME=secure_notes_test

echo [*] Checking device connection...
adb devices | find "device" >nul
if errorlevel 1 (
    echo [ERROR] No device connected!
    echo Please connect your Android device and enable USB debugging.
    pause
    exit /b 1
)
echo [OK] Device connected
echo.

echo [*] Getting APK path...
for /f "tokens=*" %%i in ('adb shell pm path %PACKAGE%') do set APK_PATH=%%i
set APK_PATH=%APK_PATH:package:=%

if "%APK_PATH%"=="" (
    echo [ERROR] App not found on device!
    echo Please install the vulnerable app first.
    pause
    exit /b 1
)
echo [OK] Found APK at: %APK_PATH%
echo.

echo [*] Creating directories...
if not exist "temp" mkdir temp
if not exist "output" mkdir output
echo [OK] Directories ready
echo.

echo [*] Extracting APK from device...
adb pull %APK_PATH% temp\%APP_NAME%.apk
if errorlevel 1 (
    echo [ERROR] Failed to extract APK
    pause
    exit /b 1
)
echo [OK] APK extracted
echo.

echo [*] Checking for apktool...
if not exist "tools\apktool.jar" (
    echo [ERROR] apktool.jar not found!
    echo.
    echo Please download apktool.jar and place it in: REPACK\tools\
    echo Download from: https://ibotpeaches.github.io/Apktool/
    echo.
    pause
    exit /b 1
)
echo [OK] apktool found
echo.

echo [*] Decompiling APK...
if exist "temp\%APP_NAME%_decompiled" rmdir /s /q "temp\%APP_NAME%_decompiled"
java -jar tools\apktool.jar d temp\%APP_NAME%.apk -o temp\%APP_NAME%_decompiled -f
if errorlevel 1 (
    echo [ERROR] Failed to decompile APK
    pause
    exit /b 1
)
echo [OK] APK decompiled
echo.

echo [*] Modifying AndroidManifest.xml...
REM Add storage permissions
powershell -Command "$content = Get-Content 'temp\%APP_NAME%_decompiled\AndroidManifest.xml' -Raw; if ($content -notmatch 'READ_EXTERNAL_STORAGE') { $content = $content -replace '</manifest>', '    <uses-permission android:name=\"android.permission.READ_EXTERNAL_STORAGE\"/>`n    <uses-permission android:name=\"android.permission.WRITE_EXTERNAL_STORAGE\"/>`n</manifest>' }; $content | Set-Content 'temp\%APP_NAME%_decompiled\AndroidManifest.xml'"
echo [OK] Manifest updated with storage permissions
echo.

echo [*] Recompiling APK...
java -jar tools\apktool.jar b temp\%APP_NAME%_decompiled -o output\%APP_NAME%_repackaged.apk
if errorlevel 1 (
    echo [ERROR] Failed to recompile APK
    pause
    exit /b 1
)
echo [OK] APK recompiled
echo.

echo [*] Signing APK...
if exist "tools\uber-apk-signer.jar" (
    echo Using uber-apk-signer...
    java -jar tools\uber-apk-signer.jar --apks output\%APP_NAME%_repackaged.apk
    echo [OK] APK signed
) else (
    echo [WARNING] uber-apk-signer.jar not found
    echo APK needs to be signed manually or will be signed during installation
)
echo.

REM Find the signed APK
set SIGNED_APK=output\%APP_NAME%_repackaged.apk
if exist "output\%APP_NAME%_repackaged-aligned-signed.apk" (
    set SIGNED_APK=output\%APP_NAME%_repackaged-aligned-signed.apk
)

echo ======================================================================
echo [SUCCESS] REPACKAGING COMPLETE!
echo ======================================================================
echo.
echo Output APK: %SIGNED_APK%
echo.
echo Next steps:
echo 1. Uninstall original app
echo 2. Install repackaged APK
echo 3. Use the app with BioShield scanning
echo.

set /p INSTALL="Do you want to install the repackaged APK now? (y/n): "
if /i "%INSTALL%"=="y" (
    echo.
    echo [*] Uninstalling original app...
    adb uninstall %PACKAGE%

    echo [*] Installing repackaged APK...
    adb install -r "%SIGNED_APK%"

    if errorlevel 1 (
        echo [ERROR] Installation failed
        echo Try manually: adb install -r "%SIGNED_APK%"
    ) else (
        echo [OK] Installation successful!
        echo.
        echo The app is ready to use with BioShield!
    )
)

echo.
pause
