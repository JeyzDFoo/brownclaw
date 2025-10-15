import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/live_water_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Test live data fetching
  await testLiveDataFetching();
}

Future<void> testLiveDataFetching() async {
  print('🔍 Testing live data fetching...');

  // Test with a few different station IDs
  final testStations = ['08NA011', '08NB005', '08GA010'];

  for (final stationId in testStations) {
    print('\n🏞️ Testing station: $stationId');

    try {
      final liveData = await LiveWaterDataService.fetchStationData(stationId);

      if (liveData != null) {
        print('✅ Success: $liveData');
      } else {
        print('❌ No data returned for $stationId');
      }
    } catch (e) {
      print('💥 Exception for $stationId: $e');
    }
  }
}
