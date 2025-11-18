@echo off
echo ========================================
echo TIMING CORRELATION ATTACK DEMONSTRATION
echo ========================================
echo.
echo This attack uses different timing for success vs failure
echo   Success: 2000ms
echo   Failure: 800ms
echo   Difference: 1200ms (leaks info!)
echo.
echo BioShield should detect:
echo   - TIMING_CORRELATION
echo   - Side-channel score: 30-60/100
echo.
echo Starting Frida with timing correlation attack script...
echo.

"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l timing_correlation_attack.js --no-pause

pause
