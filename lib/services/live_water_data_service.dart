import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'water_station_service.dart';

class LiveWaterDataService {
  // New Government of Canada API (found Oct 2025)
  static const String baseUrl =
      'https://api.weather.gc.ca/collections/hydrometric-realtime/items';

  // Legacy CSV endpoint (for fallback)
  static const String legacyUrl =
      'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline';

  /// Fetch live data for a specific station
  static Future<Map<String, dynamic>?> fetchStationData(
    String stationId,
  ) async {
    // Try new Government of Canada JSON API first
    final jsonData = await _fetchFromJsonApi(stationId);
    if (jsonData != null) return jsonData;

    // Fallback to legacy CSV API (temporarily disabled)
    // final csvData = await _fetchFromCsvApi(stationId);
    // if (csvData != null) return csvData;

    // Special handling for known stations
    if (stationId == '08NA011') {
      return await _fetchSpecialStation(stationId);
    }

    return null;
  }

  /// Fetch data from new JSON API
  static Future<Map<String, dynamic>?> _fetchFromJsonApi(
    String stationId,
  ) async {
    try {
      final url = '$baseUrl?station_number=$stationId&limit=1';
      if (kDebugMode) {
        print('🌊 Fetching live data for station $stationId');
        print('📡 URL: $url');
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timeout for station $stationId');
            },
          );

      if (kDebugMode) {
        print('📊 Response status: ${response.statusCode}');
        print('📊 Response size: ${response.body.length} chars');
      }

      if (response.statusCode == 200) {
        final csvData = response.body;
        final flowRate = _parseLatestFlow(csvData);

        if (flowRate != null) {
          if (kDebugMode) {
            print('✅ Live data retrieved: ${flowRate}m³/s for $stationId');
          }
          return {
            'flowRate': flowRate,
            'status': 'live',
            'lastUpdate': DateTime.now().toIso8601String(),
          };
        } else {
          if (kDebugMode) {
            print('⚠️ No flow data found in CSV response');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP ${response.statusCode} for station $stationId');
          if (response.body.isNotEmpty) {
            print('💬 Response body: ${response.body.substring(0, 200)}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching live data for station $stationId: $e');
      }
    }

    return null;
  }

  /// Special handling for stations we know should be online
  static Future<Map<String, dynamic>?> _fetchSpecialStation(
    String stationId,
  ) async {
    // Try multiple API formats for known online stations
    final formats = [
      '$baseUrl?stations[]=$stationId&parameters[]=47',
      '$baseUrl?stations=$stationId&parameters=47',
      '$baseUrl?stations[]=$stationId',
      'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?stations[]=$stationId&parameters[]=46', // water level
    ];

    for (int i = 0; i < formats.length; i++) {
      try {
        if (kDebugMode) {
          print('🧪 Trying format ${i + 1} for $stationId: ${formats[i]}');
        }

        final response = await http
            .get(Uri.parse(formats[i]))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final flowRate = _parseLatestFlow(response.body);
          if (flowRate != null) {
            if (kDebugMode) {
              print('✅ Success with format ${i + 1}: ${flowRate}m³/s');
            }
            return {
              'flowRate': flowRate,
              'status': 'live',
              'lastUpdate': DateTime.now().toIso8601String(),
            };
          }
        } else if (kDebugMode) {
          print('❌ Format ${i + 1} failed: HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Format ${i + 1} error: $e');
        }
      }
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
      if (kDebugMode) {
        print('📄 CSV data has ${lines.length} lines');
      }

      // Skip header and find the most recent data point
      for (int i = lines.length - 1; i >= 1; i--) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final parts = line.split(',');
          if (parts.length >= 3) {
            final flowStr = parts[2].trim().replaceAll('"', '');
            if (flowStr.isNotEmpty &&
                flowStr.toLowerCase() != 'no data' &&
                flowStr != '') {
              final flowRate = double.tryParse(flowStr);
              if (flowRate != null && flowRate >= 0) {
                if (kDebugMode) {
                  print('✅ Found flow rate: ${flowRate}m³/s');
                }
                return flowRate;
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('⚠️ No valid flow data found in CSV');
      }
    } catch (e) {
      print('❌ Error parsing CSV data: $e');
    }
    return null;
  }

  /// Parse flow data from JSON API response
  static double? _parseJsonFlow(String jsonData) {
    try {
      final data = json.decode(jsonData);

      if (data['features'] != null && data['features'].isNotEmpty) {
        final features = data['features'] as List;

        // Look through features for discharge data
        for (final feature in features) {
          final props = feature['properties'];
          if (props != null) {
            final discharge = props['DISCHARGE'];
            if (discharge != null) {
              final flowRate = double.tryParse(discharge.toString());
              if (flowRate != null && flowRate >= 0) {
                if (kDebugMode) {
                  print('✅ Found JSON flow rate: ${flowRate}m³/s');
                }
                return flowRate;
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('⚠️ No valid flow data found in JSON response');
        print('Response: ${jsonData.substring(0, 200)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing JSON data: $e');
      }
    }
    return null;
  }

  /// Determine status based on flow rate and typical ranges
  static Map<String, dynamic> determineFlowStatus(
    double flowRate, {
    double? minRunnable,
    double? maxSafe,
  }) {
    // Use realistic whitewater ranges if not provided
    minRunnable ??= _getMinRunnableFlow(flowRate);
    maxSafe ??= _getMaxSafeFlow(flowRate);

    if (flowRate < minRunnable * 0.7) {
      return {'label': 'Too Low', 'color': Colors.red};
    } else if (flowRate < minRunnable) {
      return {'label': 'Low', 'color': Colors.orange};
    } else if (flowRate <= maxSafe) {
      return {'label': 'Good', 'color': Colors.green};
    } else if (flowRate <= maxSafe * 1.5) {
      return {'label': 'High', 'color': Colors.blue};
    } else {
      return {'label': 'Flood', 'color': Colors.red};
    }
  }

  /// Get minimum runnable flow based on river size
  static double _getMinRunnableFlow(double currentFlow) {
    if (currentFlow > 150) {
      return currentFlow * 0.3; // Large rivers
    } else if (currentFlow > 75) {
      return currentFlow * 0.4; // Medium rivers
    } else {
      return currentFlow * 0.5; // Small rivers
    }
  }

  /// Get maximum safe flow based on river size
  static double _getMaxSafeFlow(double currentFlow) {
    if (currentFlow > 150) {
      return currentFlow * 2.0; // Large rivers can handle more flow
    } else if (currentFlow > 75) {
      return currentFlow * 1.8; // Medium rivers
    } else {
      return currentFlow * 1.5; // Small rivers get dangerous quickly
    }
  }

  /// Get enriched station data (database info + live data)
  static Future<Map<String, dynamic>?> getEnrichedStationData(
    String stationId,
  ) async {
    // Get station info from database
    final stationInfo = await WaterStationService.getStationById(stationId);
    if (stationInfo == null) {
      print('⚠️ Station $stationId not found in database');
      return null;
    }

    // Try to get live data
    final liveData = await fetchStationData(stationId);

    // Merge station info with live data
    final enrichedData = Map<String, dynamic>.from(stationInfo);

    if (liveData != null) {
      // We have live data
      enrichedData['flowRate'] = liveData['flowRate'];
      final now = DateTime.now();
      enrichedData['lastUpdate'] = 'Updated ${_formatTime(now)}';
      enrichedData['dataSource'] = 'live';
      enrichedData['isLive'] = true;

      final status = determineFlowStatus(liveData['flowRate'] as double);
      enrichedData['status'] = status['label'];
      enrichedData['statusColor'] = status['color'];

      if (kDebugMode) {
        print(
          '✅ Live data for $stationId: ${liveData['flowRate']}m³/s - ${status['label']}',
        );
      }
    } else {
      // Use realistic demo data based on station and season
      final demoFlow = _generateRealisticFlowData(stationId, stationInfo);
      enrichedData['flowRate'] = demoFlow;
      enrichedData['lastUpdate'] =
          'Simulated data (${_formatTime(DateTime.now())})';
      enrichedData['dataSource'] = 'demo';
      enrichedData['isLive'] = false;

      final status = determineFlowStatus(demoFlow);
      enrichedData['status'] = status['label'];
      enrichedData['statusColor'] = Colors.amber; // Amber for demo data

      if (kDebugMode) {
        print(
          '📊 Demo data for $stationId: ${demoFlow}m³/s - ${status['label']}',
        );
      }
    }
    return enrichedData;
  }

  /// Format time for display
  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Generate realistic flow data based on station characteristics and season
  static double _generateRealisticFlowData(
    String stationId,
    Map<String, dynamic> stationInfo,
  ) {
    final now = DateTime.now();
    final province = stationInfo['province'] as String? ?? '';
    final stationName = (stationInfo['name'] as String? ?? '').toLowerCase();

    // Base flow varies by region and river type
    double baseFlow = 40.0; // Default base flow

    // Adjust base flow by province and river characteristics
    if (province == 'BC') {
      if (stationName.contains('fraser')) {
        baseFlow = 180.0; // Fraser is a major river
      } else if (stationName.contains('thompson')) {
        baseFlow = 120.0;
      } else if (stationName.contains('chilliwack')) {
        baseFlow = 45.0;
      } else if (stationName.contains('spillimacheen')) {
        baseFlow = 12.0; // Spillimacheen River - smaller BC mountain stream
      } else {
        baseFlow = 65.0; // BC mountain rivers
      }
    } else if (province == 'AB') {
      if (stationName.contains('bow')) {
        baseFlow = 85.0; // Bow River
      } else if (stationName.contains('athabasca')) {
        baseFlow = 200.0; // Major river
      } else if (stationName.contains('red deer')) {
        baseFlow = 60.0;
      } else {
        baseFlow = 50.0; // Alberta prairie/mountain rivers
      }
    }

    // Seasonal variation (October is fall runoff season)
    double seasonalMultiplier = 1.0;
    final month = now.month;

    if (month >= 4 && month <= 6) {
      // Spring snowmelt (April-June)
      seasonalMultiplier = 1.8;
    } else if (month >= 7 && month <= 9) {
      // Summer low flows (July-September)
      seasonalMultiplier = 0.7;
    } else if (month >= 10 && month <= 11) {
      // Fall flows (October-November) - current season
      seasonalMultiplier = 1.2;
    } else {
      // Winter low flows (December-March)
      seasonalMultiplier = 0.5;
    }

    // Add daily variation (peak in afternoon, low at night)
    final hour = now.hour;
    double dailyMultiplier = 1.0;
    if (hour >= 6 && hour <= 18) {
      // Daytime higher flows
      dailyMultiplier = 1.1 + (hour - 12).abs() * 0.02;
    } else {
      // Nighttime lower flows
      dailyMultiplier = 0.9;
    }

    // Add some randomness for realism
    final randomVariation =
        0.8 + (now.millisecond % 400) / 1000.0; // 0.8 to 1.2

    final finalFlow =
        baseFlow * seasonalMultiplier * dailyMultiplier * randomVariation;

    // Ensure minimum flow
    return finalFlow < 1.0 ? 1.0 : finalFlow;
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
