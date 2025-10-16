import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'water_station_service.dart';
import '../models/models.dart'; // Import LiveWaterData model

class LiveWaterDataService {
  // Government of Canada Data Mart (reliable CSV source)
  static const String csvBaseUrl = 'https://dd.weather.gc.ca/hydrometric/csv';

  // Government of Canada API (has stale data issues)
  static const String jsonBaseUrl =
      'https://api.weather.gc.ca/collections/hydrometric-realtime/items';

  // #todo: Add local caching for live data to reduce API calls
  // static final Map<String, Map<String, dynamic>> _liveDataCache = {};
  // static final Map<String, DateTime> _cacheTimestamps = {};
  // static const Duration _cacheTimeout = Duration(minutes: 5); // Live data changes frequently

  // #todo: Add rate limiting to prevent API abuse
  // static final Map<String, DateTime> _lastApiCall = {};
  // static const Duration _minApiInterval = Duration(seconds: 30);

  /// Fetch live data for a specific station
  /// Updated to return LiveWaterData for type safety and better data handling
  static Future<LiveWaterData?> fetchStationData(String stationId) async {
    print('🔥 FETCHSTATIONDATA CALLED FOR: $stationId');
    print('🔥 NEW CODE IS RUNNING!');

    // #todo: Check cache first before making API calls
    // if (_isCacheValid(stationId)) {
    //   print('🔥 RETURNING CACHED DATA');
    //   return _liveDataCache[stationId];
    // }

    // #todo: Implement rate limiting to prevent API abuse
    // if (_shouldRateLimit(stationId)) {
    //   print('🔥 RATE LIMITED - returning cached data');
    //   return _liveDataCache[stationId];
    // }

    // Try CSV endpoint first (more reliable)
    print('🔥 Trying CSV first...');
    final csvData = await _fetchFromCsvDataMart(stationId);
    if (csvData != null) {
      print('🔥 CSV SUCCESS: ${csvData.formattedFlowRate}');
      // #todo: Cache the successful result
      // _liveDataCache[stationId] = csvData;
      // _cacheTimestamps[stationId] = DateTime.now();
      return csvData;
    }

    // Fallback to JSON API
    print('🔥 CSV failed, trying JSON...');
    final jsonData = await _fetchFromJsonApi(stationId);
    if (jsonData != null) {
      print('🔥 JSON FALLBACK: ${jsonData.formattedFlowRate}');
      // #todo: Cache the successful result
      // _liveDataCache[stationId] = jsonData;
      // _cacheTimestamps[stationId] = DateTime.now();
      return jsonData;
    }

    print('🔥 NO DATA FOUND');
    return null;
  }

  /// Fetch data from CSV Data Mart (most reliable)
  /// Updated to return LiveWaterData for type safety
  static Future<LiveWaterData?> _fetchFromCsvDataMart(String stationId) async {
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

                  // Create LiveWaterData object from CSV response
                  final rawData = {
                    'flowRate': flowRate,
                    'level': level,
                    'stationName': 'Station $stationId',
                    'status': 'live',
                    'lastUpdate': timestamp,
                  };

                  return LiveWaterData.fromApiResponse(
                    stationId,
                    rawData,
                    'csv',
                  );
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
  /// Updated to return LiveWaterData for type safety
  static Future<LiveWaterData?> _fetchFromJsonApi(String stationId) async {
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

          // Create raw data map for LiveWaterData conversion
          final rawData = {
            'flowRate': flowData['flowRate'],
            'level': flowData['level'],
            'stationName': flowData['stationName'],
            'status': 'live',
            'lastUpdate': DateTime.now().toIso8601String(),
          };

          return LiveWaterData.fromApiResponse(stationId, rawData, 'json');
          // #todo: Replace with LiveWaterData.fromApiResponse(stationId, flowData, 'json')
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
  static Future<Map<String, LiveWaterData>> fetchMultipleStations(
    List<String> stationIds,
  ) async {
    final results = <String, LiveWaterData>{};

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
  /// #todo: Update to return LiveWaterData instead of raw Map
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
      // We have live data - use typed properties
      enrichedData['flowRate'] = liveData.flowRate;
      final now = DateTime.now();
      enrichedData['lastUpdate'] = 'Updated ${_formatTime(now)}';
      enrichedData['dataSource'] = liveData.dataSource;
      enrichedData['isLive'] = liveData.status == LiveDataStatus.live;

      if (liveData.flowRate != null) {
        final status = determineFlowStatus(liveData.flowRate!);
        enrichedData['status'] = status['label'];
        enrichedData['statusColor'] = status['color'];

        if (kDebugMode) {
          print(
            '✅ Live data for $stationId: ${liveData.formattedFlowRate} - ${status['label']}',
          );
        }
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
