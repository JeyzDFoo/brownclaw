import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'river_run_service.dart';
import 'gauge_station_service.dart';

/// Service for managing user's favorite river runs in the new architecture
class UserFavoritesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local caching to reduce Firestore reads for favorites
  static final Map<String, List<String>> _cachedFavoriteRunIds = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 10);

  // Cache for favorite runs with details
  static final Map<String, List<RiverRun>> _cachedFavoriteRuns = {};
  static final Map<String, DateTime> _runsCacheTimestamps = {};

  // Offline support for favorites
  static bool _isOffline = false;

  /// Check if cache is valid for a given user
  static bool _isCacheValid(String userId, Map<String, DateTime> timestamps) {
    if (!timestamps.containsKey(userId)) return false;
    final age = DateTime.now().difference(timestamps[userId]!);
    return age < _cacheTimeout;
  }

  /// Clear all caches
  static void clearCache() {
    _cachedFavoriteRunIds.clear();
    _cacheTimestamps.clear();
    _cachedFavoriteRuns.clear();
    _runsCacheTimestamps.clear();
  }

  /// Set offline mode
  static void setOfflineMode(bool offline) {
    _isOffline = offline;
  }

  // Collection reference
  static CollectionReference get _favoritesCollection =>
      _firestore.collection('user_favorites');

  // Get user's favorite river run IDs
  static Stream<List<String>> getUserFavoriteRunIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Check cache first to reduce Firestore reads
    if (_cachedFavoriteRunIds.containsKey(user.uid) &&
        _isCacheValid(user.uid, _cacheTimestamps)) {
      // Return cached data as stream, but also listen for updates
      if (!_isOffline) {
        // Start listening for updates in background
        _favoritesCollection.doc(user.uid).snapshots().listen((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            final favoriteRuns = data?['riverRuns'] as List?;
            final result = favoriteRuns?.cast<String>() ?? <String>[];
            _cachedFavoriteRunIds[user.uid] = result;
            _cacheTimestamps[user.uid] = DateTime.now();
          }
        });
      }
      return Stream.value(_cachedFavoriteRunIds[user.uid]!);
    }

    return _favoritesCollection.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      final data = doc.data() as Map<String, dynamic>?;
      final favoriteRuns = data?['riverRuns'] as List?;
      final result = favoriteRuns?.cast<String>() ?? <String>[];

      // Cache the result for future use
      _cachedFavoriteRunIds[user.uid] = result;
      _cacheTimestamps[user.uid] = DateTime.now();

      return result;
    });
  }

  // Get user's favorite station IDs (extracted from runs that have stationId)
  static Stream<List<String>> getUserFavoriteStationIds() {
    return getUserFavoriteRunIds().asyncMap((runIds) async {
      if (runIds.isEmpty) return <String>[];

      // Use batch operations instead of individual Firestore calls
      final runs = await RiverRunService.getRunsBatch(runIds);
      final stationIds = runs
          .where((run) => run.stationId != null)
          .map((run) => run.stationId!)
          .toList();

      return stationIds;
    });
  }

  // Get user's favorite river runs with details
  static Stream<List<RiverRun>> getUserFavoriteRuns() {
    return getUserFavoriteRunIds().asyncMap((runIds) async {
      if (runIds.isEmpty) return <RiverRun>[];

      final user = _auth.currentUser;
      if (user != null) {
        // Check cache first
        if (_cachedFavoriteRuns.containsKey(user.uid) &&
            _isCacheValid(user.uid, _runsCacheTimestamps)) {
          return _cachedFavoriteRuns[user.uid]!;
        }
      }

      // Use batch operations instead of individual calls
      final runs = await RiverRunService.getRunsBatch(runIds);

      // Cache the results
      if (user != null) {
        _cachedFavoriteRuns[user.uid] = runs;
        _runsCacheTimestamps[user.uid] = DateTime.now();
      }

      return runs;
    });
  }

  // Get user's favorite runs with live gauge data
  static Stream<List<FavoriteRunWithGaugeData>>
  getUserFavoritesWithGaugeData() {
    return getUserFavoriteRuns().asyncMap((runs) async {
      final favoritesWithData = <FavoriteRunWithGaugeData>[];

      for (final run in runs) {
        // Find associated gauge station
        final gaugeStation = await GaugeStationService.getStationForRun(run.id);

        favoritesWithData.add(
          FavoriteRunWithGaugeData(run: run, gaugeStation: gaugeStation),
        );
      }

      return favoritesWithData;
    });
  }

  // Add a river run to favorites
  static Future<void> addFavoriteRun(String runId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      // Implement optimistic updates - update cache immediately
      final currentFavorites = _cachedFavoriteRunIds[user.uid] ?? [];
      if (!currentFavorites.contains(runId)) {
        _cachedFavoriteRunIds[user.uid] = [...currentFavorites, runId];
        _cacheTimestamps[user.uid] = DateTime.now();
      }

      // Clear runs cache since it will be stale
      _cachedFavoriteRuns.remove(user.uid);
      _runsCacheTimestamps.remove(user.uid);

      // Then sync to Firestore
      await _favoritesCollection.doc(user.uid).set({
        'riverRuns': FieldValue.arrayUnion([runId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Successfully added run $runId to favorites');
      }
    } catch (e) {
      // Rollback on failure
      if (_cachedFavoriteRunIds.containsKey(user.uid)) {
        _cachedFavoriteRunIds[user.uid] = _cachedFavoriteRunIds[user.uid]!
            .where((id) => id != runId)
            .toList();
      }

      if (kDebugMode) {
        print('❌ Error adding favorite run: $e');
      }
      rethrow;
    }
  }

  // Remove a river run from favorites
  static Future<void> removeFavoriteRun(String runId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to manage favorites');
    }

    // Store original state for rollback
    final originalFavorites = _cachedFavoriteRunIds[user.uid];

    try {
      // Optimistic update - remove from cache immediately
      if (_cachedFavoriteRunIds.containsKey(user.uid)) {
        _cachedFavoriteRunIds[user.uid] = _cachedFavoriteRunIds[user.uid]!
            .where((id) => id != runId)
            .toList();
        _cacheTimestamps[user.uid] = DateTime.now();
      }

      // Clear runs cache since it will be stale
      _cachedFavoriteRuns.remove(user.uid);
      _runsCacheTimestamps.remove(user.uid);

      // Check if document exists first
      final docRef = _favoritesCollection.doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Document doesn't exist, nothing to remove
        if (kDebugMode) {
          print('ℹ️ No favorites document exists for user, nothing to remove');
        }
        return;
      }

      await docRef.update({
        'riverRuns': FieldValue.arrayRemove([runId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Successfully removed run $runId from favorites');
      }
    } catch (e) {
      // Rollback on failure
      if (originalFavorites != null) {
        _cachedFavoriteRunIds[user.uid] = originalFavorites;
      }

      if (kDebugMode) {
        print('❌ Error removing favorite run: $e');
      }
      rethrow;
    }
  }

  // Remove a river run from favorites by station ID
  static Future<void> removeFavoriteByStationId(String stationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      // Find the run ID that corresponds to this station ID
      final runId = await RiverRunService.getRunIdByStationId(stationId);

      if (runId != null) {
        await removeFavoriteRun(runId);
        if (kDebugMode) {
          print('✅ Removed favorite run $runId for station $stationId');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No run found for station $stationId, nothing to remove');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing favorite by station ID: $e');
      }
      rethrow;
    }
  }

  // Check if a run is favorited
  static Future<bool> isRunFavorite(String runId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check cache first
      if (_cachedFavoriteRunIds.containsKey(user.uid) &&
          _isCacheValid(user.uid, _cacheTimestamps)) {
        return _cachedFavoriteRunIds[user.uid]!.contains(runId);
      }

      // Cache miss - fetch from Firestore
      final doc = await _favoritesCollection.doc(user.uid).get();
      if (!doc.exists) {
        _cachedFavoriteRunIds[user.uid] = [];
        _cacheTimestamps[user.uid] = DateTime.now();
        return false;
      }

      final data = doc.data() as Map<String, dynamic>?;
      final favoriteRuns = data?['riverRuns'] as List?;
      final result = favoriteRuns?.cast<String>() ?? <String>[];

      // Cache the result
      _cachedFavoriteRunIds[user.uid] = result;
      _cacheTimestamps[user.uid] = DateTime.now();

      return result.contains(runId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking favorite status: $e');
      }
      return false;
    }
  }

  // Toggle favorite status of a run
  static Future<bool> toggleFavoriteRun(String runId) async {
    final isFavorite = await isRunFavorite(runId);

    if (isFavorite) {
      await removeFavoriteRun(runId);
      return false;
    } else {
      await addFavoriteRun(runId);
      return true;
    }
  }

  // Clear all favorites
  static Future<void> clearAllFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Clear cache immediately (optimistic)
      _cachedFavoriteRunIds[user.uid] = [];
      _cachedFavoriteRuns.remove(user.uid);
      _cacheTimestamps[user.uid] = DateTime.now();
      _runsCacheTimestamps.remove(user.uid);

      await _favoritesCollection.doc(user.uid).delete();

      if (kDebugMode) {
        print('✅ Successfully cleared all favorites');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing favorites: $e');
      }
      rethrow;
    }
  }

  // Get favorite runs count
  static Future<int> getFavoriteRunsCount() async {
    final runIds = await getUserFavoriteRunIds().first;
    return runIds.length;
  }
}

/// Helper class to combine RiverRun with its gauge data
class FavoriteRunWithGaugeData {
  final RiverRun run;
  final GaugeStation? gaugeStation;

  const FavoriteRunWithGaugeData({required this.run, this.gaugeStation});

  // Check if this favorite has live data available
  bool get hasLiveData => gaugeStation?.hasLiveData ?? false;

  // Get current flow status
  String get flowStatus => run.getFlowStatus(gaugeStation?.currentDischarge);

  // Get current flow reading
  double? get currentFlow => gaugeStation?.currentDischarge;

  // Get display name combining run and gauge info
  String get displayName {
    if (gaugeStation != null) {
      return '${run.displayName} • ${gaugeStation!.name}';
    }
    return run.displayName;
  }
}
