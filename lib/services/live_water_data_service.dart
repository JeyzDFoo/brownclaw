import 'dart:convert';
import 'dart:math';
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

  // Request deduplication - prevent multiple requests for same station
  static final Map<String, Future<LiveWaterData?>> _activeRequests = {};

  // Rate limiting - prevent API abuse
  static final Map<String, DateTime> _lastApiCall = {};
  static const Duration _minApiInterval = Duration(seconds: 30);

  // Basic caching for live data to reduce API calls and provide fallback when rate limited
  static final Map<String, LiveWaterData> _liveDataCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(
    minutes: 15,
  ); // Cache for 15 minutes

  /// Fetch live data for a specific station
  /// Updated to return LiveWaterData for type safety and better data handling
  static Future<LiveWaterData?> fetchStationData(String stationId) async {
    // Check for valid cached data first
    final cachedData = _liveDataCache[stationId];
    final cacheTime = _cacheTimestamps[stationId];

    if (cachedData != null && cacheTime != null) {
      final cacheAge = DateTime.now().difference(cacheTime);
      if (cacheAge < _cacheTimeout) {
        if (kDebugMode) {
          print(
            'CACHE_HIT: Returning cached data for $stationId (age: ${cacheAge.inMinutes}m)',
          );
        }
        return cachedData;
      }
    }

    // Check if there's already an active request for this station
    final activeRequest = _activeRequests[stationId];
    if (activeRequest != null) {
      if (kDebugMode) {
        print(
          'DEDUP: Request for station $stationId already in progress, waiting...',
        );
      }
      return await activeRequest;
    }

    // Check rate limiting
    final lastCall = _lastApiCall[stationId];
    if (lastCall != null) {
      final timeSinceLastCall = DateTime.now().difference(lastCall);
      if (timeSinceLastCall < _minApiInterval) {
        if (kDebugMode) {
          print(
            'RATE_LIMIT: Request for station $stationId blocked (last call ${timeSinceLastCall.inSeconds}s ago)',
          );
        }
        // Return cached data if available when rate limited
        if (cachedData != null) {
          if (kDebugMode) {
            print('RATE_LIMIT_FALLBACK: Returning cached data for $stationId');
          }
          return cachedData;
        }
        return null; // No cached data available
      }
    }

    final fetchId = DateTime.now().millisecondsSinceEpoch.toString().substring(
      8,
    );

    // Create and store the request future
    final requestFuture = _performStationRequest(stationId, fetchId);
    _activeRequests[stationId] = requestFuture;

    try {
      final result = await requestFuture;
      _lastApiCall[stationId] = DateTime.now();

      // Cache successful results
      if (result != null) {
        _liveDataCache[stationId] = result;
        _cacheTimestamps[stationId] = DateTime.now();
        if (kDebugMode) {
          print('CACHE_STORE: Cached fresh data for $stationId');
        }
      }

      return result;
    } finally {
      // Clean up the active request
      _activeRequests.remove(stationId);
    }
  }

  /// Internal method to perform the actual API request
  static Future<LiveWaterData?> _performStationRequest(
    String stationId,
    String fetchId,
  ) async {
    if (kDebugMode) {
      print('FETCH [$fetchId] STARTED FOR: $stationId');
    }

    // Try CSV endpoint first (more reliable when data is fresh)
    if (kDebugMode) {
      print('FETCH [$fetchId] Trying CSV first...');
    }
    final csvData = await _fetchFromCsvDataMart(stationId);
    if (csvData != null) {
      // Check if CSV data is fresh (less than 6 hours old)
      final dataAge = DateTime.now().difference(csvData.timestamp);
      if (dataAge.inHours < 6) {
        if (kDebugMode) {
          print(
            '🔥 FETCH [$fetchId] CSV SUCCESS: ${csvData.formattedFlowRate} (${csvData.dataAge}) - SOURCE: CSV',
          );
        }
        return csvData;
      } else {
        if (kDebugMode) {
          print(
            '❌ FETCH [$fetchId] CSV data is stale (${csvData.dataAge}), rejecting...',
          );
        }
      }
    }

    // Try JSON API for fresh data
    if (kDebugMode) {
      print('FETCH [$fetchId] Trying JSON API...');
    }
    final jsonData = await _fetchFromJsonApi(stationId);
    if (jsonData != null) {
      // Check if JSON data is fresh (less than 6 hours old)
      final dataAge = DateTime.now().difference(jsonData.timestamp);
      if (dataAge.inHours < 6) {
        if (kDebugMode) {
          print(
            '🔥 FETCH [$fetchId] JSON SUCCESS: ${jsonData.formattedFlowRate} (${jsonData.dataAge}) - SOURCE: JSON',
          );
        }
        return jsonData;
      } else {
        if (kDebugMode) {
          print(
            '❌ JSON data is also stale (${jsonData.dataAge}), rejecting...',
          );
        }
      }
    }

    // No fresh data available - return null to show error
    if (kDebugMode) {
      print('❌ NO FRESH DATA AVAILABLE - all sources are stale or failed');
    }
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

        if (kDebugMode) {
          print('🔍 CSV Response for $stationId:');
          print('   Total lines: ${lines.length}');
          print('   Last 5 lines:');
          for (int i = max(0, lines.length - 6); i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              print('   [$i]: $line');
            }
          }
        }

        // Find the latest data (last non-empty line)
        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isNotEmpty && !line.startsWith('ID')) {
            final parts = line.split(',');
            if (parts.length >= 7) {
              final timestamp = parts[1];
              final waterLevel = parts[2];
              final discharge = parts[6];

              if (kDebugMode) {
                print('🔍 Parsing line $i:');
                print('   Raw parts: $parts');
                print('   Timestamp: $timestamp');
                print('   Water Level: $waterLevel');
                print('   Discharge: $discharge');
              }

              if (discharge.isNotEmpty &&
                  discharge.toLowerCase() != 'no data') {
                final flowRate = double.tryParse(discharge);
                final level = double.tryParse(waterLevel);

                print(
                  '🔥 RAW CSV DISCHARGE VALUE: "$discharge" for station $stationId',
                );
                print('🔥 PARSED FLOW RATE: $flowRate m³/s');
                print('🔥 TIMESTAMP: $timestamp');

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
            'lastUpdate':
                flowData['datetime'], // Use actual data timestamp, not current time!
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
          final datetime =
              props['DATETIME']; // Extract the actual data timestamp

          if (discharge != null || level != null) {
            return {
              'flowRate': discharge != null
                  ? double.tryParse(discharge.toString())
                  : null,
              'level': level != null ? double.tryParse(level.toString()) : null,
              'stationName': stationName,
              'datetime': datetime, // Return the actual data timestamp
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
