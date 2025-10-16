import 'package:flutter/foundation.dart';
import '../services/live_water_data_service.dart';

/// Simple test utility to verify direct live data fetching works
class TestLiveDataSimple {
  /// Test fetching live data for a known station
  static Future<void> testDirectFetch() async {
    if (kDebugMode) {
      print('🧪 Testing direct live data fetch...');

      // Test with a known Canadian station
      const testStationId = '08MF005'; // Kicking Horse River

      try {
        print('📡 Fetching data for station: $testStationId');
        final result = await LiveWaterDataService.fetchStationData(
          testStationId,
        );

        if (result != null) {
          print('✅ Station $testStationId data found:');
          print('   Flow Rate: ${result.formattedFlowRate}');
          print('   Water Level: ${result.formattedWaterLevel}');
          print('   Temperature: ${result.temperature}°C');
          print('   Last Updated: ${result.dataAge}');
          print('   Status: ${result.statusText}');
        } else {
          print('❌ No data returned for station $testStationId');
        }
      } catch (e) {
        print('❌ Error fetching data: $e');
      }
    }
  }

  /// Test fetching for multiple stations
  static Future<void> testMultipleStations() async {
    if (kDebugMode) {
      print('🧪 Testing multiple stations...');

      final testStations = [
        '08MF005', // Kicking Horse
        '08GA010', // Bow River
        '02KF005', // Ottawa River
      ];

      for (final stationId in testStations) {
        print('\n📡 Testing station: $stationId');

        try {
          final result = await LiveWaterDataService.fetchStationData(stationId);

          if (result != null) {
            print('✅ $stationId: ${result.formattedFlowRate}');
          } else {
            print('❌ $stationId: No data');
          }
        } catch (e) {
          print('❌ $stationId: Error - $e');
        }

        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
}
