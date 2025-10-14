import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'water_station_service.dart';

class LiveWaterDataService {
  static const String baseUrl =
      'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline';

  /// Fetch live data for a specific station
  static Future<Map<String, dynamic>?> fetchStationData(
    String stationId,
  ) async {
    // For web platform, return null to indicate no live data available
    if (kIsWeb) {
      return null;
    }

    try {
      final url =
          '$baseUrl?stations[]=$stationId&parameters[]=47'; // Parameter 47 is discharge
      print('🌊 Fetching live data for station $stationId');

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout for station $stationId');
            },
          );

      if (response.statusCode == 200) {
        final csvData = response.body;
        final flowRate = _parseLatestFlow(csvData);

        if (flowRate != null) {
          return {
            'flowRate': flowRate,
            'status': 'live',
            'lastUpdate': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (e) {
      print('❌ Error fetching live data for station $stationId: $e');
    }

    return null;
  }

  /// Fetch live data for multiple stations
  static Future<Map<String, Map<String, dynamic>>> fetchMultipleStations(
    List<String> stationIds,
  ) async {
    final results = <String, Map<String, dynamic>>{};

    // For web, return empty results
    if (kIsWeb) {
      return results;
    }

    // Fetch data for each station
    final futures = stationIds.map((stationId) async {
      final data = await fetchStationData(stationId);
      if (data != null) {
        results[stationId] = data;
      }
    });

    await Future.wait(futures);
    return results;
  }

  /// Parse the latest flow reading from CSV data
  static double? _parseLatestFlow(String csvData) {
    try {
      final lines = csvData.split('\n');

      // Skip header and find the most recent data point
      for (int i = lines.length - 1; i >= 1; i--) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final parts = line.split(',');
          if (parts.length >= 3) {
            final flowStr = parts[2].trim();
            if (flowStr.isNotEmpty && flowStr != 'No Data') {
              return double.tryParse(flowStr);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error parsing CSV data: $e');
    }
    return null;
  }

  /// Determine status based on flow rate and typical ranges
  static Map<String, dynamic> determineFlowStatus(
    double flowRate, {
    double? minRunnable,
    double? maxSafe,
  }) {
    // Default ranges if not provided
    minRunnable ??= flowRate * 0.3; // Assume minimum is 30% of current
    maxSafe ??= flowRate * 3.0; // Assume max safe is 3x current

    if (flowRate < minRunnable * 0.8) {
      return {'label': 'Too Low', 'color': Colors.red};
    } else if (flowRate < minRunnable) {
      return {'label': 'Low', 'color': Colors.orange};
    } else if (flowRate <= minRunnable * 2) {
      return {'label': 'Good', 'color': Colors.green};
    } else if (flowRate <= maxSafe) {
      return {'label': 'High', 'color': Colors.blue};
    } else {
      return {'label': 'Too High', 'color': Colors.red};
    }
  }

  /// Get enriched station data (database info + live data)
  static Future<Map<String, dynamic>?> getEnrichedStationData(
    String stationId,
  ) async {
    // Get station info from database
    final stationInfo = await WaterStationService.getStationById(stationId);
    if (stationInfo == null) {
      return null;
    }

    // Try to get live data
    final liveData = await fetchStationData(stationId);

    // Merge station info with live data
    final enrichedData = Map<String, dynamic>.from(stationInfo);

    if (liveData != null) {
      // We have live data
      enrichedData['flowRate'] = liveData['flowRate'];
      enrichedData['lastUpdate'] = 'Live data';
      enrichedData['dataSource'] = 'live';

      final status = determineFlowStatus(liveData['flowRate'] as double);
      enrichedData['status'] = status['label'];
      enrichedData['statusColor'] = status['color'];
    } else {
      // Use demo data
      final demoFlow =
          50.0 + (DateTime.now().millisecond % 100); // Pseudo-random demo flow
      enrichedData['flowRate'] = demoFlow;
      enrichedData['lastUpdate'] = 'Demo data';
      enrichedData['dataSource'] = 'demo';

      final status = determineFlowStatus(demoFlow);
      enrichedData['status'] = status['label'];
      enrichedData['statusColor'] = Colors.grey; // Grey for demo data
    }

    return enrichedData;
  }

  /// Get enriched data for multiple stations
  static Future<List<Map<String, dynamic>>> getEnrichedStationsData(
    List<String> stationIds,
  ) async {
    final futures = stationIds.map(
      (stationId) => getEnrichedStationData(stationId),
    );
    final results = await Future.wait(futures);

    // Filter out null results
    return results.whereType<Map<String, dynamic>>().toList();
  }
}
