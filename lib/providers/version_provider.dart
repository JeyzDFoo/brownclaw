import 'package:flutter/foundation.dart';
import '../services/version_checker_service.dart';

/// Provider for managing app version checking
class VersionProvider extends ChangeNotifier {
  late final VersionCheckerService _versionChecker;

  bool _showUpdateBanner = false;
  bool _isChecking = false;

  VersionProvider() {
    // Initialize the version checker lazily
    _versionChecker = versionCheckerService;
  }

  bool get showUpdateBanner => _showUpdateBanner;
  bool get isChecking => _isChecking;
  bool get updateAvailable => _versionChecker.updateAvailable;
  String get updateMessage => _versionChecker.updateMessage;
  int? get latestBuildNumber => _versionChecker.latestBuildNumber;
  List<String> get changelog => _versionChecker.changelog;

  /// Check for updates
  Future<void> checkForUpdate() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      final hasUpdate = await _versionChecker.checkForUpdate();
      _showUpdateBanner = hasUpdate;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Force check (ignores rate limiting)
  Future<void> forceCheck() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      final hasUpdate = await _versionChecker.forceCheck();
      _showUpdateBanner = hasUpdate;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Dismiss the update banner
  void dismissUpdateBanner() {
    _showUpdateBanner = false;
    _versionChecker.clearUpdateFlag();
    notifyListeners();
  }
}
