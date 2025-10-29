import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/live_water_data_service.dart';

/// Provider for managing live water data with caching, deduplication, and rate limiting
/// This centralizes all live data management and prevents the UI from triggering
/// multiple concurrent requests for the same station.
class LiveWaterDataProvider extends ChangeNotifier {
  // Cache for live water data (stationId -> LiveWaterData)
  final Map<String, LiveWaterData> _liveDataCache = {};

  // Track ongoing requests to prevent duplicates (stationId -> Future)
  final Map<String, Future<LiveWaterData?>> _activeRequests = {};

  // Rate limiting (stationId -> last request time)
  final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _minRequestInterval = Duration(seconds: 30);

  // Track which stations are currently being updated
  final Set<String> _updatingStations = {};

  // Error tracking (stationId -> error message)
  final Map<String, String> _errors = {};

  /// Get cached live data for a station
  LiveWaterData? getLiveData(String stationId) {
    return _liveDataCache[stationId];
  }

  /// Get all cached live data
  Map<String, LiveWaterData> get allLiveData =>
      Map.unmodifiable(_liveDataCache);

  /// Check if a station is currently being updated
  bool isUpdating(String stationId) => _updatingStations.contains(stationId);

  /// Get error for a station (if any)
  String? getError(String stationId) => _errors[stationId];

  /// Check if we should rate limit requests for this station
  bool _shouldRateLimit(String stationId) {
    final lastRequest = _lastRequestTime[stationId];
    if (lastRequest == null) return false;

    final timeSinceLastRequest = DateTime.now().difference(lastRequest);
    return timeSinceLastRequest < _minRequestInterval;
  }

  /// Fetch live data for a single station with deduplication and rate limiting
  Future<LiveWaterData?> fetchStationData(String stationId) async {
    // Check if there's already an active request for this station
    if (_activeRequests.containsKey(stationId)) {
      if (kDebugMode) {
        print('🔄 Reusing existing request for station $stationId');
      }
      return _activeRequests[stationId];
    }

    // Check rate limiting
    if (_shouldRateLimit(stationId)) {
      if (kDebugMode) {
        print(
          '⏰ Rate limited request for station $stationId, returning cached data',
        );
      }
      return _liveDataCache[stationId];
    }

    // Mark station as updating
    _updatingStations.add(stationId);
    _errors.remove(stationId); // Clear any previous errors
    _safeNotifyListeners();

    // Create and store the request future
    final requestFuture = _performStationRequest(stationId);
    _activeRequests[stationId] = requestFuture;

    try {
      final result = await requestFuture;

      if (result != null) {
        _liveDataCache[stationId] = result;
        _errors.remove(stationId);
      } else {
        _errors[stationId] = 'No fresh data available';
      }

      return result;
    } catch (e) {
      _errors[stationId] = e.toString();
      if (kDebugMode) {
        print('❌ Error fetching data for station $stationId: $e');
      }
      return null;
    } finally {
      // Clean up
      _activeRequests.remove(stationId);
      _updatingStations.remove(stationId);
      _lastRequestTime[stationId] = DateTime.now();
      _safeNotifyListeners();
    }
  }

  /// Internal method to perform the actual API request
  Future<LiveWaterData?> _performStationRequest(String stationId) async {
    return await LiveWaterDataService.fetchStationData(stationId);
  }

  /// Fetch live data for multiple stations efficiently
  Future<void> fetchMultipleStations(List<String> stationIds) async {
    if (stationIds.isEmpty) return;

    // Remove duplicates
    final uniqueStationIds = stationIds.toSet().toList();

    // Process in batches to be API-friendly
    const batchSize = 3;
    for (int i = 0; i < uniqueStationIds.length; i += batchSize) {
      final batch = uniqueStationIds.skip(i).take(batchSize);

      // Start all requests in the batch concurrently
      final batchFutures = batch.map(
        (stationId) => fetchStationData(stationId),
      );

      // Wait for the batch to complete
      await Future.wait(batchFutures);

      // Small delay between batches to be API-friendly
      if (i + batchSize < uniqueStationIds.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Clear cached data for a station
  void clearStationData(String stationId) {
    _liveDataCache.remove(stationId);
    _errors.remove(stationId);
    _safeNotifyListeners();
  }

  /// Clear all cached data
  void clearAllData() {
    _liveDataCache.clear();
    _errors.clear();
    _updatingStations.clear();
    _safeNotifyListeners();
  }

  /// Safely notify listeners, deferring if called during build
  void _safeNotifyListeners() {
    // Use a microtask to defer notification until after the current frame
    Future.microtask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Force refresh a station (ignores rate limiting)
  Future<LiveWaterData?> forceRefreshStation(String stationId) async {
    // Remove from rate limiting
    _lastRequestTime.remove(stationId);

    // Clear any active requests
    _activeRequests.remove(stationId);

    // Fetch fresh data
    return await fetchStationData(stationId);
  }

  /// Get summary of current state for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'cached_stations': _liveDataCache.keys.toList(),
      'active_requests': _activeRequests.keys.toList(),
      'updating_stations': _updatingStations.toList(),
      'errors': _errors,
      'cache_size': _liveDataCache.length,
    };
  }
}
