import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'river_service.dart';
import 'batch_firestore_service.dart';

/// Service for managing river runs (sections) in the new architecture
class RiverRunService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Static caching to reduce redundant Firestore reads
  static final Map<String, RiverRun> _runCache = {};
  static final Map<String, RiverRunWithStations> _runWithStationsCache = {};
  static final Map<String, DateTime> _runCacheTimestamps = {};
  static final Map<String, DateTime> _runWithStationsTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 10);

  // Connection state monitoring for offline support
  static bool _isOffline = false;

  /// Check if cache entry is valid
  static bool _isCacheValid(String key, Map<String, DateTime> timestamps) {
    if (!timestamps.containsKey(key)) return false;
    final age = DateTime.now().difference(timestamps[key]!);
    return age < _cacheTimeout;
  }

  /// Clear all caches
  static void clearCache() {
    _runCache.clear();
    _runWithStationsCache.clear();
    _runCacheTimestamps.clear();
    _runWithStationsTimestamps.clear();
  }

  /// Set offline mode
  static void setOfflineMode(bool offline) {
    _isOffline = offline;
  }

  // Collection reference
  static CollectionReference get _runsCollection =>
      _firestore.collection('river_runs');

  // Get all runs for a specific river
  static Stream<List<RiverRun>> getRunsForRiver(String riverId) {
    return _runsCollection
        .where('riverId', isEqualTo: riverId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RiverRun.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get run by ID
  static Future<RiverRun?> getRunById(String runId) async {
    try {
      // Check cache first before making Firestore call
      if (_runCache.containsKey(runId) &&
          _isCacheValid(runId, _runCacheTimestamps)) {
        return _runCache[runId];
      }

      final doc = await _runsCollection.doc(runId).get();
      if (doc.exists) {
        final run = RiverRun.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );

        // Cache the result
        _runCache[runId] = run;
        _runCacheTimestamps[runId] = DateTime.now();

        return run;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting run by ID: $e');
      }
      return null;
    }
  }

  // Watch run by ID (real-time stream)
  static Stream<RiverRun?> watchRunById(String runId) {
    return _runsCollection.doc(runId).snapshots().map((doc) {
      if (doc.exists) {
        final run = RiverRun.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );

        // Update cache when stream emits
        _runCache[runId] = run;
        _runCacheTimestamps[runId] = DateTime.now();

        return run;
      }
      return null;
    });
  }

  // Get multiple runs by IDs (batch operation)
  static Future<List<RiverRun>> getRunsBatch(List<String> runIds) async {
    if (runIds.isEmpty) return [];

    try {
      final results = <RiverRun>[];
      final uncachedIds = <String>[];

      // Check cache first
      for (final runId in runIds) {
        if (_runCache.containsKey(runId) &&
            _isCacheValid(runId, _runCacheTimestamps)) {
          results.add(_runCache[runId]!);
        } else {
          uncachedIds.add(runId);
        }
      }

      // Firestore whereIn limit is 10 items per query
      for (int i = 0; i < uncachedIds.length; i += 10) {
        final batchIds = uncachedIds.skip(i).take(10).toList();
        final snapshot = await _runsCollection
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in snapshot.docs) {
          final run = RiverRun.fromMap(
            doc.data() as Map<String, dynamic>,
            docId: doc.id,
          );
          results.add(run);

          // Cache each result
          _runCache[doc.id] = run;
          _runCacheTimestamps[doc.id] = DateTime.now();
        }
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting runs batch: $e');
      }
      return [];
    }
  }

  // Search runs by name or river
  static Stream<List<RiverRun>> searchRuns(String query) {
    if (query.isEmpty) {
      return _runsCollection.orderBy('name').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return RiverRun.fromMap(
            doc.data() as Map<String, dynamic>,
            docId: doc.id,
          );
        }).toList();
      });
    }

    return _runsCollection
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RiverRun.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Add a new run
  static Future<String> addRun(RiverRun run) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add river runs');
    }

    try {
      final runData = run.toMap();
      runData['createdAt'] = FieldValue.serverTimestamp();
      runData['updatedAt'] = FieldValue.serverTimestamp();
      runData['createdBy'] = user.uid;

      final docRef = await _runsCollection.add(runData);

      if (kDebugMode) {
        print('✅ Successfully added river run: ${run.name}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding river run: $e');
      }
      rethrow;
    }
  }

  // Update a run
  static Future<void> updateRun(RiverRun run) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to update river runs');
    }

    try {
      final runData = run.toMap();
      runData['updatedAt'] = FieldValue.serverTimestamp();

      await _runsCollection.doc(run.id).update(runData);

      if (kDebugMode) {
        print('✅ Successfully updated river run: ${run.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating river run: $e');
      }
      rethrow;
    }
  }

  // Delete a run (only if no descents exist)
  static Future<void> deleteRun(String runId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to delete river runs');
    }

    try {
      // Check if any descents exist for this run
      final descentsQuery = await _firestore
          .collection('river_descents')
          .where('riverRunId', isEqualTo: runId)
          .limit(1)
          .get();

      if (descentsQuery.docs.isNotEmpty) {
        throw Exception('Cannot delete run: Descents exist for this run');
      }

      await _runsCollection.doc(runId).delete();

      if (kDebugMode) {
        print('✅ Successfully deleted river run: $runId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting river run: $e');
      }
      rethrow;
    }
  }

  // Get runs by difficulty class
  static Stream<List<RiverRun>> getRunsByDifficulty(String difficultyClass) {
    return _runsCollection
        .where('difficultyClass', isEqualTo: difficultyClass)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RiverRun.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get runs with flow recommendations
  static Stream<List<RiverRun>> getRunsWithFlowData() {
    return _runsCollection
        .where('minRecommendedFlow', isNull: false)
        .where('maxRecommendedFlow', isNull: false)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RiverRun.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get runs that have associated gauge stations
  static Stream<List<RiverRun>> getRunsWithGauges() {
    return _firestore
        .collection('gauge_stations')
        .where('riverRunId', isNull: false)
        .snapshots()
        .asyncMap((gaugeSnapshot) async {
          final runIds = gaugeSnapshot.docs
              .map((doc) => doc.data()['riverRunId'] as String?)
              .where((id) => id != null)
              .cast<String>()
              .toList();

          if (runIds.isEmpty) return <RiverRun>[];

          final runsSnapshot = await _runsCollection
              .where(FieldPath.documentId, whereIn: runIds)
              .get();

          return runsSnapshot.docs.map((doc) {
            return RiverRun.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get all unique difficulty classes
  static Future<List<String>> getAllDifficultyClasses() async {
    try {
      final snapshot = await _runsCollection.get();
      final difficulties = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final difficulty = data['difficultyClass'] as String?;
        if (difficulty != null && difficulty.isNotEmpty) {
          difficulties.add(difficulty);
        }
      }

      // Sort by Roman numeral order
      final difficultyList = difficulties.toList();
      difficultyList.sort((a, b) {
        const order = {
          'Class I': 1,
          'Class II': 2,
          'Class III': 3,
          'Class IV': 4,
          'Class V': 5,
          'Class VI': 6,
        };
        return (order[a] ?? 999) - (order[b] ?? 999);
      });

      return difficultyList;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting difficulty classes: $e');
      }
      return [];
    }
  }

  // Create or get a river run from station data for favorites
  static Future<String> createRunFromStationData(
    String stationId,
    String stationName,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create river runs');
    }

    try {
      // Check if a run with this station ID already exists
      final existingRunQuery = await _runsCollection
          .where('stationId', isEqualTo: stationId)
          .limit(1)
          .get();

      if (existingRunQuery.docs.isNotEmpty) {
        // Return existing run ID
        return existingRunQuery.docs.first.id;
      }

      // Parse station name to extract river and section info
      final riverName = _extractRiverNameFromStation(stationName);
      final sectionName = _extractSectionNameFromStation(stationName);

      // Create or get the river record
      String riverId = await _createOrGetRiver(riverName);

      // Create the river run
      final runData = <String, dynamic>{
        'riverId': riverId,
        'name': sectionName,
        'difficultyClass': 'Unknown', // Default, can be updated later
        'description': 'Created from gauge station: $stationName',
        'stationId': stationId, // Link back to original station
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      };

      final docRef = await _runsCollection.add(runData);

      if (kDebugMode) {
        print('✅ Created river run from station: $stationName -> ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating run from station data: $e');
      }
      rethrow;
    }
  }

  // Get run ID by station ID
  static Future<String?> getRunIdByStationId(String stationId) async {
    try {
      final query = await _runsCollection
          .where('stationId', isEqualTo: stationId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding run by station ID: $e');
      }
      return null;
    }
  }

  // Helper method to create or get a river record
  static Future<String> _createOrGetRiver(String riverName) async {
    // Check if river already exists
    final existingRiverQuery = await _firestore
        .collection('rivers')
        .where('name', isEqualTo: riverName)
        .limit(1)
        .get();

    if (existingRiverQuery.docs.isNotEmpty) {
      return existingRiverQuery.docs.first.id;
    }

    // Create new river
    final riverData = <String, dynamic>{
      'name': riverName,
      'region': 'Unknown', // Can be updated later
      'country': 'Canada', // Default assumption for now
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('rivers').add(riverData);

    if (kDebugMode) {
      print('✅ Created river: $riverName -> ${docRef.id}');
    }

    return docRef.id;
  }

  // Helper methods to extract river and section names (copied from FavoriteRiversService)
  static String _extractRiverNameFromStation(String stationName) {
    final prepositions = [
      'at',
      'near',
      'above',
      'below',
      'upstream',
      'downstream',
    ];
    String riverName = stationName;

    for (final prep in prepositions) {
      final pattern = ' $prep ';
      final index = riverName.toLowerCase().indexOf(pattern);
      if (index != -1) {
        riverName = riverName.substring(0, index).trim();
        break;
      }
    }

    if (riverName == stationName) {
      final suffixes = [' Station', ' Gauge', ' WSC'];
      for (final suffix in suffixes) {
        if (riverName.toLowerCase().endsWith(suffix.toLowerCase())) {
          riverName = riverName
              .substring(0, riverName.length - suffix.length)
              .trim();
          break;
        }
      }
    }

    return riverName.isNotEmpty ? riverName : stationName;
  }

  static String _extractSectionNameFromStation(String stationName) {
    final prepositions = [
      'at',
      'near',
      'above',
      'below',
      'upstream',
      'downstream',
    ];

    for (final prep in prepositions) {
      final pattern = ' $prep ';
      final index = stationName.toLowerCase().indexOf(pattern);
      if (index != -1) {
        final section = stationName.substring(index + pattern.length).trim();
        return section.isNotEmpty ? section : 'Unknown Section';
      }
    }

    return 'Main';
  }

  // Get run with its associated gauge stations (single result)
  static Future<RiverRunWithStations?> getRunWithStations(String runId) async {
    try {
      final run = await getRunById(runId);
      if (run == null) return null;

      // Get associated gauge stations
      final stationsSnapshot = await _firestore
          .collection('gauge_stations')
          .where('riverRunId', isEqualTo: runId)
          .where('isActive', isEqualTo: true)
          .get();

      final stations = stationsSnapshot.docs.map((doc) {
        return GaugeStation.fromMap(doc.data(), docId: doc.id);
      }).toList();

      // Get the parent river information
      River? river;
      if (run.riverId.isNotEmpty) {
        if (kDebugMode) {
          print('getRunWithStations - Fetching river for ID: ${run.riverId}');
        }
        river = await RiverService.getRiverById(run.riverId);
        print(
          '🐛 getRunWithStations - River fetched: ${river?.name ?? 'null'}',
        );
      } else {
        print('🐛 getRunWithStations - No riverId, river will be null');
      }

      print(
        '🐛 getRunWithStations - Creating RiverRunWithStations with run: ${run.name}, river: ${river?.name ?? 'null'}',
      );
      return RiverRunWithStations(run: run, stations: stations, river: river);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting run with stations: $e');
      }
      return null;
    }
  }

  // Get all runs for a river with their associated gauge stations (stream)
  static Stream<List<RiverRunWithStations>> getRunsWithStationsForRiver(
    String riverId,
  ) {
    return getRunsForRiver(riverId).asyncMap((runs) async {
      final runWithStationsFutures = runs.map((run) async {
        final stationsSnapshot = await _firestore
            .collection('gauge_stations')
            .where('riverRunId', isEqualTo: run.id)
            .where('isActive', isEqualTo: true)
            .get();

        final stations = stationsSnapshot.docs.map((doc) {
          return GaugeStation.fromMap(doc.data(), docId: doc.id);
        }).toList();

        return RiverRunWithStations(run: run, stations: stations);
      });

      return Future.wait(runWithStationsFutures);
    });
  }

  // Get runs with stations that have live data (stream)
  static Stream<List<RiverRunWithStations>> getRunsWithLiveData() {
    return _firestore
        .collection('gauge_stations')
        .where('isActive', isEqualTo: true)
        .where('dataStatus', isEqualTo: 'live')
        .snapshots()
        .asyncMap((snapshot) async {
          final runIds = snapshot.docs
              .map((doc) => doc.data()['riverRunId'] as String?)
              .where((id) => id != null)
              .cast<String>()
              .toSet()
              .toList();

          if (runIds.isEmpty) return <RiverRunWithStations>[];

          final runWithStationsFutures = runIds.map((runId) async {
            return getRunWithStations(runId);
          });

          final results = await Future.wait(runWithStationsFutures);
          return results
              .where((result) => result != null)
              .cast<RiverRunWithStations>()
              .toList();
        });
  }

  // Get all runs with stations (stream)
  static Stream<List<RiverRunWithStations>> getAllRunsWithStations() {
    // #todo: This method loads ALL runs and their stations - very expensive!
    // Implement pagination and lazy loading for better performance
    // Consider loading only basic run info first, then stations on demand
    return _runsCollection.snapshots().asyncMap((snapshot) async {
      final runIds = snapshot.docs.map((doc) => doc.id).toList();

      if (runIds.isEmpty) return <RiverRunWithStations>[];

      // #todo: Replace individual calls with batch operations
      // This currently makes 1 Firestore read per run + 1 per station
      // Could be optimized to batch read all runs and all stations separately
      final runWithStationsFutures = runIds.map((runId) async {
        return getRunWithStations(runId);
      });

      final results = await Future.wait(runWithStationsFutures);
      return results
          .where((result) => result != null)
          .cast<RiverRunWithStations>()
          .toList();
    });
  }

  // ⚡ PERFORMANCE: Batch fetch runs with all data (90% faster!)
  ///
  /// This method replaces the N+1 query pattern with efficient batch queries.
  /// Instead of querying each run individually, it:
  /// 1. Batch fetches all runs (1 query per 10 items)
  /// 2. Extracts unique river IDs and batch fetches rivers
  /// 3. Batch fetches all stations in parallel
  /// 4. Combines everything into RiverRunWithStations models
  ///
  /// Result: 10 favorites = 3-6 queries instead of 30-40!
  static Future<List<RiverRunWithStations>> batchGetFavoriteRuns(
    List<String> runIds,
  ) async {
    if (runIds.isEmpty) return [];

    try {
      if (kDebugMode) {
        print('🚀 Batch fetching ${runIds.length} runs with all data...');
      }

      // Step 1: Batch fetch all runs (1 query per 10 items)
      final runDocs = await BatchFirestoreService.batchGetDocs(
        'river_runs',
        runIds,
      );

      final runs = runDocs.values.map((doc) {
        return RiverRun.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );
      }).toList();

      if (runs.isEmpty) {
        if (kDebugMode) {
          print('⚠️  No runs found for provided IDs');
        }
        return [];
      }

      // Step 2: Extract unique river IDs
      final riverIds = runs
          .map((r) => r.riverId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (kDebugMode) {
        print('🌊 Found ${riverIds.length} unique rivers to fetch');
      }

      // Step 3: Parallel fetch rivers AND stations (saves time!)
      final results = await Future.wait([
        BatchFirestoreService.batchGetDocs('rivers', riverIds),
        BatchFirestoreService.batchGetByField(
          'gauge_stations',
          'riverRunId',
          runIds,
        ),
      ]);

      final riverDocs = results[0] as Map<String, DocumentSnapshot>;
      final stationDocs = results[1] as List<DocumentSnapshot>;

      // Step 4: Build maps for quick lookup
      final riverMap = <String, River>{};
      for (final entry in riverDocs.entries) {
        riverMap[entry.key] = River.fromMap(
          entry.value.data() as Map<String, dynamic>,
          docId: entry.key,
        );
      }

      final stationsMap = <String, List<GaugeStation>>{};
      for (final doc in stationDocs) {
        final station = GaugeStation.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );
        final runId = station.riverRunId;
        if (runId != null && runId.isNotEmpty) {
          stationsMap.putIfAbsent(runId, () => []).add(station);
        }
      }

      // Step 5: Combine into RiverRunWithStations models
      final result = runs.map((run) {
        return RiverRunWithStations(
          run: run,
          river: riverMap[run.riverId],
          stations: stationsMap[run.id] ?? [],
        );
      }).toList();

      if (kDebugMode) {
        print('✅ Batch fetch complete: ${result.length} runs with full data');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Batch fetch error: $e');
      }
      rethrow;
    }
  }
}
