import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a physical gauge station that measures water data
class GaugeStation {
  final String stationId; // e.g., "08MF005" (Environment Canada ID)
  final String name; // Official station name
  final String? riverRunId; // Optional reference to RiverRun if associated
  final double latitude;
  final double longitude;
  final String? agency; // e.g., "Environment Canada", "USGS"
  final String? region; // Province/State
  final String? country;
  final bool isActive;
  final List<String>
  parameters; // e.g., ["discharge", "water_level", "temperature"]
  final String? dataUrl; // URL for live data
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Current live data (cached)
  final double? currentDischarge; // Current flow rate
  final double? currentWaterLevel; // Current water level
  final double? currentTemperature; // Current water temperature
  final DateTime? lastDataUpdate; // When data was last updated
  final String? dataStatus; // "live", "delayed", "unavailable"

  const GaugeStation({
    required this.stationId,
    required this.name,
    this.riverRunId,
    required this.latitude,
    required this.longitude,
    this.agency,
    this.region,
    this.country,
    required this.isActive,
    required this.parameters,
    this.dataUrl,
    this.createdAt,
    this.updatedAt,
    this.currentDischarge,
    this.currentWaterLevel,
    this.currentTemperature,
    this.lastDataUpdate,
    this.dataStatus,
  });

  // Create from Map (for Firestore data)
  factory GaugeStation.fromMap(Map<String, dynamic> map, {String? docId}) {
    return GaugeStation(
      stationId: docId ?? map['stationId'] as String,
      name: map['name'] as String? ?? 'Unknown Station',
      riverRunId: map['riverRunId'] as String?,
      latitude: _safeToDouble(map['latitude']) ?? 0.0,
      longitude: _safeToDouble(map['longitude']) ?? 0.0,
      agency: map['agency'] as String?,
      region: map['region'] as String?,
      country: map['country'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      parameters: (map['parameters'] as List?)?.cast<String>() ?? [],
      dataUrl: map['dataUrl'] as String?,
      createdAt: _timestampToDateTime(map['createdAt']),
      updatedAt: _timestampToDateTime(map['updatedAt']),
      currentDischarge: _safeToDouble(map['currentDischarge']),
      currentWaterLevel: _safeToDouble(map['currentWaterLevel']),
      currentTemperature: _safeToDouble(map['currentTemperature']),
      lastDataUpdate: _timestampToDateTime(map['lastDataUpdate']),
      dataStatus: map['dataStatus'] as String?,
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'stationId': stationId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'parameters': parameters,
    };

    if (riverRunId != null) map['riverRunId'] = riverRunId;
    if (agency != null) map['agency'] = agency;
    if (region != null) map['region'] = region;
    if (country != null) map['country'] = country;
    if (dataUrl != null) map['dataUrl'] = dataUrl;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    if (currentDischarge != null) map['currentDischarge'] = currentDischarge;
    if (currentWaterLevel != null) map['currentWaterLevel'] = currentWaterLevel;
    if (currentTemperature != null) {
      map['currentTemperature'] = currentTemperature;
    }
    if (lastDataUpdate != null) {
      map['lastDataUpdate'] = Timestamp.fromDate(lastDataUpdate!);
    }
    if (dataStatus != null) map['dataStatus'] = dataStatus;

    return map;
  }

  // Helper methods
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

  static DateTime? _timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  // Check if station has live data
  bool get hasLiveData =>
      dataStatus == 'live' &&
      lastDataUpdate != null &&
      DateTime.now().difference(lastDataUpdate!).inHours < 24;

  // Check if station measures discharge
  bool get measuresDischarge => parameters.contains('discharge');

  // Check if station measures water level
  bool get measuresWaterLevel => parameters.contains('water_level');

  // Check if station measures temperature
  bool get measuresTemperature => parameters.contains('temperature');

  // Get display name
  String get displayName => '$name ($stationId)';

  // Create a copy with modified values
  GaugeStation copyWith({
    String? stationId,
    String? name,
    String? riverRunId,
    double? latitude,
    double? longitude,
    String? agency,
    String? region,
    String? country,
    bool? isActive,
    List<String>? parameters,
    String? dataUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentDischarge,
    double? currentWaterLevel,
    double? currentTemperature,
    DateTime? lastDataUpdate,
    String? dataStatus,
  }) {
    return GaugeStation(
      stationId: stationId ?? this.stationId,
      name: name ?? this.name,
      riverRunId: riverRunId ?? this.riverRunId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      agency: agency ?? this.agency,
      region: region ?? this.region,
      country: country ?? this.country,
      isActive: isActive ?? this.isActive,
      parameters: parameters ?? this.parameters,
      dataUrl: dataUrl ?? this.dataUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentDischarge: currentDischarge ?? this.currentDischarge,
      currentWaterLevel: currentWaterLevel ?? this.currentWaterLevel,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      lastDataUpdate: lastDataUpdate ?? this.lastDataUpdate,
      dataStatus: dataStatus ?? this.dataStatus,
    );
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GaugeStation && other.stationId == stationId;
  }

  @override
  int get hashCode => stationId.hashCode;
}
