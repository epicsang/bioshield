// lib/screens/faq_screen.dart
// Updated FAQ screen for the new in-app hook framework

import 'package:flutter/material.dart';
import '../constants/colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        foregroundColor: kAuthNavy,
        title: const Text(
          'FAQ - How to Use BioShield',
          style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSkyBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAuthNavy, width: 2),
            ),
            child: const Column(
              children: [
                Icon(Icons.help_outline, size: 48, color: kAuthNavy),
                SizedBox(height: 12),
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kAuthNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Learn how to use BioShield\'s in-app hook framework for biometric security analysis',
                  style: TextStyle(color: kTextSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FAQ 1: What is BioShield?
          _buildFaqItem(
            question: 'What is BioShield?',
            answer:
                'BioShield is an advanced biometric security analysis tool that uses an in-app hook framework to detect vulnerabilities in Android apps. Unlike traditional tools that require root access or complex setup, BioShield works by repackaging apps with built-in security monitoring that runs entirely within the app itself.',
            icon: Icons.shield,
          ),

          // FAQ 2: How does the Hook Framework work?
          _buildFaqItem(
            question: 'How does the in-app hook framework work?',
            answer:
                'BioShield injects a lightweight monitoring framework directly into the app during repackaging. This framework:\n\n'
                '• Intercepts all biometric authentication attempts\n'
                '• Monitors timing patterns and detects anomalies\n'
                '• Logs authentication events in real-time\n'
                '• Assesses security risks automatically\n'
                '• Works without root access, ADB, or network connection\n\n'
                'The app functions normally while BioShield quietly monitors all biometric activity.',
            icon: Icons.settings_input_component,
            isExpanded: true,
          ),

          // FAQ 3: How to use Frida with laptop
          _buildFaqItem(
            question: 'How do I use Frida injection with my laptop?',
            answer:
                'For advanced timing analysis, use Frida from your laptop:\n\n'
                '1. Install Frida Tools:\n'
                '   pip install frida-tools\n\n'
                '2. Setup Frida Server on Device:\n'
                '   • Download frida-server for your device architecture\n'
                '   • Push to device: adb push frida-server /data/local/tmp/\n'
                '   • Make executable: adb shell chmod 755 /data/local/tmp/frida-server\n'
                '   • Start server: adb shell "su -c \'/data/local/tmp/frida-server &\'"\n\n'
                '3. Inject Enhanced Frida Agent:\n'
                '   frida -U -f <package.name> -l REPACK/frida/agent.js --no-pause\n\n'
                '4. The agent will:\n'
                '   • Hook BiometricPrompt & FingerprintManager APIs\n'
                '   • Capture 5 detailed timing metrics\n'
                '   • Perform statistical analysis\n'
                '   • Write timing.jsonl to device storage\n\n'
                '5. View detailed timing analysis in BioShield app\n\n'
                'See FRIDA_INJECTION_VIDEO_GUIDE.md for full walkthrough!',
            icon: Icons.laptop,
            isExpanded: true,
          ),

          // FAQ 4: How to Repackage Apps
          _buildFaqItem(
            question: 'How do I repackage an app for scanning?',
            answer:
                'Repackaging is quick and easy:\n\n'
                '1. Connect your phone via USB\n'
                '2. Enable USB Debugging in Developer Options\n'
                '3. Double-click REPACKAGE_NOW.bat (Windows)\n'
                '   OR run: python scripts/auto_repackage_for_device.py\n'
                '4. Select the app you want to scan from the menu\n'
                '5. Wait ~30 seconds while the script:\n'
                '   - Extracts the APK from your phone\n'
                '   - Injects the hook framework\n'
                '   - Recompiles and signs the APK\n'
                '   - Installs it back on your phone\n'
                '6. Open the repackaged app and use biometric features\n'
                '7. View scan results in BioShield app\n\n'
                'The entire process is fully automated!',
            icon: Icons.build,
            isExpanded: true,
          ),

          // FAQ 4: What tools do I need?
          _buildFaqItem(
            question: 'What tools do I need?',
            answer:
                'Required tools (one-time setup):\n\n'
                '• Python 3.8+ (for automation scripts)\n'
                '• Java JDK 8+ (for APK signing)\n'
                '• Android Platform Tools (ADB)\n'
                '• apktool (for APK decompiling/recompiling)\n'
                '• zipalign (for APK optimization)\n\n'
                'Installation takes about 20 minutes. Run our verification script to check:\n'
                'python scripts/verify_setup.py\n\n'
                'Detailed installation guide: INSTALL_AND_SETUP.md',
            icon: Icons.construction,
          ),

          // FAQ 5: Do I need root access?
          _buildFaqItem(
            question: 'Do I need root access or special permissions?',
            answer:
                'No! This is one of BioShield\'s biggest advantages:\n\n'
                '✅ No root access required\n'
                '✅ No ADB connection needed (after installation)\n'
                '✅ No network/server setup\n'
                '✅ Works on any Android device\n'
                '✅ Normal app installation process\n\n'
                'The hook framework runs entirely within the app itself, making it much easier to use than traditional security tools.',
            icon: Icons.security,
          ),

          // FAQ 6: How long does it take?
          _buildFaqItem(
            question: 'How long does the analysis take?',
            answer:
                'The process is very fast:\n\n'
                '• Initial setup (tools installation): ~20 minutes (one-time)\n'
                '• Repackaging an app: ~30 seconds\n'
                '• Real-time monitoring: Instant (as you use the app)\n'
                '• Viewing results: Instant (open BioShield app)\n\n'
                'After the one-time setup, you can analyze any app in under a minute!',
            icon: Icons.timer,
          ),

          // FAQ 7: What does it detect?
          _buildFaqItem(
            question: 'What security issues does BioShield detect?',
            answer:
                'BioShield\'s hook framework detects:\n\n'
                '🚨 Timing Anomalies:\n'
                '• Authentication too fast (< 200ms) - possible bypass\n'
                '• Authentication too slow (> 30s) - timeout issues\n'
                '• Rapid retry attempts - possible brute force\n'
                '• Instant success after error - possible patching\n'
                '• Zero-duration events - possible tampering\n\n'
                '📊 Security Analysis:\n'
                '• Crypto usage (or lack thereof)\n'
                '• Authentication patterns\n'
                '• Success/failure rates\n'
                '• Session behavior\n\n'
                '🎯 Risk Assessment:\n'
                '• SAFE - No issues detected\n'
                '• LOW - Minor anomalies\n'
                '• MEDIUM - Moderate security concerns\n'
                '• HIGH - Serious vulnerabilities',
            icon: Icons.bug_report,
            isExpanded: true,
          ),

          // FAQ 8: How accurate is the detection?
          _buildFaqItem(
            question: 'How accurate is the anomaly detection?',
            answer:
                'BioShield uses multiple detection methods:\n\n'
                '1. Timing Analysis - Measures duration of auth events\n'
                '2. Pattern Recognition - Identifies suspicious behavior\n'
                '3. Session Tracking - Monitors multi-auth sessions\n'
                '4. Statistical Analysis - Compares against normal baselines\n\n'
                'The framework has been tested against known bypass techniques and shows high accuracy in detecting:\n'
                '• Biometric spoofing attempts\n'
                '• Authentication bypass exploits\n'
                '• API misuse and vulnerabilities\n'
                '• Timing-based attacks',
            icon: Icons.psychology,
          ),

          // FAQ 9: Can I export reports?
          _buildFaqItem(
            question: 'Can I export scan data and reports?',
            answer:
                'Yes! BioShield provides multiple export options:\n\n'
                '📄 JSON Reports:\n'
                '• Comprehensive scan results\n'
                '• All authentication events\n'
                '• Timing statistics\n'
                '• Anomaly details\n\n'
                '📊 ML-Ready Data:\n'
                '• JSONL format (newline-delimited JSON)\n'
                '• Perfect for machine learning training\n'
                '• Includes all raw event data\n'
                '• Easy to process with Python/pandas\n\n'
                '📱 Export Methods:\n'
                '• Via BioShield app UI\n'
                '• Via ADB shell commands\n'
                '• Automatic file generation',
            icon: Icons.file_download,
          ),

          // FAQ 10: Where is data stored?
          _buildFaqItem(
            question: 'Where is my scan data stored?',
            answer:
                'Security and privacy first:\n\n'
                '📱 On-Device Storage:\n'
                '• All logs are stored locally in the app\'s internal storage using on-device IPC. No cloud connection is required for analysis.\n'
                '• Location: /data/data/<package>/files/bioshield_logs/\n'
                '• Not accessible by other apps\n'
                '• Automatic cleanup (keeps the 10 most recent log files)\n\n'
                '☁️ Cloud Sync (Optional):\n'
                '• Firebase integration for backup\n'
                '• Only if you enable it\n'
                '• Encrypted transmission\n'
                '• You control your data\n\n'
                '🔒 Privacy:\n'
                '• No data shared without permission\n'
                '• No analytics or tracking\n'
                '• Complete data ownership',
            icon: Icons.storage,
          ),

          // FAQ 11: Comparison with other tools
          _buildFaqItem(
            question: 'How is this different from other security tools?',
            answer:
                'BioShield\'s in-app hooks vs Traditional Tools:\n\n'
                '✅ BioShield Advantages:\n'
                '• No root access required\n'
                '• No ADB connection needed\n'
                '• 30-second setup\n'
                '• 95% success rate\n'
                '• Works on any device\n'
                '• Can\'t be detected by apps\n'
                '• Normal installation process\n'
                '• Fast and efficient\n\n'
                '❌ Traditional Tools:\n'
                '• Require root or persistent ADB\n'
                '• Complex server setup\n'
                '• Easily detected\n'
                '• Network dependent\n'
                '• Manual intervention needed\n'
                '• Not production-ready\n\n'
                'BioShield uses a custom hook framework built specifically for biometric security analysis.',
            icon: Icons.compare_arrows,
          ),

          // FAQ 12: Can apps detect BioShield?
          _buildFaqItem(
            question: 'Can apps detect that BioShield is monitoring them?',
            answer:
                'BioShield is designed to be invisible:\n\n'
                '✅ Undetectable Because:\n'
                '• No external processes running\n'
                '• No network connections made\n'
                '• No suspicious libraries loaded\n'
                '• Looks like normal app code\n'
                '• No root detection triggers\n\n'
                '📝 What Apps See:\n'
                '• A normally functioning app\n'
                '• Standard biometric prompts\n'
                '• Normal response times\n'
                '• No suspicious behavior\n\n'
                'The hook framework is completely transparent to the app and operates at the Java layer, making it virtually undetectable.',
            icon: Icons.visibility_off,
          ),

          // FAQ 13: Troubleshooting
          _buildFaqItem(
            question: 'What if repackaging fails or the app crashes?',
            answer:
                'Common solutions:\n\n'
                '🔧 Repackaging Fails:\n'
                '• Check all tools are installed: run verify_setup.py\n'
                '• Ensure phone is connected: adb devices\n'
                '• Try a different app (some have anti-tampering)\n'
                '• Check INSTALL_AND_SETUP.md for detailed steps\n\n'
                '💥 App Crashes:\n'
                '• Check logcat for errors: adb logcat\n'
                '• Some banking apps have strong security\n'
                '• Try apps with standard BiometricPrompt\n'
                '• ProGuard obfuscation may cause issues\n\n'
                '📊 No Logs Generated:\n'
                '• App may not use BiometricPrompt\n'
                '• Check hooks initialized: adb logcat | findstr BioShield\n'
                '• Verify app has biometric features\n\n'
                'Full troubleshooting guide in INSTALL_AND_SETUP.md',
            icon: Icons.troubleshoot,
          ),

          // FAQ 14: Free vs Premium
          _buildFaqItem(
            question: 'What\'s the difference between Free and Premium?',
            answer:
                'Free Tier:\n'
                '• 3 scans per 24 hours\n'
                '• Basic vulnerability reports\n'
                '• Manual repackaging\n'
                '• Standard export (JSON)\n\n'
                'Premium Tier:\n'
                '• Unlimited scans\n'
                '• Advanced ML-powered analysis\n'
                '• Automated batch repackaging\n'
                '• Priority support\n'
                '• Detailed remediation guides\n'
                '• Cloud sync and backup\n'
                '• Historical trend analysis\n'
                '• Custom alerting',
            icon: Icons.stars,
          ),

          // FAQ 15: ML Integration
          _buildFaqItem(
            question: 'How does the ML integration work?',
            answer:
                'BioShield uses machine learning for advanced analysis:\n\n'
                '🧠 Data Collection:\n'
                '• The hook framework logs all biometric events locally.\n'
                '• JSONL format perfect for ML training\n'
                '• Features: timing, crypto usage, patterns\n\n'
                '📊 On-Device Analysis:\n'
                '• TFLite models run on-device\n'
                '• Real-time anomaly prediction\n'
                '• Pattern recognition\n'
                '• Behavioral analysis\n\n'
                '🎯 Benefits:\n'
                '• Detect unknown vulnerabilities\n'
                '• Improve accuracy over time\n'
                '• Personalized risk assessment\n'
                '• Zero-day detection capability\n\n'
                'Models can be updated and trained with new vulnerability data.',
            icon: Icons.psychology_alt,
          ),

          const SizedBox(height: 32),

          // Need more help section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSkyBlue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 40, color: kAuthNavy),
                const SizedBox(height: 12),
                const Text(
                  'Still need help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kAuthNavy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check out our comprehensive documentation',
                  style: TextStyle(color: kTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('See START_HERE.md in project root'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.book, size: 18),
                      label: const Text('Quick Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAuthNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('See INSTALL_AND_SETUP.md for detailed guide'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Setup Guide'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAuthNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('See HOOK_FRAMEWORK_EXPLAINED.md for technical details'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Technical Docs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAuthNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
    required IconData icon,
    bool isExpanded = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: kCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderLight, width: 1),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: kAuthNavy,
          ),
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSkyBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kAuthNavy, size: 24),
          ),
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
              fontSize: 16,
            ),
          ),
          initiallyExpanded: isExpanded,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                answer,
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
