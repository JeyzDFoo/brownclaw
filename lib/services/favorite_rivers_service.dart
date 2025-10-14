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
          final data = doc.data() as Map<String, dynamic>?;
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
      // Add to user's favorites list
      await _firestore.collection('user_favorites').doc(user.uid).set({
        'rivers': FieldValue.arrayUnion([stationId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also store the river details for easy access
      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(stationId)
          .set({
            'stationId': stationId,
            'name': riverData['name'],
            'section': riverData['section'],
            'location': riverData['location'],
            'difficulty': riverData['difficulty'],
            'minRunnable': riverData['minRunnable'],
            'maxSafe': riverData['maxSafe'],
            'addedAt': FieldValue.serverTimestamp(),
          });
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

      final data = doc.data() as Map<String, dynamic>?;
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
}
