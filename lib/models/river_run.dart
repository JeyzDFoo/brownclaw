import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a specific section or run on a river
class RiverRun {
  final String id;
  final String riverId; // Reference to River
  final String name; // e.g., "Upper Canyon", "Lower Falls"
  final String difficultyClass; // e.g., "Class III", "Class V"
  final String? description;
  final double? length; // in kilometers
  final String? putIn; // Put-in location description
  final String? takeOut; // Take-out location description
  final double? gradient; // ft/mile or m/km
  final String? season; // Best season to run
  final String? permits; // Permit requirements
  final List<String>? hazards; // Known hazards
  final double? minRecommendedFlow; // Minimum recommended flow (cms)
  final double? maxRecommendedFlow; // Maximum safe flow (cms)
  final double? optimalFlowMin; // Optimal flow range minimum
  final double? optimalFlowMax; // Optimal flow range maximum
  final String? flowUnit; // 'cms', 'cfs', etc.
  final String? stationId; // Associated gauge station ID (if any)
  final String? createdBy; // User who created this section
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RiverRun({
    required this.id,
    required this.riverId,
    required this.name,
    required this.difficultyClass,
    this.description,
    this.length,
    this.putIn,
    this.takeOut,
    this.gradient,
    this.season,
    this.permits,
    this.hazards,
    this.minRecommendedFlow,
    this.maxRecommendedFlow,
    this.optimalFlowMin,
    this.optimalFlowMax,
    this.flowUnit,
    this.stationId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // Create from Map (for Firestore data)
  factory RiverRun.fromMap(Map<String, dynamic> map, {String? docId}) {
    return RiverRun(
      id: docId ?? map['id'] as String,
      riverId: map['riverId'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Section',
      difficultyClass: map['difficultyClass'] as String? ?? 'Unknown',
      description: map['description'] as String?,
      length: _safeToDouble(map['length']),
      putIn: map['putIn'] as String?,
      takeOut: map['takeOut'] as String?,
      gradient: _safeToDouble(map['gradient']),
      season: map['season'] as String?,
      permits: map['permits'] as String?,
      hazards: (map['hazards'] as List?)?.cast<String>(),
      minRecommendedFlow: _safeToDouble(map['minRecommendedFlow']),
      maxRecommendedFlow: _safeToDouble(map['maxRecommendedFlow']),
      optimalFlowMin: _safeToDouble(map['optimalFlowMin']),
      optimalFlowMax: _safeToDouble(map['optimalFlowMax']),
      flowUnit: map['flowUnit'] as String?,
      stationId: map['stationId'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: _timestampToDateTime(map['createdAt']),
      updatedAt: _timestampToDateTime(map['updatedAt']),
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'riverId': riverId,
      'name': name,
      'difficultyClass': difficultyClass,
    };

    if (description != null) map['description'] = description;
    if (length != null) map['length'] = length;
    if (putIn != null) map['putIn'] = putIn;
    if (takeOut != null) map['takeOut'] = takeOut;
    if (gradient != null) map['gradient'] = gradient;
    if (season != null) map['season'] = season;
    if (permits != null) map['permits'] = permits;
    if (hazards != null) map['hazards'] = hazards;
    if (minRecommendedFlow != null) {
      map['minRecommendedFlow'] = minRecommendedFlow;
    }
    if (maxRecommendedFlow != null) {
      map['maxRecommendedFlow'] = maxRecommendedFlow;
    }
    if (optimalFlowMin != null) map['optimalFlowMin'] = optimalFlowMin;
    if (optimalFlowMax != null) map['optimalFlowMax'] = optimalFlowMax;
    if (flowUnit != null) map['flowUnit'] = flowUnit;
    if (stationId != null) map['stationId'] = stationId;
    if (createdBy != null) map['createdBy'] = createdBy;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);

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

  // Get flow status based on a given flow rate
  String getFlowStatus(double? currentFlow) {
    if (currentFlow == null ||
        minRecommendedFlow == null ||
        maxRecommendedFlow == null) {
      return 'Unknown';
    }

    if (currentFlow < minRecommendedFlow!) {
      return 'Too Low';
    } else if (currentFlow > maxRecommendedFlow!) {
      return 'Too High';
    } else if (optimalFlowMin != null &&
        optimalFlowMax != null &&
        currentFlow >= optimalFlowMin! &&
        currentFlow <= optimalFlowMax!) {
      return 'Optimal';
    } else {
      return 'Runnable';
    }
  }

  // Check if run has flow recommendations
  bool get hasFlowRecommendations =>
      minRecommendedFlow != null && maxRecommendedFlow != null;

  // Get display name (section name with difficulty)
  String get displayName => '$name ($difficultyClass)';

  // Helper method to determine if this run has associated gauge stations
  // This would typically be checked by querying the GaugeStationService
  bool get hasAssociatedStations =>
      true; // Placeholder - to be implemented in service layer

  // Create a copy with modified values
  RiverRun copyWith({
    String? id,
    String? riverId,
    String? name,
    String? difficultyClass,
    String? description,
    double? length,
    String? putIn,
    String? takeOut,
    double? gradient,
    String? season,
    String? permits,
    List<String>? hazards,
    double? minRecommendedFlow,
    double? maxRecommendedFlow,
    double? optimalFlowMin,
    double? optimalFlowMax,
    String? flowUnit,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RiverRun(
      id: id ?? this.id,
      riverId: riverId ?? this.riverId,
      name: name ?? this.name,
      difficultyClass: difficultyClass ?? this.difficultyClass,
      description: description ?? this.description,
      length: length ?? this.length,
      putIn: putIn ?? this.putIn,
      takeOut: takeOut ?? this.takeOut,
      gradient: gradient ?? this.gradient,
      season: season ?? this.season,
      permits: permits ?? this.permits,
      hazards: hazards ?? this.hazards,
      minRecommendedFlow: minRecommendedFlow ?? this.minRecommendedFlow,
      maxRecommendedFlow: maxRecommendedFlow ?? this.maxRecommendedFlow,
      optimalFlowMin: optimalFlowMin ?? this.optimalFlowMin,
      optimalFlowMax: optimalFlowMax ?? this.optimalFlowMax,
      flowUnit: flowUnit ?? this.flowUnit,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverRun && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
