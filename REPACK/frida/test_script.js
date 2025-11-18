// Simple test script
console.log = function(msg) {
    try {
        Java.perform(() => {
            const Log = Java.use("android.util.Log");
            Log.i("FRIDA_SCRIPT_TEST", String(msg));
        });
    } catch (e) {}
};

console.log("TEST: Script is executing!");

Java.perform(() => {
    console.log("TEST: Java.perform() is working!");
});
