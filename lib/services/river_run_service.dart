import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for managing river runs (sections) in the new architecture
class RiverRunService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
      final doc = await _runsCollection.doc(runId).get();
      if (doc.exists) {
        return RiverRun.fromMap(
          doc.data() as Map<String, dynamic>,
          docId: doc.id,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting run by ID: $e');
      }
      return null;
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
              .map(
                (doc) =>
                    (doc.data() as Map<String, dynamic>)['riverRunId']
                        as String?,
              )
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
}
