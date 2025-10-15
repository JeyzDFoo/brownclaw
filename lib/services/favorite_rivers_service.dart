import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteRiversService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's favorite rivers
  static Stream<List<String>> getUserFavorites() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user_favorites')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <String>[];
          final data = doc.data();
          final favorites = data?['rivers'] as List?;
          return favorites?.cast<String>() ?? <String>[];
        });
  }

  // Add a river to favorites
  static Future<void> addFavorite(
    String stationId,
    Map<String, dynamic> riverData,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Debug: Print the riverData to see what's being passed
      print('🐛 Adding favorite - stationId: $stationId');
      print('🐛 riverData: $riverData');

      // Add to user's favorites list
      await _firestore.collection('user_favorites').doc(user.uid).set({
        'rivers': FieldValue.arrayUnion([stationId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also store the river details for easy access
      final stationData = {
        'stationId': stationId,
        'name': riverData['name'] ?? 'Unknown Station',
        'section':
            riverData['section'] ??
            _extractLocationFromStationId(stationId) ??
            (riverData['province'] != null && riverData['province'] != 'Unknown'
                ? riverData['province']
                : null) ??
            'Unknown Section',
        'location':
            riverData['location'] ??
            _extractLocationFromStationId(stationId) ??
            (riverData['province'] != null && riverData['province'] != 'Unknown'
                ? riverData['province']
                : null) ??
            'Unknown Location',
        'difficulty': riverData['difficulty'] ?? 'Unknown',
        'minRunnable': riverData['minRunnable'] ?? 0.0,
        'maxSafe': riverData['maxSafe'] ?? 1000.0,
        'flow': riverData['flow'] ?? 0.0,
        'status': riverData['status'] ?? 'Unknown',
        'province':
            riverData['province'] ??
            _extractLocationFromStationId(stationId) ??
            'Unknown',
        'addedAt': FieldValue.serverTimestamp(),
      };

      // Debug: Print the final data being stored
      print('🐛 Final stationData being stored: $stationData');

      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(stationId)
          .set(stationData);
    } catch (e) {
      print('❌ Error adding favorite: $e');
      rethrow;
    }
  }

  // Remove a river from favorites
  static Future<void> removeFavorite(String stationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Remove from favorites list
      await _firestore.collection('user_favorites').doc(user.uid).update({
        'rivers': FieldValue.arrayRemove([stationId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Remove river details
      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(stationId)
          .delete();
    } catch (e) {
      print('❌ Error removing favorite: $e');
      rethrow;
    }
  }

  // Check if a river is favorited
  static Future<bool> isFavorite(String stationId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      final favorites = data?['rivers'] as List?;
      return favorites?.contains(stationId) ?? false;
    } catch (e) {
      print('❌ Error checking favorite: $e');
      return false;
    }
  }

  // Get favorite river details
  static Stream<List<Map<String, dynamic>>> getFavoriteRiversDetails() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user_favorites')
        .doc(user.uid)
        .collection('river_details')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Helper method to extract location info from station ID
  static String? _extractLocationFromStationId(String stationId) {
    // Canadian station IDs follow patterns like:
    // 05BH004 (Alberta), 08MF005 (BC), 02KF005 (Ontario/Quebec)
    if (stationId.length >= 7) {
      final prefix = stationId.substring(0, 2);
      switch (prefix) {
        case '01':
        case '02':
          return 'Atlantic Canada';
        case '03':
        case '04':
          return 'Quebec/Ontario';
        case '05':
          return 'Alberta';
        case '06':
        case '07':
          return 'Saskatchewan/Manitoba';
        case '08':
          return 'British Columbia';
        case '09':
        case '10':
          return 'Yukon/Northwest Territories';
      }
    }
    return null;
  }
}
