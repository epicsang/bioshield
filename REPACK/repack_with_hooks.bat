@echo off
REM BioShield Automated APK Repackaging with Hook Injection
REM Usage: repack_with_hooks.bat <package_name>

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   BioShield APK Repackaging with Hooks
echo ========================================
echo.

REM Check if package name provided
if "%1"=="" (
    echo [!] Usage: repack_with_hooks.bat ^<package_name^>
    echo.
    echo Example:
    echo   repack_with_hooks.bat com.bioshield.test.secure_notes_test
    exit /b 1
)

set PACKAGE=%1
set APP_NAME=app
set TOOLS_DIR=tools
set TEMP_DIR=temp
set OUTPUT_DIR=output

REM Verify tools exist
if not exist "%TOOLS_DIR%\apktool.jar" (
    echo [!] apktool.jar not found!
    echo     Run: python download_tools.py
    exit /b 1
)

if not exist "%TOOLS_DIR%\uber-apk-signer.jar" (
    echo [!] uber-apk-signer.jar not found!
    echo     Run: python download_tools.py
    exit /b 1
)

REM Create directories
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [*] Step 1: Getting APK path from device...
for /f "tokens=*" %%i in ('adb shell pm path %PACKAGE% 2^>nul') do set APK_PATH=%%i
set APK_PATH=%APK_PATH:package:=%

if "%APK_PATH%"=="" (
    echo [!] Package not found: %PACKAGE%
    echo     Make sure the app is installed and device is connected
    exit /b 1
)

echo     Found: %APK_PATH%

echo.
echo [*] Step 2: Pulling APK from device...
adb pull "%APK_PATH%" "%TEMP_DIR%\%APP_NAME%.apk" >nul 2>&1
if errorlevel 1 (
    echo [!] Failed to pull APK
    exit /b 1
)
echo     [OK] APK pulled successfully

echo.
echo [*] Step 3: Decompiling APK...
if exist "%TEMP_DIR%\%APP_NAME%_decompiled" rmdir /s /q "%TEMP_DIR%\%APP_NAME%_decompiled"
java -jar "%TOOLS_DIR%\apktool.jar" d "%TEMP_DIR%\%APP_NAME%.apk" -o "%TEMP_DIR%\%APP_NAME%_decompiled" -f >nul 2>&1
if errorlevel 1 (
    echo [!] Failed to decompile APK
    exit /b 1
)
echo     [OK] APK decompiled

echo.
echo [*] Step 4: Injecting BioShield hooks...

REM Create smali directory structure
set PKG_PATH=%PACKAGE:.=\%
set SMALI_DIR=%TEMP_DIR%\%APP_NAME%_decompiled\smali\%PKG_PATH%
if not exist "%SMALI_DIR%" mkdir "%SMALI_DIR%"

REM Copy BioShieldApplication.smali template
if not exist "%TEMP_DIR%\BioShieldApplication.smali" (
    echo [!] BioShieldApplication.smali template not found!
    echo     Creating minimal hook...

    REM Create minimal BioShieldApplication.smali
    (
        echo .class public L%PACKAGE:.=/%/BioShieldApplication;
        echo .super Landroid/app/Application;
        echo .source "BioShieldApplication.java"
        echo.
        echo.
        echo # static fields
        echo .field private static final TAG:Ljava/lang/String; = "BioShield.Hook"
        echo.
        echo .field private static instance:L%PACKAGE:.=/%/BioShieldApplication;
        echo.
        echo.
        echo # direct methods
        echo .method public constructor ^<init^>^(^)V
        echo     .registers 1
        echo.
        echo     invoke-direct {p0}, Landroid/app/Application;-^<init^>^(^)V
        echo.
        echo     return-void
        echo .end method
        echo.
        echo .method public static getInstance^(^)L%PACKAGE:.=/%/BioShieldApplication;
        echo     .registers 1
        echo.
        echo     sget-object v0, L%PACKAGE:.=/%/BioShieldApplication;-^>instance:L%PACKAGE:.=/%/BioShieldApplication;
        echo.
        echo     return-object v0
        echo .end method
        echo.
        echo.
        echo # virtual methods
        echo .method public onCreate^(^)V
        echo     .registers 3
        echo.
        echo     invoke-super {p0}, Landroid/app/Application;-^>onCreate^(^)V
        echo.
        echo     sput-object p0, L%PACKAGE:.=/%/BioShieldApplication;-^>instance:L%PACKAGE:.=/%/BioShieldApplication;
        echo.
        echo     const-string v0, "BioShield.Hook"
        echo.
        echo     const-string v1, "BioShield Hook Application Started"
        echo.
        echo     invoke-static {v0, v1}, Landroid/util/Log;-^>d^(Ljava/lang/String;Ljava/lang/String;^)I
        echo.
        echo     const-string v0, "BioShield.Hook"
        echo.
        echo     invoke-virtual {p0}, L%PACKAGE:.=/%/BioShieldApplication;-^>getPackageName^(^)Ljava/lang/String;
        echo.
        echo     move-result-object v1
        echo.
        echo     invoke-static {v0, v1}, Landroid/util/Log;-^>d^(Ljava/lang/String;Ljava/lang/String;^)I
        echo.
        echo     return-void
        echo .end method
    ) > "%SMALI_DIR%\BioShieldApplication.smali"

    echo     [OK] Created BioShieldApplication.smali
) else (
    copy "%TEMP_DIR%\BioShieldApplication.smali" "%SMALI_DIR%\BioShieldApplication.smali" >nul
    echo     [OK] Copied BioShieldApplication.smali
)

