import 'package:flutter/foundation.dart';
import '../services/live_water_data_service.dart';
import '../services/gauge_station_service.dart';

/// Utility class for testing and debugging live data functionality
class LiveDataTester {
  /// Test live data for a specific station ID
  static Future<void> testStationLiveData(String stationId) async {
    if (kDebugMode) {
      print('🧪 Testing live data for station: $stationId');
      print('=' * 50);
    }

    try {
      // Test direct API call
      final liveData = await LiveWaterDataService.fetchStationData(stationId);

      if (liveData != null) {
        if (kDebugMode) {
          print('✅ Live data API working:');
          print('   Flow Rate: ${liveData.formattedFlowRate}');
          print('   Water Level: ${liveData.formattedWaterLevel}');
          print('   Station Name: ${liveData.stationName}');
          print('   Status: ${liveData.statusText}');
          print('   Last Update: ${liveData.dataAge}');
        }

        // Test gauge station update
        try {
          await GaugeStationService.updateStationLiveData(stationId);
          if (kDebugMode) {
            print('✅ Gauge station update successful');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Gauge station update failed: $e');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ No live data available for station $stationId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error testing live data: $e');
      }
    }

    if (kDebugMode) {
      print('=' * 50);
    }
  }

  /// Test multiple stations
  static Future<void> testMultipleStations(List<String> stationIds) async {
    if (kDebugMode) {
      print('🧪 Testing ${stationIds.length} stations...');
    }

    for (final stationId in stationIds) {
      await testStationLiveData(stationId);
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting
    }
  }

  /// Test some known working stations
  static Future<void> testKnownStations() async {
    final knownStations = [
      '08NA011', // Spillimacheen River
      '08MF005', // Kicking Horse River
      '02LA002', // Ottawa River
    ];

    await testMultipleStations(knownStations);
  }

  /// Update all gauge stations with live data
  static Future<void> updateAllStationsLiveData() async {
    if (kDebugMode) {
      print('🔄 Updating all active gauge stations...');
    }

    try {
      await GaugeStationService.updateAllStationsLiveData();
      if (kDebugMode) {
        print('✅ All stations updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating all stations: $e');
      }
    }
  }
}
