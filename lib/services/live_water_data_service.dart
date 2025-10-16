import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'water_station_service.dart';
import '../models/models.dart';

/// LiveWaterDataService - Web-Only Implementation
///
/// This service fetches live water data from the Government of Canada's
/// hydrometric API for web deployment only. The app is designed exclusively
/// for web platforms and does not support mobile or desktop platforms.
///
/// Features:
/// - Direct API calls to Government of Canada JSON endpoint
/// - Automatic selection of most recent data from multiple records
/// - Request deduplication and basic caching
/// - Web-optimized with CORS-friendly endpoints
class LiveWaterDataService {
  // Government of Canada JSON API
  static const String jsonBaseUrl =
      'https://api.weather.gc.ca/collections/hydrometric-realtime/items';

  // Request deduplication - prevent multiple requests for same station
  static final Map<String, Future<LiveWaterData?>> _activeRequests = {};
  static final Map<String, LiveWaterData> _liveDataCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(
    minutes: 5,
  ); // Cache for 5 minutes for fresher data

  /// Clear cache for a specific station or all stations
  static void clearCache([String? stationId]) {
    if (stationId != null) {
      _liveDataCache.remove(stationId);
      _cacheTimestamps.remove(stationId);
    } else {
      _liveDataCache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Fetch live data for a specific station (web-only)
  /// Uses the Government of Canada JSON API directly
  static Future<LiveWaterData?> fetchStationData(String stationId) async {
    // Check for valid cached data first
    final cachedData = _liveDataCache[stationId];
    final cacheTime = _cacheTimestamps[stationId];

    if (cachedData != null && cacheTime != null) {
      final cacheAge = DateTime.now().difference(cacheTime);
      if (cacheAge < _cacheTimeout) {
        return cachedData;
      }
    }

    // Check if there's already an active request for this station
    final activeRequest = _activeRequests[stationId];
    if (activeRequest != null) {
      return await activeRequest;
    }

    // Create and execute the request
    final requestFuture = _fetchFromJsonApi(stationId);
    _activeRequests[stationId] = requestFuture;

    try {
      final result = await requestFuture;

      // Cache successful results
      if (result != null) {
        _liveDataCache[stationId] = result;
        _cacheTimestamps[stationId] = DateTime.now();
      }

      return result;
    } finally {
      // Clean up the active request
      _activeRequests.remove(stationId);
    }
  }

  /// Fetch data from JSON API (fallback)
  /// Updated to return LiveWaterData for type safety
  static Future<LiveWaterData?> _fetchFromJsonApi(String stationId) async {
    try {
      final url =
          '$jsonBaseUrl?STATION_NUMBER=$stationId&limit=10&sortby=-DATETIME&f=json';

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timeout for station $stationId');
            },
          );

      if (response.statusCode == 200) {
        final jsonData = response.body;
        final flowData = _parseJsonResponse(jsonData);

        if (flowData != null) {
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
        }
      }
    } catch (e) {
      // Silent error handling for production
    }

    return null;
  }

  /// Fetch live data for multiple stations (web-only)
  static Future<Map<String, LiveWaterData>> fetchMultipleStations(
    List<String> stationIds,
  ) async {
    final results = <String, LiveWaterData>{};

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

        // Sort features by datetime to get the most recent (should be sorted by API but double-check)
        features.sort((a, b) {
          final aTime = a['properties']?['DATETIME'] ?? '';
          final bTime = b['properties']?['DATETIME'] ?? '';
          return bTime.compareTo(aTime); // Descending order (newest first)
        });

        final feature = features[0]; // Get the most recent feature
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
    } catch (e) {
      // Silent error handling for production
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
      }
    } else {
      // No data available
      enrichedData['flowRate'] = 0.0;
      enrichedData['lastUpdate'] = 'Data unavailable';
      enrichedData['dataSource'] = 'unavailable';
      enrichedData['isLive'] = false;
      enrichedData['status'] = 'Unknown';
      enrichedData['statusColor'] = Colors.grey;
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