REM Update AndroidManifest.xml to add BioShieldApplication
set MANIFEST=%TEMP_DIR%\%APP_NAME%_decompiled\AndroidManifest.xml
powershell -Command "(Get-Content '%MANIFEST%') -replace '<application ([^>]*?)>', '<application $1 android:name=\".BioShieldApplication\">' | Set-Content '%MANIFEST%'"

REM Add storage permissions
findstr /C:"WRITE_EXTERNAL_STORAGE" "%MANIFEST%" >nul
if errorlevel 1 (
    powershell -Command "(Get-Content '%MANIFEST%') -replace '</manifest>', '    <uses-permission android:name=\"android.permission.WRITE_EXTERNAL_STORAGE\"/>`n    <uses-permission android:name=\"android.permission.READ_EXTERNAL_STORAGE\"/>`n    <uses-permission android:name=\"android.permission.MANAGE_EXTERNAL_STORAGE\"/>`n</manifest>' | Set-Content '%MANIFEST%'"
)

echo     [OK] Updated AndroidManifest.xml

echo.
echo [*] Step 5: Recompiling APK...
if exist "%OUTPUT_DIR%\%APP_NAME%_hooked.apk" del "%OUTPUT_DIR%\%APP_NAME%_hooked.apk"
java -jar "%TOOLS_DIR%\apktool.jar" b "%TEMP_DIR%\%APP_NAME%_decompiled" -o "%OUTPUT_DIR%\%APP_NAME%_hooked.apk" >nul 2>&1
if errorlevel 1 (
    echo [!] Failed to recompile APK
    exit /b 1
)
echo     [OK] APK recompiled

echo.
echo [*] Step 6: Signing APK...
java -jar "%TOOLS_DIR%\uber-apk-signer.jar" --apks "%OUTPUT_DIR%\%APP_NAME%_hooked.apk" >nul 2>&1
if errorlevel 1 (
    echo [!] Failed to sign APK
    exit /b 1
)
echo     [OK] APK signed

echo.
echo [*] Step 7: Installing APK...
set /p INSTALL="Install APK now? (y/n): "
if /i "%INSTALL%"=="y" (
    adb uninstall %PACKAGE% >nul 2>&1
    for %%f in ("%OUTPUT_DIR%\*aligned*Signed.apk") do (
        echo     Installing %%f...
        adb install "%%f"
        if not errorlevel 1 (
            echo.
            echo ========================================
            echo   SUCCESS! Hooked APK Installed
            echo ========================================
            echo.
            echo Package: %PACKAGE%
            echo Hook: BioShieldApplication injected
            echo.
            echo Test with:
            echo   adb shell am start -n %PACKAGE%/.MainActivity
            echo   adb logcat -s BioShield.Hook:*
        )
    )
) else (
    echo.
    echo [*] Signed APK saved to:
    for %%f in ("%OUTPUT_DIR%\*aligned*Signed.apk") do echo     %%f
)

echo.
endlocal
