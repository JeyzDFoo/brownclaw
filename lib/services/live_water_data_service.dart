import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'water_station_service.dart';

class LiveWaterDataService {
  // Government of Canada Data Mart (reliable CSV source)
  static const String csvBaseUrl = 'https://dd.weather.gc.ca/hydrometric/csv';

  // Government of Canada API (has stale data issues)
  static const String jsonBaseUrl =
      'https://api.weather.gc.ca/collections/hydrometric-realtime/items';

  /// Fetch live data for a specific station
  static Future<Map<String, dynamic>?> fetchStationData(
    String stationId,
  ) async {
    print('🔥 FETCHSTATIONDATA CALLED FOR: $stationId');
    print('🔥 NEW CODE IS RUNNING!');

    // Try CSV endpoint first (more reliable)
    print('🔥 Trying CSV first...');
    final csvData = await _fetchFromCsvDataMart(stationId);
    if (csvData != null) {
      print('🔥 CSV SUCCESS: ${csvData['flowRate']} m³/s');
      return csvData;
    }

    // Fallback to JSON API
    print('🔥 CSV failed, trying JSON...');
    final jsonData = await _fetchFromJsonApi(stationId);
    if (jsonData != null) {
      print('🔥 JSON FALLBACK: ${jsonData['flowRate']} m³/s');
      return jsonData;
    }

    print('🔥 NO DATA FOUND');
    return null;
  }

  /// Fetch data from CSV Data Mart (most reliable)
  static Future<Map<String, dynamic>?> _fetchFromCsvDataMart(
    String stationId,
  ) async {
    try {
      print('🔥 _fetchFromCsvDataMart called for station: $stationId');

      // Determine province from station ID (first 2 digits)
      String province = 'BC'; // Default to BC
      if (stationId.startsWith('02')) {
        province = 'ON'; // Ontario/Quebec
      } else if (stationId.startsWith('05')) {
        province = 'AB'; // Alberta
      } else if (stationId.startsWith('08') || stationId.startsWith('09')) {
        province = 'BC'; // British Columbia
      }

      final csvUrl =
          '$csvBaseUrl/$province/hourly/${province}_${stationId}_hourly_hydrometric.csv';

      // Use CORS proxy for web platform
      final url = kIsWeb ? 'https://corsproxy.io/?$csvUrl' : csvUrl;

      print('🔥 Fetching CSV from: $url');

      if (kDebugMode) {
        print('📊 Fetching CSV data for station $stationId from: $url');
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: kIsWeb ? {'X-Requested-With': 'XMLHttpRequest'} : null,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');

        // Find the latest data (last non-empty line)
        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isNotEmpty && !line.startsWith('ID')) {
            final parts = line.split(',');
            if (parts.length >= 7) {
              final timestamp = parts[1];
              final waterLevel = parts[2];
              final discharge = parts[6];

              if (discharge.isNotEmpty &&
                  discharge.toLowerCase() != 'no data') {
                final flowRate = double.tryParse(discharge);
                final level = double.tryParse(waterLevel);

                print(
                  '🔥 RAW CSV DISCHARGE VALUE: "$discharge" for station $stationId',
                );
                print('🔥 PARSED FLOW RATE: $flowRate m³/s');

                if (flowRate != null) {
                  if (kDebugMode) {
                    print('✅ CSV data: ${flowRate}m³/s at $timestamp');
                  }

                  print(
                    '🔥 RETURNING CSV DATA: flowRate=$flowRate, timestamp=$timestamp',
                  );
                  return {
                    'flowRate': flowRate,
                    'level': level,
                    'stationName': 'Station $stationId',
                    'status': 'live',
                    'lastUpdate': timestamp,
                  };
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ CSV fetch error for $stationId: $e');
      }
    }

    return null;
  }

  /// Fetch data from JSON API (fallback)
  static Future<Map<String, dynamic>?> _fetchFromJsonApi(
    String stationId,
  ) async {
    try {
      final url = '$jsonBaseUrl?STATION_NUMBER=$stationId&limit=1&f=json';
      if (kDebugMode) {
        print('🔄 Trying JSON API for station $stationId');
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
        final jsonData = response.body;
        final flowData = _parseJsonResponse(jsonData);

        if (flowData != null) {
          print(
            '🔥 RETURNING JSON DATA: flowRate=${flowData['flowRate']} for station $stationId',
          );
          if (kDebugMode) {
            print(
              '✅ Live data retrieved: ${flowData['flowRate']}m³/s for $stationId',
            );
          }
          return {
            'flowRate': flowData['flowRate'],
            'level': flowData['level'],
            'stationName': flowData['stationName'],
            'status': 'live',
            'lastUpdate': DateTime.now().toIso8601String(),
          };
        } else {
          if (kDebugMode) {
            print('⚠️ No flow data found in JSON response');
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

  /// Parse complete station data from JSON API response
  static Map<String, dynamic>? _parseJsonResponse(String jsonData) {
    try {
      final data = json.decode(jsonData);

      if (data['features'] != null && data['features'].isNotEmpty) {
        final features = data['features'] as List;
        final feature = features[0]; // Get the first (latest) feature
        final props = feature['properties'];

        if (props != null) {
          final discharge = props['DISCHARGE'];
          final level = props['LEVEL'];
          final stationName = props['STATION_NAME'] ?? 'Unknown Station';

          if (discharge != null || level != null) {
            return {
              'flowRate': discharge != null
                  ? double.tryParse(discharge.toString())
                  : null,
              'level': level != null ? double.tryParse(level.toString()) : null,
              'stationName': stationName,
            };
          }
        }
      }

      if (kDebugMode) {
        print('⚠️ No valid station data found in JSON response');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing JSON response: $e');
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
      // No data available
      enrichedData['flowRate'] = 0.0;
      enrichedData['lastUpdate'] = 'Data unavailable';
      enrichedData['dataSource'] = 'unavailable';
      enrichedData['isLive'] = false;
      enrichedData['status'] = 'Unknown';
      enrichedData['statusColor'] = Colors.grey;

      if (kDebugMode) {
        print('⚠️ No data available for station $stationId');
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
