import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../version.dart';

/// Service to check for app updates
///
/// Compares local build number with server version.json
/// Shows update prompt when new version is available
class VersionCheckerService {
  static const String _versionEndpoint = '/version.json';

  DateTime? _lastCheckTime;
  static const Duration _checkInterval = Duration(hours: 1);

  bool _updateAvailable = false;
  String _updateMessage = 'A new version is available. Please refresh.';
  int? _latestBuildNumber;

  bool get updateAvailable => _updateAvailable;
  String get updateMessage => _updateMessage;
  int? get latestBuildNumber => _latestBuildNumber;

  /// Check if an update is available
  ///
  /// Returns true if a newer version exists on the server
  Future<bool> checkForUpdate() async {
    // Only run on web platform
    if (!kIsWeb) {
      debugPrint('VersionChecker: Not running on web, skipping check');
      return false;
    }

    // Rate limit checks to once per hour
    if (_lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck < _checkInterval) {
        debugPrint(
          'VersionChecker: Checked ${timeSinceLastCheck.inMinutes}min ago, skipping',
        );
        return _updateAvailable;
      }
    }

    try {
      debugPrint('VersionChecker: Checking for updates...');
      debugPrint('VersionChecker: Current build: ${AppVersion.buildNumber}');

      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$_versionEndpoint?t=$timestamp';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _latestBuildNumber = data['buildNumber'] as int?;
        _updateMessage = data['updateMessage'] as String? ?? _updateMessage;

        if (_latestBuildNumber != null) {
          _updateAvailable = _latestBuildNumber! > AppVersion.buildNumber;

          if (_updateAvailable) {
            debugPrint(
              'VersionChecker: Update available! '
              'Current: ${AppVersion.buildNumber}, '
              'Latest: $_latestBuildNumber',
            );
          } else {
            debugPrint('VersionChecker: App is up to date');
          }
        }

        _lastCheckTime = DateTime.now();
        return _updateAvailable;
      } else {
        debugPrint('VersionChecker: HTTP ${response.statusCode}');
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
  }
}

/// Singleton instance
final versionCheckerService = VersionCheckerService();
