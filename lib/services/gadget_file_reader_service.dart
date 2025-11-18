import 'dart:io';
import 'dart:convert';

/// Service to read biometric logs from shared storage
/// Written by Frida Gadget in hooked apps
///
/// Simple file-based IPC:
/// 1. Frida writes to /storage/emulated/0/BioShield/logs/*.jsonl
/// 2. BioShield reads, parses, and deletes files
/// 3. No ContentProvider needed!
class GadgetFileReaderService {
  static const String logDir = "/storage/emulated/0/BioShield/logs";

  /// Read all logs from shared storage
  Future<List<Map<String, dynamic>>> readAllLogs() async {
    try {
      final directory = Directory(logDir);
      if (!await directory.exists()) {
        print('[GadgetFileReader] Log directory not found: $logDir');
        return [];
      }

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList();

      print('[GadgetFileReader] Found ${files.length} log files');

      List<Map<String, dynamic>> allLogs = [];
      for (var file in files) {
        try {
          final lines = await file.readAsLines();
          for (var line in lines) {
            if (line.trim().isNotEmpty) {
              try {
                allLogs.add(jsonDecode(line));
              } catch (e) {
                print('[GadgetFileReader] Error parsing line: $e');
              }
            }
          }
        } catch (e) {
          print('[GadgetFileReader] Error reading file ${file.path}: $e');
        }
      }

      print('[GadgetFileReader] Read ${allLogs.length} total log events');
      return allLogs;
    } catch (e) {
      print('[GadgetFileReader] Error: $e');
      return [];
    }
  }

  /// Delete all log files after processing
  Future<int> clearLogs() async {
    try {
      final directory = Directory(logDir);
      if (!await directory.exists()) {
        print('[GadgetFileReader] Log directory does not exist');
        return 0;
      }

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList();

      int deletedCount = 0;
      for (var file in files) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          print('[GadgetFileReader] Error deleting ${file.path}: $e');
        }
      }

      print('[GadgetFileReader] Deleted $deletedCount log files');
      return deletedCount;
    } catch (e) {
      print('[GadgetFileReader] Error clearing logs: $e');
      return 0;
    }
  }

  /// Watch for new log files (for waiting mode)
  Stream<FileSystemEvent> watchLogs() {
    final directory = Directory(logDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory.watch(events: FileSystemEvent.create);
  }

  /// Count available log files
  Future<int> countLogFiles() async {
    try {
      final directory = Directory(logDir);
      if (!await directory.exists()) {
        return 0;
      }

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList();

      return files.length;
    } catch (e) {
      print('[GadgetFileReader] Error counting files: $e');
      return 0;
    }
  }

  /// Get the log directory path
  String getLogDirectory() {
    return logDir;
  }

  /// Ensure log directory exists
  Future<void> ensureLogDirectoryExists() async {
    try {
      final directory = Directory(logDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('[GadgetFileReader] Created log directory: $logDir');
      }
    } catch (e) {
      print('[GadgetFileReader] Error creating directory: $e');
    }
  }
}
