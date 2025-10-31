import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../version.dart';

/// Service to check for app updates via Firestore
///
/// Compares local build number with Firestore app_config/version document
/// Shows update prompt when new version is available
///
/// ✅ Benefits over static JSON:
/// - Bypasses PWA caching completely
/// - Real-time updates via Firestore
/// - No HTTP cache issues
/// - Admin can update version info instantly
class VersionCheckerService {
  static const String _versionCollection = 'app_config';
  static const String _versionDocument = 'version';

  DateTime? _lastCheckTime;
  static const Duration _checkInterval = Duration(hours: 1);

  // Debug override - set to true to bypass rate limiting for testing
  static const bool _debugMode = kDebugMode;

  bool _updateAvailable = false;
  String _updateMessage = 'A new version is available. Please refresh.';
  int? _latestBuildNumber;
  List<String> _changelog = [];

  bool get updateAvailable => _updateAvailable;
  String get updateMessage => _updateMessage;
  int? get latestBuildNumber => _latestBuildNumber;
  List<String> get changelog => _changelog;

  /// Check if an update is available
  ///
  /// Returns true if a newer version exists on the server
  Future<bool> checkForUpdate() async {
    // Only run on web platform (but allow debug override)
    if (!kIsWeb) {
      debugPrint(
        'VersionChecker: Not running on web platform (kIsWeb=$kIsWeb), skipping check',
      );
      return false;
    }

    debugPrint('VersionChecker: Running on web platform (kIsWeb=$kIsWeb)');

    // Rate limit checks to once per hour (bypass in debug mode)
    if (_lastCheckTime != null && !_debugMode) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck < _checkInterval) {
        debugPrint(
          'VersionChecker: Checked ${timeSinceLastCheck.inMinutes}min ago, skipping',
        );
        return _updateAvailable;
      }
    }

    if (_debugMode) {
      debugPrint('VersionChecker: Debug mode - bypassing rate limiting');
    }

    try {
      debugPrint('VersionChecker: Checking for updates via Firestore...');
      debugPrint('VersionChecker: Current build: ${AppVersion.buildNumber}');

      // Fetch version info from Firestore (bypasses all caching)
      final versionDoc = await FirebaseFirestore.instance
          .collection(_versionCollection)
          .doc(_versionDocument)
          .get()
          .timeout(const Duration(seconds: 10));

      if (versionDoc.exists) {
        final data = versionDoc.data()!;
        debugPrint('VersionChecker: Firestore document data: $data');

        _latestBuildNumber = data['buildNumber'] as int?;
        _updateMessage = data['updateMessage'] as String? ?? _updateMessage;

        debugPrint('VersionChecker: Parsed latest build: $_latestBuildNumber');
        debugPrint('VersionChecker: Current build: ${AppVersion.buildNumber}');

        // Parse changelog if available
        if (data['changelog'] is List) {
          _changelog = (data['changelog'] as List)
              .map((e) => e.toString())
              .toList();
        }

        if (_latestBuildNumber != null) {
          _updateAvailable = _latestBuildNumber! > AppVersion.buildNumber;
          debugPrint(
            'VersionChecker: Update available? $_updateAvailable ($_latestBuildNumber > ${AppVersion.buildNumber})',
          );

          if (_updateAvailable) {
            debugPrint(
              'VersionChecker: Update available! '
              'Current: ${AppVersion.buildNumber}, '
              'Latest: $_latestBuildNumber',
            );
            if (_changelog.isNotEmpty) {
              debugPrint('VersionChecker: Changelog:');
              for (final item in _changelog) {
                debugPrint('  - $item');
              }
            }
          } else {
            debugPrint('VersionChecker: App is up to date');
          }
        }

        _lastCheckTime = DateTime.now();
        return _updateAvailable;
      } else {
        debugPrint('VersionChecker: Version document not found in Firestore');
        return false;
      }
    } catch (e) {
      debugPrint('VersionChecker: Error checking version: $e');
      return false;
    }
  }

  /// Force a version check (ignores rate limiting)
  Future<bool> forceCheck() async {
    _lastCheckTime = null;
    return checkForUpdate();
  }

  /// Reset update flag (after user dismisses or refreshes)
  void clearUpdateFlag() {
    _updateAvailable = false;
    _changelog = [];
  }
}

/// Singleton instance - lazy initialization
VersionCheckerService? _versionCheckerServiceInstance;
VersionCheckerService get versionCheckerService {
  _versionCheckerServiceInstance ??= VersionCheckerService();
  return _versionCheckerServiceInstance!;
}
