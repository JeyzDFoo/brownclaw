/// App version information
///
/// Update this file whenever you deploy to production
/// The version checker will detect when users need to refresh
class AppVersion {
  /// Current app version
  /// Format: MAJOR.MINOR.PATCH (semantic versioning)
  static const String version = '1.1.0';

  /// Build number - increment with each deployment
  /// This is checked against the server to detect updates
  static const int buildNumber = 3;

  /// Build date - automatically shows users when this version was deployed
  static const String buildDate = '2025-10-20';

  /// Full version string for display
  static String get fullVersion => 'v$version (Build $buildNumber)';

  /// Version info for debug/logs
  static String get versionInfo =>
      'BrownClaw $version (Build $buildNumber) - Built on $buildDate';
}
