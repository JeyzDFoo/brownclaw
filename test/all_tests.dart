import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'models/river_test.dart' as river_tests;
import 'models/river_run_test.dart' as river_run_tests;
import 'models/gauge_station_test.dart' as gauge_station_tests;
import 'models/river_run_flow_test.dart' as river_run_flow_tests;
import 'services/canadian_water_service_test.dart' as canadian_water_tests;
import 'widgets/main_app_test.dart' as main_app_tests;

// Import existing provider tests
import 'providers/theme_provider_test.dart' as theme_provider_tests;
import 'providers/favorites_provider_test.dart' as favorites_provider_tests;
import 'providers/user_provider_test.dart' as user_provider_tests;
import 'providers/river_run_provider_test.dart' as river_run_provider_tests;

void main() {
  group('🧪 BrownClaw Test Suite', () {
    group('📦 Model Tests', () {
      river_tests.main();
      river_run_tests.main();
      gauge_station_tests.main();
      river_run_flow_tests.main();
    });

    group('🔧 Service Tests', () {
      canadian_water_tests.main();
    });

    group('🎨 Widget Tests', () {
      main_app_tests.main();
    });

    group('🔄 Provider Tests', () {
      theme_provider_tests.main();
      favorites_provider_tests.main();
      user_provider_tests.main();
      river_run_provider_tests.main();
    });
  });
}
