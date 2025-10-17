import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StationModel {
  final String id;
  final String name;
  final String province;
  final double? latitude;
  final double? longitude;
  final double? drainageArea;
  final String status;
  final String dataSource;
  final DateTime updatedAt;
  final bool isWhitewater;

  // Whitewater-specific fields
  final String? section;
  final String? difficulty;
  final double? minRunnable;
  final double? maxSafe;

  StationModel({
    required this.id,
    required this.name,
    required this.province,
    this.latitude,
    this.longitude,
    this.drainageArea,
    required this.status,
    required this.dataSource,
    required this.updatedAt,
    required this.isWhitewater,
    this.section,
    this.difficulty,
    this.minRunnable,
    this.maxSafe,
  });

  factory StationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    if (kDebugMode) {
      print(
        '🐛 StationModel.fromFirestore - doc.id: ${doc.id}, data[\'id\']: ${data['id']}',
      );
    }

    return StationModel(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? 'Unknown Station',
      province:
          (data['province'] == null ||
              data['province'].toString().toLowerCase() == 'null')
          ? 'Unknown'
          : data['province'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      drainageArea: data['drainage_area']?.toDouble(),
      status: data['status'] ?? 'Unknown',
      dataSource: data['data_source'] ?? 'unknown',
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : DateTime.now(),
      isWhitewater: data['is_whitewater'] ?? false,
      section: data['section'],
      difficulty: data['difficulty'],
      minRunnable: data['min_runnable']?.toDouble(),
      maxSafe: data['max_safe']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'drainage_area': drainageArea,
      'status': status,
      'data_source': dataSource,
      'updated_at': updatedAt.toIso8601String(),
      'is_whitewater': isWhitewater,
      'section': section,
      'difficulty': difficulty,
      'min_runnable': minRunnable,
      'max_safe': maxSafe,
    };
  }
}

class FirestoreStationService {
  static const String collectionName = 'water_stations';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern to prevent multiple instances
  static FirestoreStationService? _instance;

  // Static caching for station data to reduce Firestore reads
  static final Map<String, List<StationModel>> _provinceCache = {};
  static final Map<String, StationModel> _stationCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static final Map<String, DateTime> _stationCacheTimestamps = {};
  static final Map<String, Future<List<StationModel>>> _activeQueries = {};
  static const Duration cacheValidityDuration = Duration(
    hours: 1,
  ); // Stations don't change often

  // Pagination support for large station lists
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  FirestoreStationService._internal();

  factory FirestoreStationService() {
    _instance ??= FirestoreStationService._internal();
    return _instance!;
  }

  /// Check if cache entry is valid
  static bool _isCacheValid(String key, Map<String, DateTime> timestamps) {
    if (!timestamps.containsKey(key)) return false;
    final age = DateTime.now().difference(timestamps[key]!);
    return age < cacheValidityDuration;
  }

  /// Get station from individual station cache
  static StationModel? _getStationFromCache(String stationId) {
    if (_stationCache.containsKey(stationId) &&
        _isCacheValid(stationId, _stationCacheTimestamps)) {
      return _stationCache[stationId];
    }
    return null;
  }

  /// Add station to individual station cache
  static void _addStationToCache(String stationId, StationModel station) {
    _stationCache[stationId] = station;
    _stationCacheTimestamps[stationId] = DateTime.now();
  }

  /// Search stations by name with text matching (AB and BC only)
  Future<List<StationModel>> searchStationsByName(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllStations(
          limit: 50,
        ); // Return limited results when no query
      }

      // Get all AB and BC stations (much smaller dataset, no limit needed)
      final albertaStations = await getStationsByProvince('AB');
      final bcStations = await getStationsByProvince('BC');

      // Combine AB and BC stations
      final allWhitewaterStations = [...albertaStations, ...bcStations];

