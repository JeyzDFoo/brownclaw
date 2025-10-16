import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/live_water_data_service.dart';

/// Service for managing gauge stations in the new architecture
class GaugeStationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // #todo: Add static caching for gauge stations to reduce Firestore reads
  // static final Map<String, GaugeStation> _stationCache = {};
  // static final Map<String, List<GaugeStation>> _runStationsCache = {};
  // static DateTime? _lastCacheUpdate;
  // static const Duration _cacheTimeout = Duration(hours: 1);

  // #todo: Add batch operations for multiple station queries
  // static Future<List<GaugeStation>> getStationsBatch(List<String> stationIds)

  // Collection reference
  static CollectionReference get _stationsCollection =>
      _firestore.collection('gauge_stations');

  // Get all active gauge stations
  static Stream<List<GaugeStation>> getActiveStations() {
    return _stationsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get gauge station by ID
  static Future<GaugeStation?> getStationById(String stationId) async {
    try {
      // #todo: Check cache first before making Firestore call
      // if (_stationCache.containsKey(stationId) && _isCacheValid()) {
      //   return _stationCache[stationId];
      // }

      final doc = await _stationsCollection.doc(stationId).get();
      if (doc.exists) {
        final station = GaugeStation.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );

        // #todo: Cache the result for future use
        // _stationCache[stationId] = station;
        // _lastCacheUpdate = DateTime.now();

        return station;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting gauge station by ID: $e');
      }
      return null;
    }
  }

  // Get gauge stations associated with a river run (stream)
  static Stream<List<GaugeStation>> getStationsForRun(String runId) {
    return _stationsCollection
        .where('riverRunId', isEqualTo: runId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get gauge station associated with a river run (single result, backward compatibility)
  static Future<GaugeStation?> getStationForRun(String runId) async {
    try {
      final snapshot = await _stationsCollection
          .where('riverRunId', isEqualTo: runId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return GaugeStation.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          docId: snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting gauge station for run: $e');
      }
      return null;
    }
  }

  // Search gauge stations by name or ID
  static Stream<List<GaugeStation>> searchStations(String query) {
    if (query.isEmpty) return getActiveStations();

    return _stationsCollection
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Add a new gauge station
  static Future<String> addStation(GaugeStation station) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add gauge stations');
    }

    try {
      final stationData = station.toMap();
      stationData['createdAt'] = FieldValue.serverTimestamp();
      stationData['updatedAt'] = FieldValue.serverTimestamp();

      await _stationsCollection.doc(station.stationId).set(stationData);

      if (kDebugMode) {
        print('✅ Successfully added gauge station: ${station.name}');
      }

      return station.stationId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding gauge station: $e');
      }
      rethrow;
    }
  }

  // Update a gauge station
  static Future<void> updateStation(GaugeStation station) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to update gauge stations');
    }

    try {
      final stationData = station.toMap();
      stationData['updatedAt'] = FieldValue.serverTimestamp();

      await _stationsCollection.doc(station.stationId).update(stationData);

      if (kDebugMode) {
        print('✅ Successfully updated gauge station: ${station.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating gauge station: $e');
      }
      rethrow;
    }
  }

  // Update station's live data
  static Future<void> updateStationLiveData(String stationId) async {
    try {
      // Fetch live data from external service
      // #todo: Update to use LiveWaterData instead of Map<String, dynamic>
      final liveData = await LiveWaterDataService.fetchStationData(stationId);

      if (liveData != null) {
        // #todo: Use LiveWaterData.toMap() instead of manual field extraction
        final updateData = <String, dynamic>{
          'currentDischarge': liveData.flowRate,
          'currentWaterLevel': liveData.waterLevel,
          'currentTemperature': liveData.temperature,
          'lastDataUpdate': FieldValue.serverTimestamp(),
          'dataStatus': liveData.status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _stationsCollection.doc(stationId).update(updateData);

        if (kDebugMode) {
          print('✅ Updated live data for station: $stationId');
        }
      } else {
        // Mark as unavailable
        await _stationsCollection.doc(stationId).update({
          'dataStatus': 'unavailable',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('⚠️ No live data available for station: $stationId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating live data for station $stationId: $e');
      }

      // Mark as error
      await _stationsCollection.doc(stationId).update({
        'dataStatus': 'error',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      rethrow;
    }
  }

  // Update all active stations' live data
  static Future<void> updateAllStationsLiveData() async {
    try {
      final snapshot = await _stationsCollection
          .where('isActive', isEqualTo: true)
          .get();

      final futures = <Future>[];

      for (final doc in snapshot.docs) {
        futures.add(updateStationLiveData(doc.id));
      }

      await Future.wait(futures);

      if (kDebugMode) {
        print('✅ Updated live data for ${snapshot.docs.length} stations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating all stations live data: $e');
      }
      rethrow;
    }
  }

  // Get stations by region
  static Stream<List<GaugeStation>> getStationsByRegion(String region) {
    return _stationsCollection
        .where('region', isEqualTo: region)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get stations with live data
  static Stream<List<GaugeStation>> getStationsWithLiveData() {
    return _stationsCollection
        .where('isActive', isEqualTo: true)
        .where('dataStatus', isEqualTo: 'live')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get unassigned stations (not linked to any river run)
  static Stream<List<GaugeStation>> getUnassignedStations() {
    return _stationsCollection
        .where('isActive', isEqualTo: true)
        .where('riverRunId', isNull: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GaugeStation.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Link a gauge station to a river run
  static Future<void> linkStationToRun(String stationId, String runId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to link stations');
    }

    try {
      await _stationsCollection.doc(stationId).update({
        'riverRunId': runId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Successfully linked station $stationId to run $runId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error linking station to run: $e');
      }
      rethrow;
    }
  }

  // Unlink a gauge station from a river run
  static Future<void> unlinkStationFromRun(String stationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to unlink stations');
    }

    try {
      await _stationsCollection.doc(stationId).update({
        'riverRunId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Successfully unlinked station $stationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unlinking station: $e');
      }
      rethrow;
    }
  }

  // Add a river run to a gauge station's associated runs list
  static Future<void> addRunToStation(String stationId, String runId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to link runs to stations');
    }

    try {
      // Get the current station data
      final stationDoc = await _stationsCollection.doc(stationId).get();

      if (!stationDoc.exists) {
        throw Exception('Gauge station not found: $stationId');
      }

      final currentData = stationDoc.data() as Map<String, dynamic>;
      final currentAssociatedRuns =
          (currentData['associatedRiverRunIds'] as List?)?.cast<String>() ??
          <String>[];

      // Add the new run ID if it's not already in the list
      if (!currentAssociatedRuns.contains(runId)) {
        currentAssociatedRuns.add(runId);

        await _stationsCollection.doc(stationId).update({
          'associatedRiverRunIds': currentAssociatedRuns,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('✅ Successfully added run $runId to station $stationId');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Run $runId already associated with station $stationId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding run to station: $e');
      }
      rethrow;
    }
  }

  // Remove a river run from a gauge station's associated runs list
  static Future<void> removeRunFromStation(
    String stationId,
    String runId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        'User must be authenticated to unlink runs from stations',
      );
    }

    try {
      // Get the current station data
      final stationDoc = await _stationsCollection.doc(stationId).get();

      if (!stationDoc.exists) {
        throw Exception('Gauge station not found: $stationId');
      }

      final currentData = stationDoc.data() as Map<String, dynamic>;
      final currentAssociatedRuns =
          (currentData['associatedRiverRunIds'] as List?)?.cast<String>() ??
          <String>[];

      // Remove the run ID if it exists in the list
      if (currentAssociatedRuns.contains(runId)) {
        currentAssociatedRuns.remove(runId);

        await _stationsCollection.doc(stationId).update({
          'associatedRiverRunIds': currentAssociatedRuns,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('✅ Successfully removed run $runId from station $stationId');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Run $runId was not associated with station $stationId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing run from station: $e');
      }
      rethrow;
    }
  }
}
