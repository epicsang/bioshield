# BioShield APK Repack Guide

Welcome to the BioShield Frida Gadget APK Repack Guide!

## Contents

### Main Documentation
- **[REPACK_GUIDE.md](REPACK_GUIDE.md)** - Complete step-by-step guide for repacking APKs with Frida Gadget

### Reference Files

The `reference_files/` folder contains all the necessary scripts and configurations:

#### Core Script
- **`frida_biometric_script.js`** - The main Frida Gadget hook script
  - Hooks androidx.biometric.BiometricPrompt
  - Captures authentication events (success/failure/error)
  - Encrypts logs using AES-256-GCM
  - Writes to `/storage/emulated/0/Download/BioShield/logs.jsonl`

#### Automation Scripts
- **`scripts/patch_manifest.py`** - Automatically adds `android:extractNativeLibs="true"` to AndroidManifest.xml
- **`scripts/patch_mainactivity.py`** - Automatically injects Frida Gadget loader into MainActivity.smali

## Quick Start

1. Read [REPACK_GUIDE.md](REPACK_GUIDE.md) thoroughly
2. Gather all prerequisites listed in the guide
3. Copy `frida_biometric_script.js` - this will become `libfrida-gadget.script.so`
4. Follow the 7-step process in the guide
5. Test on your device using the verification steps

## What You'll Need (Not Included)

You must download separately:
- **Frida Gadget binary** from https://github.com/frida/frida/releases
  - For Android emulator: `frida-gadget-16.5.9-android-x86_64.so`
  - For physical devices: `frida-gadget-16.5.9-android-arm64.so`
- **APKTool** from https://apktool.org/
- **Android SDK Build Tools** (includes apksigner, zipalign)

## Configuration Files You'll Create

During the repack process, you'll create:

### `libfrida-gadget.config.so`
```json
{
  "interaction": {
    "type": "script",
    "path": "libfrida-gadget.script.so",
    "on_load": "init"
  }
}
```

Place this file in `temp_repack/lib/<architecture>/`

## Architecture Support

This setup has been tested on:
- Android 12, 13, 14 (API 31-34)
- x86_64 (emulator)
- arm64-v8a (physical devices)

## File Placement Overview

```
temp_repack/
├── AndroidManifest.xml (modified: extractNativeLibs="true")
├── smali_classes<N>/
│   └── <package_path>/
│       └── MainActivity.smali (modified: Gadget loader injected)
└── lib/
    └── <architecture>/
        ├── libfrida-gadget.so (Frida Gadget binary)
        ├── libfrida-gadget.config.so (JSON config)
        └── libfrida-gadget.script.so (JavaScript hooks)
```

## Success Indicators

After following the guide, you should see in `adb logcat`:

```
I FRIDA_LOADER: SUCCESS: Frida Gadget loaded
I FRIDA_SCRIPT: === [BioShield] init() called, stage: early ===
I FRIDA_SCRIPT: [OK] Hooked BiometricPrompt constructor
I FRIDA_SCRIPT: [OK] Hooked authenticate() methods
I FRIDA_SCRIPT: [OK] Hooked AuthenticationCallback
I FRIDA_SCRIPT: === [BioShield] Biometric Hooks Active ===
```

## Important Notes

### The 3-File .so Convention

**Critical:** All 3 files MUST end with `.so` extension:
- ✅ `libfrida-gadget.so`
- ✅ `libfrida-gadget.config.so`
- ✅ `libfrida-gadget.script.so`

Why? Android only extracts files ending in `.so` from the `lib/` folder. This is a limitation of the APK extraction mechanism, not Frida.

### Security Considerations

- **Encryption Key**: The script uses a hardcoded AES key for demonstration. Generate a unique key for production.
- **Log Storage**: Logs are written to public Downloads folder. Consider app-private storage for sensitive data.
- **App Distribution**: Only repack apps you own or have explicit permission to modify.

## Troubleshooting

If something goes wrong, refer to the comprehensive troubleshooting section in [REPACK_GUIDE.md](REPACK_GUIDE.md#troubleshooting).

Common issues:
- App crashes → Missing `extractNativeLibs="true"`
- Gadget loads but no hooks → Missing `"on_load": "init"` in config
- No events captured → Wrong biometric API or fingerprint not enrolled

## Support

For detailed explanations of each step, error messages, and solutions, see the full guide: [REPACK_GUIDE.md](REPACK_GUIDE.md)

---

**Version:** 1.0
**Last Updated:** 2025-11-16
**Compatible with:** Frida Gadget 16.5.9
