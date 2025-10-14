import 'package:cloud_firestore/cloud_firestore.dart';

class WaterStationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _stationsCollection = 'water_stations';

  /// Station model for our database
  static Map<String, dynamic> createStationData({
    required String stationId,
    required String stationName,
    required String province,
    required String riverName,
    required double latitude,
    required double longitude,
    String? operatorName,
    String? stationStatus,
    List<String>? availableParameters,
  }) {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'province': province,
      'riverName': riverName,
      'latitude': latitude,
      'longitude': longitude,
      'operatorName': operatorName ?? 'Environment and Climate Change Canada',
      'stationStatus': stationStatus ?? 'Active',
      'availableParameters': availableParameters ?? ['47'], // 47 = discharge
      'searchTerms': [
        stationName.toLowerCase(),
        riverName.toLowerCase(),
        province.toLowerCase(),
        stationId.toLowerCase(),
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Add a batch of popular Canadian whitewater stations to our database
  static Future<void> seedPopularStations() async {
    final batch = _firestore.batch();

    final popularStations = [
      {
        'stationId': '02KF005',
        'stationName': 'Ottawa River near Ottawa (Masson)',
        'province': 'Ontario',
        'riverName': 'Ottawa River',
        'latitude': 45.5344,
        'longitude': -75.4268,
      },
      {
        'stationId': '02KA006',
        'stationName': 'Madawaska River at Arnprior',
        'province': 'Ontario',
        'riverName': 'Madawaska River',
        'latitude': 45.4383,
        'longitude': -76.3492,
      },
      {
        'stationId': '02ED003',
        'stationName': 'French River near Monetville',
        'province': 'Ontario',
        'riverName': 'French River',
        'latitude': 46.2167,
        'longitude': -80.4167,
      },
      {
        'stationId': '05BH004',
        'stationName': 'Bow River at Calgary',
        'province': 'Alberta',
        'riverName': 'Bow River',
        'latitude': 51.0447,
        'longitude': -114.0719,
      },
      {
        'stationId': '05AD007',
        'stationName': 'Kicking Horse River at Golden',
        'province': 'British Columbia',
        'riverName': 'Kicking Horse River',
        'latitude': 51.2998,
        'longitude': -116.9631,
      },
      {
        'stationId': '05BJ004',
        'stationName': 'Elbow River at Calgary',
        'province': 'Alberta',
        'riverName': 'Elbow River',
        'latitude': 51.0347,
        'longitude': -114.0831,
      },
      {
        'stationId': '02KB001',
        'stationName': 'Petawawa River near Petawawa',
        'province': 'Ontario',
        'riverName': 'Petawawa River',
        'latitude': 45.8833,
        'longitude': -77.2833,
      },
      {
        'stationId': '02KD007',
        'stationName': 'Gatineau River near Maniwaki',
        'province': 'Quebec',
        'riverName': 'Gatineau River',
        'latitude': 46.3833,
        'longitude': -75.9667,
      },
      {
        'stationId': '02KB008',
        'stationName': 'Rouge River at Calumet',
        'province': 'Quebec',
        'riverName': 'Rouge River',
        'latitude': 45.6833,
        'longitude': -74.6167,
      },
      {
        'stationId': '09AB004',
        'stationName': 'Yukon River at Whitehorse',
        'province': 'Yukon',
        'riverName': 'Yukon River',
        'latitude': 60.7211,
        'longitude': -135.0568,
      },
      // Add more popular whitewater stations
      {
        'stationId': '02GC018',
        'stationName': 'Mattawa River near Mattawa',
        'province': 'Ontario',
        'riverName': 'Mattawa River',
        'latitude': 46.3167,
        'longitude': -78.7000,
      },
      {
        'stationId': '02MC002',
        'stationName': 'Magnetawan River near Britt',
        'province': 'Ontario',
        'riverName': 'Magnetawan River',
        'latitude': 45.7833,
        'longitude': -80.6000,
      },
      {
        'stationId': '05DA007',
        'stationName': 'Athabasca River at Jasper',
        'province': 'Alberta',
        'riverName': 'Athabasca River',
        'latitude': 52.8833,
        'longitude': -118.0833,
      },
      {
        'stationId': '08MH016',
        'stationName': 'Fraser River at Mission',
        'province': 'British Columbia',
        'riverName': 'Fraser River',
        'latitude': 49.1333,
        'longitude': -122.3000,
      },
      {
        'stationId': '08NM116',
        'stationName': 'Thompson River at Kamloops',
        'province': 'British Columbia',
        'riverName': 'Thompson River',
        'latitude': 50.6667,
        'longitude': -120.3333,
      },
    ];

    for (final station in popularStations) {
      final docRef = _firestore
          .collection(_stationsCollection)
          .doc(station['stationId'] as String);
      final stationData = createStationData(
        stationId: station['stationId'] as String,
        stationName: station['stationName'] as String,
        province: station['province'] as String,
        riverName: station['riverName'] as String,
        latitude: station['latitude'] as double,
        longitude: station['longitude'] as double,
      );
      batch.set(docRef, stationData);
    }

    await batch.commit();
    print('✅ Seeded ${popularStations.length} popular water stations');
  }

  /// Search stations by name, river, or province
  static Future<List<Map<String, dynamic>>> searchStations(
    String query, {
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      // Return popular stations when no query
      return getPopularStations(limit: limit);
    }

    final lowercaseQuery = query.toLowerCase();

    try {
      // Search using array-contains for search terms
      final querySnapshot = await _firestore
          .collection(_stationsCollection)
          .where('searchTerms', arrayContainsAny: [lowercaseQuery])
          .limit(limit)
          .get();

      final stations = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // If no results with array search, try partial matching
      if (stations.isEmpty) {
        return await _searchStationsPartial(query, limit: limit);
      }

      return stations;
    } catch (e) {
      print('❌ Error searching stations: $e');
      return [];
    }
  }

  /// Partial search as fallback
  static Future<List<Map<String, dynamic>>> _searchStationsPartial(
    String query, {
    int limit = 20,
  }) async {
    final lowercaseQuery = query.toLowerCase();

    final querySnapshot = await _firestore
        .collection(_stationsCollection)
        .limit(50) // Get more to filter locally
        .get();

    final filteredStations = querySnapshot.docs
        .where((doc) {
          final data = doc.data();
          final stationName = (data['stationName'] ?? '')
              .toString()
              .toLowerCase();
          final riverName = (data['riverName'] ?? '').toString().toLowerCase();
          final province = (data['province'] ?? '').toString().toLowerCase();
          final stationId = (data['stationId'] ?? '').toString().toLowerCase();

          return stationName.contains(lowercaseQuery) ||
              riverName.contains(lowercaseQuery) ||
              province.contains(lowercaseQuery) ||
              stationId.contains(lowercaseQuery);
        })
        .take(limit)
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        })
        .toList();

    return filteredStations;
  }

  /// Get popular/featured stations
  static Future<List<Map<String, dynamic>>> getPopularStations({
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_stationsCollection)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting popular stations: $e');
      return [];
    }
  }

  /// Get station by ID
  static Future<Map<String, dynamic>?> getStationById(String stationId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_stationsCollection)
          .doc(stationId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        data['id'] = docSnapshot.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting station by ID: $e');
      return null;
    }
  }

  /// Check if stations database is empty (needs seeding)
  static Future<bool> needsSeeding() async {
    try {
      final querySnapshot = await _firestore
          .collection(_stationsCollection)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('❌ Error checking if seeding needed: $e');
      return true;
    }
  }

  /// Initialize the service (seed if needed)
  static Future<void> initialize() async {
    if (await needsSeeding()) {
      print('🌱 Seeding water stations database...');
      await seedPopularStations();
    } else {
      print('✅ Water stations database already initialized');
    }
  }
}
