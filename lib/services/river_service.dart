import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for managing rivers in the new architecture
class RiverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  static CollectionReference get _riversCollection =>
      _firestore.collection('rivers');

  // Get all rivers
  static Stream<List<River>> getAllRivers() {
    return _riversCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return River.fromMap(doc.data() as Map<String, dynamic>, docId: doc.id);
      }).toList();
    });
  }

  // Get river by ID
  static Future<River?> getRiverById(String riverId) async {
    try {
      final doc = await _riversCollection.doc(riverId).get();
      if (doc.exists) {
        return River.fromMap(doc.data() as Map<String, dynamic>, docId: doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting river by ID: $e');
      }
      return null;
    }
  }

  // Search rivers by name
  static Stream<List<River>> searchRivers(String query) {
    if (query.isEmpty) return getAllRivers();

    return _riversCollection
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return River.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Add a new river
  static Future<String> addRiver(River river) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add rivers');
    }

    try {
      final riverData = river.toMap();
      riverData['createdAt'] = FieldValue.serverTimestamp();
      riverData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _riversCollection.add(riverData);

      if (kDebugMode) {
        print('✅ Successfully added river: ${river.name}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding river: $e');
      }
      rethrow;
    }
  }

  // Update a river
  static Future<void> updateRiver(River river) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to update rivers');
    }

    try {
      final riverData = river.toMap();
      riverData['updatedAt'] = FieldValue.serverTimestamp();

      await _riversCollection.doc(river.id).update(riverData);

      if (kDebugMode) {
        print('✅ Successfully updated river: ${river.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating river: $e');
      }
      rethrow;
    }
  }

  // Delete a river (only if no runs exist)
  static Future<void> deleteRiver(String riverId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to delete rivers');
    }

    try {
      // Check if any runs exist for this river
      final runsQuery = await _firestore
          .collection('river_runs')
          .where('riverId', isEqualTo: riverId)
          .limit(1)
          .get();

      if (runsQuery.docs.isNotEmpty) {
        throw Exception('Cannot delete river: River runs exist for this river');
      }

      await _riversCollection.doc(riverId).delete();

      if (kDebugMode) {
        print('✅ Successfully deleted river: $riverId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting river: $e');
      }
      rethrow;
    }
  }

  // Get rivers by region
  static Stream<List<River>> getRiversByRegion(String region) {
    return _riversCollection
        .where('region', isEqualTo: region)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return River.fromMap(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            );
          }).toList();
        });
  }

  // Get all unique regions
  static Future<List<String>> getAllRegions() async {
    try {
      final snapshot = await _riversCollection.get();
      final regions = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final region = data['region'] as String?;
        if (region != null && region.isNotEmpty) {
          regions.add(region);
        }
      }

      final regionList = regions.toList();
      regionList.sort();
      return regionList;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting regions: $e');
      }
      return [];
    }
  }
}
