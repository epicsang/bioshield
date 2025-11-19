// lib/services/permissions_service.dart
// Handle storage permissions for BioShield

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';

class PermissionsService {
  static const MethodChannel _channel = MethodChannel('com.fyp.bioshield/permissions');

  /// Open Manage All Files settings page (Android 11+)
  static Future<void> _openManageAllFilesSettings() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openManageAllFilesSettings');
      } catch (e) {
        // Fallback to regular app settings
        await openAppSettings();
      }
    }
  }

  /// Request storage permissions with user-friendly dialog
  static Future<bool> requestStoragePermissions(BuildContext context) async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't need these permissions
    }

    // Check current status
    final storageStatus = await Permission.storage.status;
    final manageStorageStatus = await Permission.manageExternalStorage.status;

    // If already granted, return true
    if (storageStatus.isGranted || manageStorageStatus.isGranted) {
      return true;
    }

    // Show explanation dialog
    if (!context.mounted) return false;
    final shouldRequest = await _showPermissionDialog(context);
    if (!shouldRequest) {
      return false;
    }

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Check if granted
    final granted = statuses[Permission.storage]?.isGranted == true ||
                    statuses[Permission.manageExternalStorage]?.isGranted == true;

    if (!granted && context.mounted) {
      // Show dialog to open settings
      await _showSettingsDialog(context);
    }

    return granted;
  }

  /// Check if storage permissions are granted
  static Future<bool> checkStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final storageStatus = await Permission.storage.status;
    final manageStorageStatus = await Permission.manageExternalStorage.status;

    return storageStatus.isGranted || manageStorageStatus.isGranted;
  }

  /// Show permission explanation dialog
  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSkyBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder_open,
                  color: kAuthNavy,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Storage Access',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAuthNavy),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BioShield needs storage access to:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kAuthNavy),
              ),
              const SizedBox(height: 12),
              const _PermissionItem(
                icon: Icons.security,
                text: 'Read Frida scan results from repackaged apps',
              ),
              const SizedBox(height: 8),
              const _PermissionItem(
                icon: Icons.upload_file,
                text: 'Import APK files for repackaging',
              ),
              const SizedBox(height: 8),
              const _PermissionItem(
                icon: Icons.save,
                text: 'Export scan reports (PDF/CSV)',
              ),
              const SizedBox(height: 16),
              Text(
                'Without storage access, BioShield cannot read scan results or repackage apps.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Not Now',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSkyBlue,
                foregroundColor: kAuthNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Grant Access',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Show dialog to open app settings
  static Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kWarning, size: 28),
              SizedBox(width: 12),
              Text('Permission Required', style: TextStyle(color: kAuthNavy)),
            ],
          ),
          content: const Text(
            'Storage permission is required for BioShield to function properly.\n\n'
            'Please grant storage access in Settings.',
            style: TextStyle(color: kAuthNavy),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openManageAllFilesSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kSkyBlue,
                foregroundColor: kAuthNavy,
              ),
              child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Request permission before running a scan
  static Future<bool> requestPermissionForScan(BuildContext context) async {
    final hasPermission = await checkStoragePermissions();

    if (!hasPermission) {
      if (!context.mounted) return false;
      return await requestStoragePermissions(context);
    }

    return true;
  }
}

/// Widget for permission item
class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kAuthNavy),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: kAuthNavy),
          ),
        ),
      ],
    );
  }
}
