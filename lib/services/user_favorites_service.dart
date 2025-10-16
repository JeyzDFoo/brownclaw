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

  // #todo: Add local caching to reduce Firestore reads for favorites
  // static Map<String, List<String>>? _cachedFavoriteRunIds;
  // static String? _cachedUserId;
  // static DateTime? _lastCacheUpdate;
  // static const Duration _cacheTimeout = Duration(minutes: 10);

  // #todo: Add offline support for favorites
  // static bool _isOffline = false;

  // Collection reference
  static CollectionReference get _favoritesCollection =>
      _firestore.collection('user_favorites');

  // Get user's favorite river run IDs
  static Stream<List<String>> getUserFavoriteRunIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // #todo: Check cache first to reduce Firestore reads
    // if (_cachedUserId == user.uid && _isCacheValid()) {
    //   return Stream.value(_cachedFavoriteRunIds![user.uid] ?? []);
    // }

    return _favoritesCollection.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      final data = doc.data() as Map<String, dynamic>?;
      final favoriteRuns = data?['riverRuns'] as List?;
      final result = favoriteRuns?.cast<String>() ?? <String>[];

      // #todo: Cache the result for future use
      // _cachedFavoriteRunIds = {user.uid: result};
      // _cachedUserId = user.uid;
      // _lastCacheUpdate = DateTime.now();

      return result;
    });
  }

  // Get user's favorite station IDs (extracted from runs that have stationId)
  static Stream<List<String>> getUserFavoriteStationIds() {
    return getUserFavoriteRunIds().asyncMap((runIds) async {
      if (runIds.isEmpty) return <String>[];

      // #todo: This makes individual Firestore calls for each run
      // Consider batching these reads or caching run data
      final stationIds = <String>[];
      for (final runId in runIds) {
        final run = await RiverRunService.getRunById(runId);
        if (run?.stationId != null) {
          stationIds.add(run!.stationId!);
        }
      }
      return stationIds;
    });
  }

  // Get user's favorite river runs with details
  static Stream<List<RiverRun>> getUserFavoriteRuns() {
    return getUserFavoriteRunIds().asyncMap((runIds) async {
      if (runIds.isEmpty) return <RiverRun>[];

      final runs = <RiverRun>[];
      for (final runId in runIds) {
        final run = await RiverRunService.getRunById(runId);
        if (run != null) {
          runs.add(run);
        }
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
      // #todo: Implement optimistic updates - update cache immediately
      // then sync to Firestore, rollback on failure

      await _favoritesCollection.doc(user.uid).set({
        'riverRuns': FieldValue.arrayUnion([runId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // #todo: Update cache after successful Firestore write
      // _updateCacheAfterAdd(user.uid, runId);

      if (kDebugMode) {
        print('✅ Successfully added run $runId to favorites');
      }
    } catch (e) {
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

    try {
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
      final doc = await _favoritesCollection.doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      final favoriteRuns = data?['riverRuns'] as List?;
      return favoriteRuns?.contains(runId) ?? false;
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
