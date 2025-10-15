import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StationModel {
  final String id;
  final String name;
  final String province;
  final double? latitude;
  final double? longitude;
  final double? drainageArea;
  final String status;
  final String dataSource;
  final DateTime updatedAt;
  final bool isWhitewater;

  // Whitewater-specific fields
  final String? section;
  final String? difficulty;
  final double? minRunnable;
  final double? maxSafe;

  StationModel({
    required this.id,
    required this.name,
    required this.province,
    this.latitude,
    this.longitude,
    this.drainageArea,
    required this.status,
    required this.dataSource,
    required this.updatedAt,
    required this.isWhitewater,
    this.section,
    this.difficulty,
    this.minRunnable,
    this.maxSafe,
  });

  factory StationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return StationModel(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? 'Unknown Station',
      province:
          (data['province'] == null ||
              data['province'].toString().toLowerCase() == 'null')
          ? 'Unknown'
          : data['province'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      drainageArea: data['drainage_area']?.toDouble(),
      status: data['status'] ?? 'Unknown',
      dataSource: data['data_source'] ?? 'unknown',
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : DateTime.now(),
      isWhitewater: data['is_whitewater'] ?? false,
      section: data['section'],
      difficulty: data['difficulty'],
      minRunnable: data['min_runnable']?.toDouble(),
      maxSafe: data['max_safe']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'drainage_area': drainageArea,
      'status': status,
      'data_source': dataSource,
      'updated_at': updatedAt.toIso8601String(),
      'is_whitewater': isWhitewater,
      'section': section,
      'difficulty': difficulty,
      'min_runnable': minRunnable,
      'max_safe': maxSafe,
    };
  }
}

class FirestoreStationService {
  static const String collectionName = 'water_stations';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search stations by name with text matching (AB and BC only)
  Future<List<StationModel>> searchStationsByName(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllStations(
          limit: 50,
        ); // Return limited results when no query
      }

      // Get all AB and BC stations (much smaller dataset, no limit needed)
      final albertaStations = await getStationsByProvince('AB');
      final bcStations = await getStationsByProvince('BC');

      // Combine AB and BC stations
      final allWhitewaterStations = [...albertaStations, ...bcStations];

      final stations = allWhitewaterStations
          .where(
            (station) =>
                station.name.toLowerCase().contains(query.toLowerCase()) ||
                station.id.toLowerCase().contains(query.toLowerCase()) ||
                station.province.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      // Sort by relevance (exact matches first, then partial matches)
      stations.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final queryLower = query.toLowerCase();

        // Exact matches first
        if (aName.contains(queryLower) && !bName.contains(queryLower))
          return -1;
        if (!aName.contains(queryLower) && bName.contains(queryLower)) return 1;

        // Then by name alphabetically
        return aName.compareTo(bName);
      });

      return stations;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching stations: $e');
      }
      return [];
    }
  }

  /// Get all stations (AB and BC only, with optional limit)
  Future<List<StationModel>> getAllStations({int? limit}) async {
    try {
      // Get all AB and BC stations (the most relevant for whitewater)
      final albertaStations = await getStationsByProvince('AB');
      final bcStations = await getStationsByProvince('BC');

      // Combine stations
      final allStations = [...albertaStations, ...bcStations];

      // Apply limit if specified
      if (limit != null && allStations.length > limit) {
        return allStations.take(limit).toList();
      }

      return allStations;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all stations: $e');
      }
      return [];
    }
  }

  /// Get stations by province
  Future<List<StationModel>> getStationsByProvince(String province) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('province', isEqualTo: province)
          .get();

      return snapshot.docs
          .map((doc) => StationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stations by province: $e');
      }
      return [];
    }
  }

  /// Get whitewater stations only
  Future<List<StationModel>> getWhitewaterStations() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('is_whitewater', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => StationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting whitewater stations: $e');
      }
      return [];
    }
  }

  /// Get station by ID
  Future<StationModel?> getStationById(String stationId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(collectionName)
          .doc(stationId)
          .get();

      if (doc.exists) {
        return StationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting station by ID: $e');
      }
      return null;
    }
  }

  /// Get provinces list
  Future<List<String>> getAvailableProvinces() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .get();

      final provinces = snapshot.docs
          .map(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['province'] as String?,
          )
          .where((province) => province != null && province.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      provinces.sort();
      return provinces;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting provinces: $e');
      }
      return [];
    }
  }

  /// Stream stations (for real-time updates)
  Stream<List<StationModel>> streamStations({int? limit}) {
    Query query = _firestore.collection(collectionName);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => StationModel.fromFirestore(doc)).toList(),
    );
  }
}
