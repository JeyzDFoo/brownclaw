import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

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
    if (user == null) {
      if (kDebugMode) {
        print('❌ Cannot add favorite: User not authenticated');
      }
      throw Exception('User not authenticated');
    }

    if (stationId.isEmpty) {
      if (kDebugMode) {
        print('❌ Cannot add favorite: Station ID is empty');
      }
      throw ArgumentError('Station ID cannot be empty');
    }

    // Validate station ID format
    if (stationId.length > 100) {
      if (kDebugMode) {
        print('❌ Cannot add favorite: Station ID too long: $stationId');
      }
      throw ArgumentError('Station ID is too long (max 100 characters)');
    }

    try {
      // Debug: Print the riverData to see what's being passed
      if (kDebugMode) {
        print('🐛 Adding favorite - stationId: $stationId');
        print('🐛 riverData: $riverData');
      }

      // Add to user's favorites list
      if (kDebugMode) {
        print('🔄 Adding station to favorites array...');
      }
      await _firestore.collection('user_favorites').doc(user.uid).set({
        'rivers': FieldValue.arrayUnion([stationId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Successfully added to favorites array');
      }

      // Also store the river details for easy access
      final extractedLocation = _extractLocationFromStationId(stationId);
      final province = riverData['province'] as String?;
      final fallbackLocation = (province != null && province != 'Unknown')
          ? province
          : extractedLocation ?? 'Unknown';

      // Parse station name to extract river name and section
      final stationName = (riverData['name'] as String?)?.isNotEmpty == true
          ? riverData['name'] as String
          : 'Station $stationId';

      // Extract river name from station name (e.g., "Bow River at Calgary" -> "Bow River")
      final riverName = _extractRiverNameFromStation(stationName);
      final sectionName = _extractSectionNameFromStation(stationName);

      if (kDebugMode) {
        print(
          '🐛 Station: "$stationName" -> River: "$riverName", Section: "$sectionName"',
        );
      }

      final stationData = <String, dynamic>{
        'stationId': stationId,
        'name': sectionName, // Use section name, not full station name
        'riverName': riverName, // Store river name separately
        'section': {
          'name': (riverData['section'] is Map)
              ? (riverData['section'] as Map)['name'] ?? sectionName
              : (riverData['section'] as String?)?.isNotEmpty == true
              ? riverData['section']
              : sectionName,
          'class': (riverData['section'] is Map)
              ? (riverData['section'] as Map)['class'] ??
                    riverData['difficulty'] ??
                    'Unknown'
              : riverData['difficulty'] ?? 'Unknown',
        },
        'location': riverData['location'] as String? ?? fallbackLocation,
        'difficulty': riverData['difficulty'] as String? ?? 'Unknown',
        'minRunnable': _safeToDouble(riverData['minRunnable']) ?? 0.0,
        'maxSafe': _safeToDouble(riverData['maxSafe']) ?? 1000.0,
        'flow': _safeToDouble(riverData['flow']) ?? 0.0,
        'status': riverData['status'] as String? ?? 'Unknown',
        'province': province ?? extractedLocation ?? 'Unknown',
        'addedAt': FieldValue.serverTimestamp(),
      };

      // Debug: Print the final data being stored
      if (kDebugMode) {
        print('🐛 Final stationData being stored: $stationData');
        print('🔄 Saving river details...');
      }

      // Sanitize station ID for use as Firestore document ID
      final sanitizedStationId = _sanitizeDocumentId(stationId);

      if (kDebugMode) {
        print('🔄 Original station ID: $stationId');
        print('🔄 Sanitized station ID: $sanitizedStationId');
      }

      // Save the river details
      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(sanitizedStationId)
          .set(stationData);

      if (kDebugMode) {
        print(
          '✅ Successfully added favorite $stationId (saved as $sanitizedStationId)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding favorite: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Station ID: $stationId');
        print('❌ User ID: ${user.uid}');
      }
      rethrow;
    }
  }

  // Add a river station to favorites using RiverStation model
  static Future<void> addFavoriteStation(RiverStation station) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Add to user's favorites list
      await _firestore.collection('user_favorites').doc(user.uid).set({
        'rivers': FieldValue.arrayUnion([station.stationId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Sanitize station ID for use as Firestore document ID
      final sanitizedStationId = _sanitizeDocumentId(station.stationId);

      // Save the river details using the model's toMap method
      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(sanitizedStationId)
          .set(station.toMap());

      if (kDebugMode) {
        print('✅ Successfully added favorite station: ${station.stationId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding favorite station: $e');
      }
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

      // Sanitize station ID for document reference
      final sanitizedStationId = _sanitizeDocumentId(stationId);

      // Remove river details
      await _firestore
          .collection('user_favorites')
          .doc(user.uid)
          .collection('river_details')
          .doc(sanitizedStationId)
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
  static Stream<List<RiverStation>> getFavoriteRiversDetails() {
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
            return RiverStation.fromMap(data);
          }).toList();
        });
  }

  // Keep the old method for backward compatibility (deprecated)
  @Deprecated('Use getFavoriteRiversDetails() instead')
  static Stream<List<Map<String, dynamic>>> getFavoriteRiversDetailsRaw() {
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

  // Helper method to safely convert to double
  static double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
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

  // Helper method to sanitize station ID for use as Firestore document ID
  static String _sanitizeDocumentId(String stationId) {
    // Firestore document IDs cannot contain: / \ . # $ [ ]
    // Replace invalid characters with underscores
    return stationId
        .replaceAll(RegExp(r'[/\\\.#\$\[\]]'), '_')
        .replaceAll(' ', '_')
        .trim();
  }

  // Extract river name from station name
  static String _extractRiverNameFromStation(String stationName) {
    // Common patterns:
    // "Bow River at Calgary" -> "Bow River"
    // "Fraser River near Hope" -> "Fraser River"
    // "Athabasca River below Fort McMurray" -> "Athabasca River"
    // "Red Deer River at Red Deer" -> "Red Deer River"

    // Remove common location prepositions and everything after
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

    // If no preposition found, check for common suffixes to remove
    if (riverName == stationName) {
      // Remove common suffixes like "Station", "Gauge", etc.
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

  // Extract section name from station name
  static String _extractSectionNameFromStation(String stationName) {
    // Common patterns:
    // "Bow River at Calgary" -> "Calgary"
    // "Fraser River near Hope" -> "Hope"
    // "Athabasca River below Fort McMurray" -> "Fort McMurray"

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

    // If no clear section found, return "Main" as default
    return 'Main';
  }
}
