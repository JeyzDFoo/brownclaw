import 'package:flutter/foundation.dart';

/// Performance logging utility for tracking app startup and initialization times
/// Helps identify bottlenecks in the app loading process
class PerformanceLogger {
  static final Map<String, DateTime> _timestamps = {};
  static final List<String> _logs = [];
  static DateTime? _appStartTime;

  /// Mark the start of app initialization
  static void markAppStart() {
    _appStartTime = DateTime.now();
    _mark('app_start');
    if (kDebugMode) {
      print('⏱️ [PERF] App startup initiated');
    }
  }

  /// Mark a specific point in time with a label
  static void _mark(String label) {
    _timestamps[label] = DateTime.now();
  }

  /// Log a performance checkpoint with duration from previous checkpoint
  static void log(String label, {String? detail}) {
    final now = DateTime.now();
    _mark(label);

    if (_appStartTime == null) {
      if (kDebugMode) {
        print(
          '⚠️ [PERF] Warning: App start time not set. Call markAppStart() first.',
        );
      }
      return;
    }

    final totalDuration = now.difference(_appStartTime!);
    final message = detail != null
        ? '⏱️ [PERF] $label (+${totalDuration.inMilliseconds}ms) - $detail'
        : '⏱️ [PERF] $label (+${totalDuration.inMilliseconds}ms)';

    _logs.add(message);

    if (kDebugMode) {
      print(message);
    }
  }

  /// Log duration between two specific checkpoints
  static void logDuration(String label, String startLabel, String endLabel) {
    final start = _timestamps[startLabel];
    final end = _timestamps[endLabel];

    if (start == null || end == null) {
      if (kDebugMode) {
        print(
          '⚠️ [PERF] Warning: Missing timestamp for $startLabel or $endLabel',
        );
      }
      return;
    }

    final duration = end.difference(start);
    final message = '⏱️ [PERF] $label: ${duration.inMilliseconds}ms';
    _logs.add(message);

    if (kDebugMode) {
      print(message);
    }
  }

  /// Print a summary of all performance logs
  static void printSummary() {
    if (_appStartTime == null) return;

    final totalTime = DateTime.now().difference(_appStartTime!);

    if (kDebugMode) {
      print('\n' + '=' * 60);
      print('📊 PERFORMANCE SUMMARY');
      print('=' * 60);
      for (final log in _logs) {
        print(log);
      }
      print('─' * 60);
      print('🏁 Total startup time: ${totalTime.inMilliseconds}ms');
      print('=' * 60 + '\n');
    }
  }

  /// Clear all stored performance data
  static void clear() {
    _timestamps.clear();
    _logs.clear();
    _appStartTime = null;
  }

  /// Get the duration from app start to now
  static int getTimeSinceStart() {
    if (_appStartTime == null) return 0;
    return DateTime.now().difference(_appStartTime!).inMilliseconds;
  }
}
