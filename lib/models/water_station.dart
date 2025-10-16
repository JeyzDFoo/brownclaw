/// Represents a water monitoring station from Environment Canada
class WaterStation {
  final String documentId; // Firestore document ID
  final String stationId; // Official station ID (e.g., "08MF005")
  final String stationName;
  final String? riverName;
  final String? officialName;
  final String province;
  final double? latitude;
  final double? longitude;
  final String? operatorName;
  final String? stationStatus;
  final List<String>? availableParameters;
  final List<String>? searchTerms;

  const WaterStation({
    required this.documentId,
    required this.stationId,
    required this.stationName,
    this.riverName,
    this.officialName,
    required this.province,
    this.latitude,
    this.longitude,
    this.operatorName,
    this.stationStatus,
    this.availableParameters,
    this.searchTerms,
  });

  /// Create from Firestore document
  factory WaterStation.fromMap(Map<String, dynamic> map, String documentId) {
    return WaterStation(
      documentId: documentId,
      stationId: map['stationId'] as String? ?? map['id'] as String? ?? '',
      stationName:
          map['stationName'] as String? ??
          map['name'] as String? ??
          'Unknown Station',
      riverName: map['riverName'] as String?,
      officialName: map['official_name'] as String?,
      province: map['province'] as String? ?? 'Unknown',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      operatorName: map['operatorName'] as String?,
      stationStatus: map['stationStatus'] as String?,
      availableParameters: (map['availableParameters'] as List?)
          ?.cast<String>(),
      searchTerms: (map['searchTerms'] as List?)?.cast<String>(),
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'riverName': riverName,
      'official_name': officialName,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'operatorName': operatorName,
      'stationStatus': stationStatus,
      'availableParameters': availableParameters,
      'searchTerms': searchTerms,
    };
  }

  /// Get display name with station ID
  String get displayName => '$stationName ($stationId)';

  /// Get display name for river
  String get riverDisplayName => riverName ?? officialName ?? 'Unknown River';

  /// Check if this looks like a valid Canadian station ID
  bool get hasValidStationId {
    // Canadian station IDs are typically like "08MF005" (alphanumeric, starts with numbers)
    return RegExp(r'^[0-9][0-9A-Z]{5,}$').hasMatch(stationId);
  }

  @override
  String toString() => 'WaterStation($stationId: $stationName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaterStation && other.stationId == stationId;
  }

  @override
  int get hashCode => stationId.hashCode;
}
