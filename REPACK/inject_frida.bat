@echo off
REM BioShield - Frida Gadget Injection Script
REM Injects Frida Gadget into Vulnerable App APK

echo ========================================
echo BioShield Frida Gadget Injection
echo ========================================

REM Step 1: Pull APK from device (if needed)
echo.
echo [1/7] Checking for APK...
if not exist "vulnerable_app_original.apk" (
    echo Pulling vulnerable app from device...
    adb pull /data/app/~~*/com.fyp.vulnerable.vulnerable_biometric_app-*/base.apk vulnerable_app_original.apk
    if errorlevel 1 (
        echo ERROR: Failed to pull APK. Make sure device is connected.
        pause
        exit /b 1
    )
)

REM Step 2: Decompile APK
echo.
echo [2/7] Decompiling APK...
if exist "vulnerable_decompiled" rd /s /q vulnerable_decompiled
java -jar tools\apktool.jar d vulnerable_app_original.apk -o vulnerable_decompiled -f
if errorlevel 1 (
    echo ERROR: Decompilation failed
    pause
    exit /b 1
)

REM Step 3: Copy Frida Gadget library
echo.
echo [3/7] Injecting Frida Gadget library...
mkdir "vulnerable_decompiled\lib\arm64-v8a" 2>nul
copy /Y "frida\libfrida-gadget.so" "vulnerable_decompiled\lib\arm64-v8a\" >nul
copy /Y "frida\libfrida-gadget.config.so" "vulnerable_decompiled\lib\arm64-v8a\" >nul
copy /Y "frida\libfrida-gadget.script.so" "vulnerable_decompiled\lib\arm64-v8a\" >nul

REM Step 4: Modify MainActivity to load Frida (if not already done)
echo.
echo [4/7] Modifying MainActivity to load Frida...
REM Add System.loadLibrary("frida-gadget") to MainActivity

powershell -Command ^
    "$file = 'vulnerable_decompiled\smali\com\fyp\vulnerable\MainActivity.smali'; ^
    $content = Get-Content $file -Raw; ^
    if ($content -notmatch 'frida-gadget') { ^
        $content = $content -replace '(\.method public onCreate.*?\.locals \d+)', '$1`n    const-string v0, \"frida-gadget\"`n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V'; ^
        Set-Content $file $content; ^
        Write-Host 'Frida loadLibrary injected'; ^
    } else { ^
        Write-Host 'Frida already injected'; ^
    }"

REM Step 5: Rebuild APK
echo.
echo [5/7] Rebuilding APK...
if exist "vulnerable_frida.apk" del "vulnerable_frida.apk"
java -jar tools\apktool.jar b vulnerable_decompiled -o vulnerable_frida_unsigned.apk
if errorlevel 1 (
    echo ERROR: Rebuild failed
    pause
    exit /b 1
)

REM Step 6: Sign APK
echo.
echo [6/7] Signing APK...
"C:\Users\User\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat" sign ^
    --ks "C:\Users\User\.android\debug.keystore" ^
    --ks-pass pass:android ^
    --key-pass pass:android ^
    --out vulnerable_frida.apk ^
    vulnerable_frida_unsigned.apk

if errorlevel 1 (
    echo ERROR: Signing failed
    pause
    exit /b 1
)

REM Step 7: Success!
echo.
echo [7/7] ✅ SUCCESS!
echo.
echo Frida-injected APK created: vulnerable_frida.apk
echo.
echo Next steps:
echo   1. adb uninstall com.fyp.vulnerable.vulnerable_biometric_app
echo   2. adb install vulnerable_frida.apk
echo   3. Launch the app to trigger Frida Gadget
echo.
pause
