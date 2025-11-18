@echo off
echo ========================================
echo REPLAY ATTACK DEMONSTRATION
echo ========================================
echo.
echo This attack replays constant 500ms timing patterns
echo BioShield should detect:
echo   - REPLAY_PATTERN
echo   - CONSTANT_TIME_LEAK
echo   - LOW_TIMING_ENTROPY
echo   - Side-channel score: 50-75/100
echo.
echo Starting Frida with replay attack script...
echo.

"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l replay_attack.js --no-pause

pause
