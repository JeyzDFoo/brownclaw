import 'package:flutter/foundation.dart';
import '../services/live_water_data_service.dart';

/// Debug utility to test live water data fetching
class LiveDataDebugger {
  /// Test the live data service directly
  static Future<void> debugLiveDataService() async {
    if (kDebugMode) {
      print('🐛 Starting LiveWaterDataService debug...');

      // Test known BC stations
      final testStations = [
        '08MF005', // Kicking Horse River (Golden)
        '08NA011', // Spillimacheen River
        '08GA010', // Bow River
      ];

      for (final stationId in testStations) {
        print('\n🧪 Testing station: $stationId');
        print('🧪 Calling LiveWaterDataService.fetchStationData...');

        try {
          final liveData = await LiveWaterDataService.fetchStationData(
            stationId,
          );

          if (liveData != null) {
            print('✅ SUCCESS for $stationId:');
            print('   - Station Name: ${liveData.stationName}');
            print('   - Flow Rate: ${liveData.flowRate} m³/s');
            print('   - Water Level: ${liveData.waterLevel} m');
            print('   - Temperature: ${liveData.temperature}°C');
            print('   - Timestamp: ${liveData.timestamp}');
            print('   - Data Source: ${liveData.dataSource}');
            print('   - Status: ${liveData.status}');
            print('   - Formatted Flow: ${liveData.formattedFlowRate}');
          } else {
            print('❌ NULL returned for station $stationId');
            print('   - This means both CSV and JSON APIs failed');
          }
        } catch (e, stackTrace) {
          print('💥 EXCEPTION for station $stationId:');
          print('   Error: $e');
          print('   Stack: $stackTrace');
        }

        // Small delay between tests
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('\n🐛 LiveWaterDataService debug complete');
    }
  }
}
