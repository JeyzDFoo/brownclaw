import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:brownclaw/services/version_checker_service.dart';
import 'package:brownclaw/version.dart';

/// Simple test to debug the version checker
/// Run this to see exactly what's happening with version checking
void main() {
  group('Debug Version Checker', () {
    test('should show current version info', () {
      print('🔍 Debug Version Info:');
      print('   Current Version: ${AppVersion.version}');
      print('   Current Build: ${AppVersion.buildNumber}');
      print('   Build Date: ${AppVersion.buildDate}');
      print('   Full Version: ${AppVersion.fullVersion}');

      expect(AppVersion.buildNumber, 5); // Should be 5 currently
    });

    test('should test version comparison logic', () {
      const currentBuild = 5;

      // Test different scenarios
      print('🧮 Version Comparison Tests:');
      print('   Current build: $currentBuild');
      print(
        '   Build 4 > $currentBuild? ${4 > currentBuild} (should be false)',
      );
      print(
        '   Build 5 > $currentBuild? ${5 > currentBuild} (should be false)',
      );
      print('   Build 6 > $currentBuild? ${6 > currentBuild} (should be true)');
      print('   Build 7 > $currentBuild? ${7 > currentBuild} (should be true)');

      // So if you set Firestore buildNumber to 6 or higher, it should show update
      expect(6 > currentBuild, true);
      expect(5 > currentBuild, false);
    });
  });
}
