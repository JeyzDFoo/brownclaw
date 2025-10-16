import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

/// Test setup utilities for provider tests
class TestSetup {
  static bool _initialized = false;

  /// Initialize Firebase for testing
  static Future<void> initializeFirebase() async {
    if (_initialized) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: 'test-project-id',
        ),
      );
      _initialized = true;
    } catch (e) {
      // Firebase already initialized, ignore
      _initialized = true;
    }
  }
}
