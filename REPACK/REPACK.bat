@echo off
REM BioShield APK Repackager - Windows Launcher
REM Automated tool to inject custom hook framework into Android APKs

title BioShield APK Repackager

echo.
echo ================================================================
echo              BioShield APK Repackager
echo         Automated Hook Framework Injection Tool
echo ================================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    echo.
    echo Please install Python 3.7 or higher from:
    echo https://www.python.org/downloads/
    echo.
    echo Make sure to check "Add Python to PATH" during installation
    pause
    exit /b 1
)

REM Check if Java is installed
java -version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Java is not installed or not in PATH
    echo.
    echo Please install Java JDK 8 or higher from:
    echo https://www.oracle.com/java/technologies/downloads/
    echo.
    pause
    exit /b 1
)

REM Check if ADB is installed
adb version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Android Debug Bridge (ADB) is not installed or not in PATH
    echo.
    echo Please install Android Platform Tools from:
    echo https://developer.android.com/studio/releases/platform-tools
    echo.
    echo After downloading:
    echo 1. Extract the zip file
    echo 2. Add the platform-tools folder to your PATH
    echo.
    pause
    exit /b 1
)

REM Check if apktool exists
if not exist "tools\apktool.jar" (
    echo [WARNING] apktool.jar not found in tools\ directory
    echo.
    echo Please download apktool from:
    echo https://ibotpeaches.github.io/Apktool/
    echo.
    echo And place apktool.jar in: %~dp0tools\
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "%continue%"=="y" (
        exit /b 1
    )
)

echo [OK] All requirements checked
echo.
echo Starting BioShield APK Repackager...
echo.

REM Run the Python script
python repack_app.py

if errorlevel 1 (
    echo.
    echo [ERROR] Repackaging failed
    pause
    exit /b 1
)

echo.
echo ================================================================
echo                  Repackaging Complete!
echo ================================================================
echo.
pause
