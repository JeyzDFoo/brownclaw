/// River type classification for data source handling
///
/// Different river types use different data sources and display patterns:
/// - Standard rivers use Government of Canada hydrometric data
/// - Kananaskis rivers use TransAlta dam release data (premium feature)
enum RiverType {
  /// Standard river using Government of Canada hydrometric data
  standard,

  /// Kananaskis region river using TransAlta Barrier Dam data
  kananaskis,
}

/// Extension methods for RiverType classification
extension RiverTypeExtension on RiverType {
  /// Check if this is a Kananaskis river
  bool get isKananaskis => this == RiverType.kananaskis;

  /// Check if this is a standard river
  bool get isStandard => this == RiverType.standard;

  /// Determine river type from river name
  static RiverType fromRiverName(String riverName) {
    final lower = riverName.toLowerCase();

    // Kananaskis river name patterns
    if (lower.contains('kananaskis') ||
        lower.contains('kan') ||
        lower == 'upper kan') {
      return RiverType.kananaskis;
    }

    return RiverType.standard;
  }

  /// Determine river type from station ID
  static RiverType fromStationId(String stationId) {
    // TransAlta station IDs contain underscores
    if (stationId.contains('_')) {
      return RiverType.kananaskis;
    }

    // Government of Canada station IDs are alphanumeric only
    return RiverType.standard;
  }

  /// Get human-readable description
  String get description {
    switch (this) {
      case RiverType.kananaskis:
        return 'Kananaskis (TransAlta Data)';
      case RiverType.standard:
        return 'Standard (Gov. of Canada Data)';
    }
  }

  /// Get data source description
  String get dataSource {
    switch (this) {
      case RiverType.kananaskis:
        return 'TransAlta Barrier Dam';
      case RiverType.standard:
        return 'Government of Canada Hydrometric';
    }
  }
}

/// Helper class for river type utilities
class RiverTypeHelper {
  /// Determine river type from river data map
  static RiverType fromRiverData(Map<String, dynamic> riverData) {
    // Try to determine from river name first
    final riverName = riverData['riverName'] as String?;
    if (riverName != null && riverName.isNotEmpty) {
      final typeFromName = RiverTypeExtension.fromRiverName(riverName);
      if (typeFromName == RiverType.kananaskis) {
        return RiverType.kananaskis;
      }
    }

    // Fall back to station ID
    final stationId = riverData['stationId'] as String?;
    if (stationId != null && stationId.isNotEmpty) {
      return RiverTypeExtension.fromStationId(stationId);
    }

    // Default to standard
    return RiverType.standard;
  }

  /// Check if river data represents a Kananaskis river
  static bool isKananaskisRiver(Map<String, dynamic> riverData) {
    return fromRiverData(riverData).isKananaskis;
  }
}
