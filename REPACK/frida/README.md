# BioShield Frida Package
**Pixel 6 / Android 13 Compatible - Non-Root Setup**

## 📁 Directory Structure

```
BioShield/
├── REPACK/
│   └── frida/
│       ├── agent.js                    # Main Frida hook script
│       ├── gadget-config.json          # TCP listener configuration
│       └── README.md                   # This file
├── inject_frida.bat                    # Windows injection script
├── test_fingerprint.bat                # ADB fingerprint simulator
├── start_frida_server.bat              # Start frida-server
└── frida_hook_app.bat                  # Hook app script
```

## 🚀 Quick Start

### 1. Start Frida Server (if using server mode)
```cmd
start_frida_server.bat
```

### 2. Inject Frida Agent
```cmd
inject_frida.bat
```

### 3. Test Fingerprint Authentication
```cmd
test_fingerprint.bat
```

## 📝 Features

- ✅ **Shared Storage Logging**: Logs to `/storage/emulated/0/BioShield/logs/`
- ✅ **Auto-Cleanup**: Keeps last 50 log files
- ✅ **BiometricPrompt Hooks**: Both crypto and no-crypto overloads
- ✅ **FingerprintManager Hooks**: Legacy API support (Android 6-8)
- ✅ **TCP Listener Mode**: Avoids SELinux socket issues on Pixel 6
- ✅ **Timing Analysis**: Captures authentication latency metrics

## 🔧 Configuration

### Gadget Config (`gadget-config.json`)
- **Port**: 27042 (TCP listener)
- **Runtime**: V8
- **Auto-loads**: agent.js

### Agent Script (`agent.js`)
- **Log Directory**: `/storage/emulated/0/BioShield/logs/`
- **Max Log Files**: 50 (configurable via `MAX_LOG_FILES`)
- **Hooks**: BiometricPrompt + FingerprintManager

## 📊 Log Format

```json
{
  "timestamp": 1700000000000,
  "attempt": 1,
  "success": true,
  "totalLatency": 450,
  "failurePattern": null
}
```

## 🐛 Troubleshooting

### Frida Server Won't Start
```cmd
adb root
adb push REPACK/frida-server-x86_64 /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
```

### Logs Not Writing (EPERM)
- Ensure `/storage/emulated/0/BioShield/logs/` exists
- Check app has storage permissions
- Try app-specific storage: `/data/data/com.fyp.limit.limit_test_app/files/bioshield_logs/`

### Hooks Not Triggering
- Verify BiometricPrompt.authenticate() is being called
- Check logcat: `adb logcat | grep -i biometric`
- Use fallback FingerprintManager hook

## 📱 Device Compatibility

| Device | Android | Status |
|--------|---------|--------|
| Pixel 3a | API 30 | ✅ Tested |
| Pixel 6 | API 33 | ✅ Tested |
| Emulator x86_64 | API 30-34 | ✅ Tested |

## 🔒 Security Notes

- **Educational Use Only**: This tool is for security research and FYP testing
- **Do Not Use on Production Apps**: Without authorization
- **Logs Contain Sensitive Data**: Handle timing logs securely

## 📖 Documentation

- [Frida Official Docs](https://frida.re/docs/home/)
- [Android Biometric API Guide](https://developer.android.com/training/sign-in/biometric-auth)
- [BioShield Project Documentation](../README.md)

---

**Version**: 1.0.0
**Last Updated**: 2025-01-16
**Author**: BioShield Team
