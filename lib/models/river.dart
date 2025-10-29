import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a river - the main waterway
class River {
  final String id;
  final String name;
  final String region; // Province/State
  final String country;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const River({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  // Create from Map (for Firestore data)
  factory River.fromMap(Map<String, dynamic> map, {String? docId}) {
    return River(
      id: docId ?? map['id'] as String,
      name: map['name'] as String? ?? 'Unknown River',
      region: map['region'] as String? ?? 'Unknown',
      country: map['country'] as String? ?? 'Unknown',
      description: map['description'] as String?,
      createdAt: _timestampToDateTime(map['createdAt']),
      updatedAt: _timestampToDateTime(map['updatedAt']),
    );
  }

  // Convert to Map (for Firestore storage or JSON cache)
  // [forCache] - if true, uses ISO strings for timestamps instead of Firestore Timestamp
  Map<String, dynamic> toMap({bool forCache = false}) {
    final map = <String, dynamic>{
      'name': name,
      'region': region,
      'country': country,
    };

    if (description != null) map['description'] = description;

    // Handle timestamp serialization based on usage
    if (createdAt != null) {
      map['createdAt'] = forCache
          ? createdAt!.toIso8601String()
          : Timestamp.fromDate(createdAt!);
    }
    if (updatedAt != null) {
      map['updatedAt'] = forCache
          ? updatedAt!.toIso8601String()
          : Timestamp.fromDate(updatedAt!);
    }

    return map;
  }

  // Helper method to convert timestamp
  static DateTime? _timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp); // Handle ISO strings from cache
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Create a copy with modified values
  River copyWith({
    String? id,
    String? name,
    String? region,
    String? country,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return River(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      country: country ?? this.country,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => '$name ($region)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is River && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
