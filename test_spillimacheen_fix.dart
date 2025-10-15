import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/live_water_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Test the fixed Spillimacheen data fetching
  await testSpillimacheenFix();
}

Future<void> testSpillimacheenFix() async {
  print('🧪 TESTING SPILLIMACHEEN FIX');
  print('=' * 50);
  print('Expected: ~8.43 m³/s (current data)');
  print('Previous wrong value: 34.8 m³/s (old data)');
  print('');

  try {
    print('🌊 Fetching live data for station 08NA011...');

    final liveData = await LiveWaterDataService.fetchStationData('08NA011');

    if (liveData != null) {
      final flowRate = liveData['flowRate'];
      final timestamp = liveData['lastUpdate'];
      final stationName = liveData['stationName'];

      print('✅ SUCCESS!');
      print('📍 Station: $stationName');
      print('💧 Flow Rate: $flowRate m³/s');
      print('⏰ Timestamp: $timestamp');

      // Check if we got the correct current data
      if (flowRate != null && flowRate > 0 && flowRate < 20) {
        print('🎉 FIXED! Getting current data (~8-9 m³/s range)');
        print('✅ The old 34.8 m³/s value should no longer appear');
      } else if (flowRate != null && flowRate > 30) {
        print('⚠️  Still getting old data (${flowRate} m³/s)');
        print('💡 The JSON API might still be returning outdated values');
      } else {
        print('❓ Unexpected flow rate: $flowRate m³/s');
      }
    } else {
      print('❌ No data returned');
      print('💡 Check network connection and API endpoints');
    }

    // Also test enriched data
    print('');
    print('🔍 Testing enriched station data...');

    final enrichedData = await LiveWaterDataService.getEnrichedStationData(
      '08NA011',
    );

    if (enrichedData != null) {
      final flowRate = enrichedData['flowRate'];
      final status = enrichedData['status'];
      final riverName = enrichedData['riverName'];

      print('✅ Enriched data retrieved:');
      print('🏞️  River: $riverName');
      print('💧 Flow: $flowRate m³/s');
      print('🎯 Status: $status');
    } else {
      print('❌ No enriched data');
    }
  } catch (e) {
    print('💥 Exception: $e');
  }

  print('');
  print('=' * 50);
  print('🚀 Test complete! Check your Flutter app now.');
}
