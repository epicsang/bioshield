@echo off
echo ========================================
echo TIMING ATTACK DEMONSTRATION
echo ========================================
echo.
echo This attack bypasses authentication instantly (~5ms)
echo BioShield should detect:
echo   - TIMING_ATTACK
echo   - CONSTANT_TIME_LEAK
echo   - Side-channel score: 55-85/100
echo.
echo Starting Frida with timing attack script...
echo.

"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l timing_attack.js --no-pause

pause