      final stations = allWhitewaterStations
          .where(
            (station) =>
                station.name.toLowerCase().contains(query.toLowerCase()) ||
                station.id.toLowerCase().contains(query.toLowerCase()) ||
                station.province.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      // Sort by relevance (exact matches first, then partial matches)
      stations.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final queryLower = query.toLowerCase();

        // Exact matches first
        if (aName.contains(queryLower) && !bName.contains(queryLower))
          return -1;
        if (!aName.contains(queryLower) && bName.contains(queryLower)) return 1;

        // Then by name alphabetically
        return aName.compareTo(bName);
      });

      return stations;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching stations: $e');
      }
      return [];
    }
  }

  /// Get all stations (AB and BC only, with optional limit and pagination)
  Future<List<StationModel>> getAllStations({int? limit, int page = 1}) async {
    try {
      // Validate pagination parameters
      final effectiveLimit = limit ?? defaultPageSize;
      final safeLimit = effectiveLimit.clamp(1, maxPageSize);
      final safePage = page.clamp(1, 999);

      // Check cache first to avoid redundant Firestore reads
      const cacheKey = 'ALL';
      if (_isCacheValid(cacheKey, _cacheTimestamps) &&
          _provinceCache.containsKey(cacheKey)) {
        final cached = _provinceCache[cacheKey]!;

        // Apply pagination to cached results
        final startIndex = (safePage - 1) * safeLimit;
        if (startIndex >= cached.length) {
          return []; // Page beyond available data
        }

        final endIndex = (startIndex + safeLimit).clamp(0, cached.length);
        return cached.sublist(startIndex, endIndex);
      }

      if (kDebugMode) {
        print(
          'Getting all stations for AB and BC provinces (page: $safePage, limit: $safeLimit)',
        );
      }

      // Fetch provinces individually with error handling for each
      List<StationModel> albertaStations = [];
      List<StationModel> bcStations = [];

      try {
        albertaStations = await getStationsByProvince('AB');
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fetch Alberta stations: $e');
        }
      }

      try {
        bcStations = await getStationsByProvince('BC');
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fetch BC stations: $e');
        }
      }

      // Combine stations
      final allStations = [...albertaStations, ...bcStations];

      // Cache the combined results for future use
      _provinceCache[cacheKey] = allStations;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Also cache individual stations
      for (final station in allStations) {
        _addStationToCache(station.id, station);
      }

      if (kDebugMode) {
        print(
          'Combined ${allStations.length} stations (AB: ${albertaStations.length}, BC: ${bcStations.length})',
        );
      }

      // Apply pagination
      final startIndex = (safePage - 1) * safeLimit;
      if (startIndex >= allStations.length) {
        return []; // Page beyond available data
      }

      final endIndex = (startIndex + safeLimit).clamp(0, allStations.length);
      return allStations.sublist(startIndex, endIndex);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all stations: $e');
      }
      return [];
    }
  }

  /// Batch get stations by IDs (optimized for multiple lookups)
  Future<List<StationModel>> getStationsBatch(List<String> stationIds) async {
    if (stationIds.isEmpty) return [];

    try {
      final results = <StationModel>[];
      final uncachedIds = <String>[];

      // Check cache first
      for (final stationId in stationIds) {
        final cached = _getStationFromCache(stationId);
        if (cached != null) {
          results.add(cached);
        } else {
          uncachedIds.add(stationId);
        }
      }

      if (uncachedIds.isEmpty) {
        if (kDebugMode) {
          print('All ${stationIds.length} stations found in cache');
        }
        return results;
      }

      // Fetch uncached stations in batches (Firestore limit is 10 for whereIn)
      for (int i = 0; i < uncachedIds.length; i += 10) {
        final batchIds = uncachedIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection(collectionName)
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in snapshot.docs) {
          final station = StationModel.fromFirestore(doc);
          results.add(station);
          _addStationToCache(doc.id, station);
        }
      }

      if (kDebugMode) {
        print(
          'Batch fetched ${results.length} stations (${uncachedIds.length} from Firestore, ${stationIds.length - uncachedIds.length} from cache)',
        );
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Error in batch get stations: $e');
      }
      return [];
    }
  }

  /// Clear the cache (useful for refresh functionality)
  void clearCache() {
    _provinceCache.clear();
    _stationCache.clear();
    _cacheTimestamps.clear();
    _stationCacheTimestamps.clear();
    _activeQueries.clear();
    if (kDebugMode) {
      print('Station cache cleared');
    }
  }

  /// Cancel active queries (useful when navigating away quickly)
  void cancelActiveQueries() {
    if (_activeQueries.isNotEmpty) {
      if (kDebugMode) {
        print('Cancelling ${_activeQueries.length} active queries');
      }
      _activeQueries.clear();
    }
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'cached_provinces': _provinceCache.keys.toList(),
      'cache_timestamps': _cacheTimestamps.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'active_queries': _activeQueries.keys.toList(),
      'cache_size': _provinceCache.values.fold<int>(
        0,
        (total, stations) => total + stations.length,
      ),
    };
  }

  /// Get stations by province with caching to prevent repeated queries
  Future<List<StationModel>> getStationsByProvince(String province) async {
    final cacheKey = province.toUpperCase();

    try {
      // Check if there's already an active query for this province
      if (_activeQueries.containsKey(cacheKey)) {
        if (kDebugMode) {
          print('Waiting for active query for province: $province');
        }
        try {
          return await _activeQueries[cacheKey]!;
        } catch (e) {
          if (kDebugMode) {
            print('Active query failed for province $province: $e');
          }
          // Remove the failed query and continue to fallback logic
          _activeQueries.remove(cacheKey);
        }
      }

      // Check cache first
      final cachedTimestamp = _cacheTimestamps[cacheKey];
      final now = DateTime.now();

      if (cachedTimestamp != null &&
          now.difference(cachedTimestamp) < cacheValidityDuration &&
          _provinceCache.containsKey(cacheKey)) {
        if (kDebugMode) {
          print('Returning cached data for province: $province');
        }
        return _provinceCache[cacheKey]!;
      }

      if (kDebugMode) {
        print('Fetching fresh data for province: $province');
      }

      // Create and store the query future
      final queryFuture = _fetchProvinceData(province, cacheKey);
      _activeQueries[cacheKey] = queryFuture;

      try {
        final result = await queryFuture;
        // Clean up the active query on success
        _activeQueries.remove(cacheKey);
        return result;
      } catch (e) {
        // Clean up the active query on error
        _activeQueries.remove(cacheKey);

        if (kDebugMode) {
          print('Query failed for province $province: $e');
        }

        // Fallback to cached data if available
        throw e; // Let the outer catch handle this
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stations by province $province: $e');
        print('Error type: ${e.runtimeType}');
      }

      // Return cached data if available, even if expired
      if (_provinceCache.containsKey(cacheKey)) {
        if (kDebugMode) {
          print(
            'Returning stale cached data due to error for province: $province',
          );
        }
        return _provinceCache[cacheKey]!;
      }

      // If no cached data available, return empty list instead of throwing
      if (kDebugMode) {
        print(
          'No cached data available for province: $province, returning empty list',
        );
      }
      return [];
    }
  }

  Future<List<StationModel>> _fetchProvinceData(
    String province,
    String cacheKey,
  ) async {
    try {
      if (kDebugMode) {
        print('Starting Firestore query for province: $province');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('province', isEqualTo: province.toUpperCase())
          .get()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              if (kDebugMode) {
                print('Query timeout for province: $province');
              }
              throw Exception('Query timeout for province: $province');
            },
          );

      final stations = snapshot.docs
          .map((doc) {
            try {
              return StationModel.fromFirestore(doc);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing document ${doc.id}: $e');
              }
              return null;
            }
          })
          .where((station) => station != null)
          .cast<StationModel>()
          .toList();

      // Update cache only if query was successful
      _provinceCache[cacheKey] = stations;
      _cacheTimestamps[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print(
          'Successfully fetched ${stations.length} stations for province: $province',
        );
      }

      return stations;
    } catch (e) {
      if (kDebugMode) {
        print('Error in _fetchProvinceData for province $province: $e');
        print('Error type: ${e.runtimeType}');
      }

      // Don't update cache on error, let the calling method handle fallback
      rethrow;
    }
  }

  /// Get whitewater stations only
  Future<List<StationModel>> getWhitewaterStations() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('is_whitewater', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => StationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting whitewater stations: $e');
      }
      return [];
    }
  }

  /// Get station by ID
  Future<StationModel?> getStationById(String stationId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(collectionName)
          .doc(stationId)
          .get();

      if (doc.exists) {
        return StationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting station by ID: $e');
      }
      return null;
    }
  }

  /// Get provinces list
  Future<List<String>> getAvailableProvinces() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .get();

      final provinces = snapshot.docs
          .map(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['province'] as String?,
          )
          .where((province) => province != null && province.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      provinces.sort();
      return provinces;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting provinces: $e');
      }
      return [];
    }
  }

  /// Stream stations (for real-time updates)
  Stream<List<StationModel>> streamStations({int? limit}) {
    Query query = _firestore.collection(collectionName);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => StationModel.fromFirestore(doc)).toList(),
    );
  }
}
