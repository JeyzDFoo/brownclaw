import 'package:flutter/foundation.dart';

/// Debug logging utility that only prints in debug mode
/// and can be easily disabled for production or testing
class DebugLogger {
  static bool _isEnabled = kDebugMode;

  /// Enable or disable debug logging
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Log a debug message with optional emoji prefix
  static void log(String message, [String emoji = '🔍']) {
    if (_isEnabled) {
      print('$emoji $message');
    }
  }

  /// Log an info message
  static void info(String message) {
    log(message, '🟦');
  }

  /// Log a warning message
  static void warning(String message) {
    log(message, '🟠');
  }

  /// Log an error message
  static void error(String message) {
    log(message, '🔴');
  }

  /// Log a success message
  static void success(String message) {
    log(message, '🟢');
  }
}
