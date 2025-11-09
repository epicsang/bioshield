# 1. Add dependencies in pubspec.yaml:
dependencies:
  permission_handler: ^11.3.0

# 2. Add permissions to android/app/src/main/AndroidManifest.xml:
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />

# 3. In main.dart, make this page your home screen:
import 'package:flutter/material.dart';
import 'biometric_analyzer_page.dart';

void main() => runApp(const MaterialApp(home: BiometricAnalyzerPage()));


'''
When the user taps “Analyze Latest Biometric JSON”:

The app looks inside /storage/emulated/0/Download/

Finds the newest .json file

Reads it directly

Runs all your vulnerability rules locally

Displays the risk score, weaknesses, and recommendations
'''