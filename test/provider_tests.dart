import 'package:flutter_test/flutter_test.dart';

// Import all provider tests
import 'providers/theme_provider_test.dart' as theme_tests;
import 'providers/favorites_provider_test.dart' as favorites_tests;
import 'providers/user_provider_test.dart' as user_tests;
import 'providers/river_run_provider_test.dart' as river_run_tests;

void main() {
  group('Provider Tests Suite', () {
    theme_tests.main();
    favorites_tests.main();
    user_tests.main();
    river_run_tests.main();
  });
}
