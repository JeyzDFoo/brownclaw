import 'package:flutter/foundation.dart';

/// Debug logging utility that only prints in debug mode
/// 🔇 PRODUCTION SAFE: Automatically disabled in release builds (kDebugMode = false)
/// All logging is completely silenced in production deployments
class DebugLogger {
  // Always respect kDebugMode - silent in production builds
  static bool _isEnabled = kDebugMode;

  /// Enable or disable debug logging (only works in debug mode)
  /// In production builds, logging is always disabled regardless of this setting
  static void setEnabled(bool enabled) {
    _isEnabled = kDebugMode && enabled;
  }

  /// Log a debug message with optional emoji prefix
  /// 🔇 Silent in production builds
  static void log(String message, [String emoji = '🔍']) {
    if (_isEnabled && kDebugMode) {
      debugPrint('$emoji $message');
    }
  }

  /// Log an info message - 🔇 Silent in production
  static void info(String message) {
    log(message, 'ℹ️');
  }

  /// Log a warning message - 🔇 Silent in production
  static void warning(String message) {
    log(message, '⚠️');
  }

  /// Log an error message - 🔇 Silent in production
  static void error(String message) {
    log(message, '❌');
  }

  /// Log a success message - 🔇 Silent in production
  static void success(String message) {
    log(message, '✅');
  }

  /// Log a loading message - � Silent in production
  static void loading(String message) {
    log(message, '⏳');
  }
}
