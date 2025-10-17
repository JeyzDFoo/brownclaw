import 'package:cloud_firestore/cloud_firestore.dart';

class RiverDescent {
  final String? id;
  final String riverRunId; // Reference to RiverRun
  final String waterLevel; // Description of water level during the run
  final String notes;
  final String userId;
  final String? userEmail;
  final String? userName;
  final DateTime? timestamp;
  final String? date;
  final double? rating; // User's rating of the run (1-5 stars)
  final List<String>? tags; // Tags like "high-water", "first-descent", etc.

  const RiverDescent({
    this.id,
    required this.riverRunId,
    required this.waterLevel,
    required this.notes,
    required this.userId,
    this.userEmail,
    this.userName,
    this.timestamp,
    this.date,
    this.rating,
    this.tags,
  });

  // Create from Map (for Firestore data)
  factory RiverDescent.fromMap(Map<String, dynamic> map, {String? docId}) {
    return RiverDescent(
      id: docId,
      riverRunId: map['riverRunId'] as String? ?? '',
      waterLevel: _safeToString(map['waterLevel']),
      notes: map['notes'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userEmail: map['userEmail'] as String?,
      userName: map['userName'] as String?,
      timestamp: _timestampToDateTime(map['timestamp']),
      date: map['date'] as String?,
      rating: _safeToDouble(map['rating']),
      tags: (map['tags'] as List?)?.cast<String>(),
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'riverRunId': riverRunId,
      'waterLevel': waterLevel,
      'notes': notes,
      'userId': userId,
    };

    if (userEmail != null) map['userEmail'] = userEmail;
    if (userName != null) map['userName'] = userName;
    if (timestamp != null) map['timestamp'] = Timestamp.fromDate(timestamp!);
    if (date != null) map['date'] = date;
    if (rating != null) map['rating'] = rating;
    if (tags != null) map['tags'] = tags;

    return map;
  }

  // Helper methods
  static String _safeToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) return value.toString();
    return value.toString();
  }

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

  // Get formatted date string
  String get formattedDate {
    if (date != null) return date!;
    if (timestamp != null) {
      return '${timestamp!.year}-${timestamp!.month.toString().padLeft(2, '0')}-${timestamp!.day.toString().padLeft(2, '0')}';
    }
    return 'Unknown date';
  }

  // Get display name for user
  String get displayUserName {
    if (userName?.isNotEmpty == true) return userName!;
    if (userEmail?.isNotEmpty == true) return userEmail!.split('@')[0];
    return 'Unknown kayaker';
  }

  // Create a copy with modified values
  RiverDescent copyWith({
    String? id,
    String? riverRunId,
    String? waterLevel,
    String? notes,
    String? userId,
    String? userEmail,
    String? userName,
    DateTime? timestamp,
    String? date,
    double? rating,
    List<String>? tags,
  }) {
    return RiverDescent(
      id: id ?? this.id,
      riverRunId: riverRunId ?? this.riverRunId,
      waterLevel: waterLevel ?? this.waterLevel,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      date: date ?? this.date,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() => 'Descent on $riverRunId on $formattedDate';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverDescent &&
        other.id == id &&
        other.riverRunId == riverRunId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, riverRunId, timestamp);
}
