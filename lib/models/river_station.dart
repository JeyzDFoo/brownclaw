import 'package:cloud_firestore/cloud_firestore.dart';
import 'river_section.dart';

class RiverStation {
  final String stationId;
  final String name;
  final RiverSection section;
  final String location;
  final String difficulty;
  final double minRunnable;
  final double maxSafe;
  final double flow;
  final String status;
  final String province;
  final DateTime? addedAt;

  // Live data fields
  final double? flowRate;
  final double? waterLevel;
  final double? temperature;
  final String? lastUpdated;
  final String? dataSource;
  final bool? isLive;

  const RiverStation({
    required this.stationId,
    required this.name,
    required this.section,
    required this.location,
    required this.difficulty,
    required this.minRunnable,
    required this.maxSafe,
    required this.flow,
    required this.status,
    required this.province,
    this.addedAt,
    this.flowRate,
    this.waterLevel,
    this.temperature,
    this.lastUpdated,
    this.dataSource,
    this.isLive,
  });

  // Create from Map (for Firestore data)
  factory RiverStation.fromMap(Map<String, dynamic> map) {
    final sectionData = map['section'];
    RiverSection section;

    if (sectionData is Map<String, dynamic>) {
      section = RiverSection.fromMap(sectionData);
    } else if (sectionData is String) {
      // Handle legacy string format
      section = RiverSection.fromString(
        sectionData,
        map['difficulty'] as String?,
      );
    } else {
      section = RiverSection.empty();
    }

    return RiverStation(
      stationId: map['stationId'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Station',
      section: section,
      location: map['location'] as String? ?? 'Unknown Location',
      difficulty: map['difficulty'] as String? ?? 'Unknown',
      minRunnable: _safeToDouble(map['minRunnable']) ?? 0.0,
      maxSafe: _safeToDouble(map['maxSafe']) ?? 1000.0,
      flow: _safeToDouble(map['flow']) ?? 0.0,
      status: map['status'] as String? ?? 'Unknown',
      province: map['province'] as String? ?? 'Unknown',
      addedAt: _timestampToDateTime(map['addedAt']),
      flowRate: _safeToDouble(map['flowRate']),
      waterLevel: _safeToDouble(map['waterLevel']),
      temperature: _safeToDouble(map['temperature']),
      lastUpdated: map['lastUpdated'] as String?,
      dataSource: map['dataSource'] as String?,
      isLive: map['isLive'] as bool?,
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'stationId': stationId,
      'name': name,
      'section': section.toMap(),
      'location': location,
      'difficulty': difficulty,
      'minRunnable': minRunnable,
      'maxSafe': maxSafe,
      'flow': flow,
      'status': status,
      'province': province,
    };

    if (addedAt != null) {
      map['addedAt'] = Timestamp.fromDate(addedAt!);
    }

    // Add live data if available
    if (flowRate != null) map['flowRate'] = flowRate;
    if (waterLevel != null) map['waterLevel'] = waterLevel;
    if (temperature != null) map['temperature'] = temperature;
    if (lastUpdated != null) map['lastUpdated'] = lastUpdated;
    if (dataSource != null) map['dataSource'] = dataSource;
    if (isLive != null) map['isLive'] = isLive;

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

  // Determine water status based on flow rate
  String get waterStatus {
    if (flowRate == null || minRunnable == 0.0 || maxSafe == 0.0) {
      return 'Unknown';
    }

    if (flowRate! < minRunnable) {
      return 'Too Low';
    } else if (flowRate! > maxSafe) {
      return 'Too High';
    } else {
      return 'Runnable';
    }
  }

  // Get display name (riverName or fallback)
  String get displayName => name.isNotEmpty ? name : 'Station $stationId';

  // Check if station has live data
  bool get hasLiveData => isLive == true && dataSource == 'live';

  // Create a copy with modified values
  RiverStation copyWith({
    String? stationId,
    String? name,
    RiverSection? section,
    String? location,
    String? difficulty,
    double? minRunnable,
    double? maxSafe,
    double? flow,
    String? status,
    String? province,
    DateTime? addedAt,
    double? flowRate,
    double? waterLevel,
    double? temperature,
    String? lastUpdated,
    String? dataSource,
    bool? isLive,
  }) {
    return RiverStation(
      stationId: stationId ?? this.stationId,
      name: name ?? this.name,
      section: section ?? this.section,
      location: location ?? this.location,
      difficulty: difficulty ?? this.difficulty,
      minRunnable: minRunnable ?? this.minRunnable,
      maxSafe: maxSafe ?? this.maxSafe,
      flow: flow ?? this.flow,
      status: status ?? this.status,
      province: province ?? this.province,
      addedAt: addedAt ?? this.addedAt,
      flowRate: flowRate ?? this.flowRate,
      waterLevel: waterLevel ?? this.waterLevel,
      temperature: temperature ?? this.temperature,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dataSource: dataSource ?? this.dataSource,
      isLive: isLive ?? this.isLive,
    );
  }

  @override
  String toString() => '$displayName - ${section.name}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverStation && other.stationId == stationId;
  }

  @override
  int get hashCode => stationId.hashCode;
}
