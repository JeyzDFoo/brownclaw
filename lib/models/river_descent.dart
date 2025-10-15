import 'package:cloud_firestore/cloud_firestore.dart';
import 'river_section.dart';

class RiverDescent {
  final String? id;
  final String riverName;
  final RiverSection section;
  final String difficulty;
  final String waterLevel;
  final String notes;
  final String userId;
  final String? userEmail;
  final String? userName;
  final DateTime? timestamp;
  final String? date;

  const RiverDescent({
    this.id,
    required this.riverName,
    required this.section,
    required this.difficulty,
    required this.waterLevel,
    required this.notes,
    required this.userId,
    this.userEmail,
    this.userName,
    this.timestamp,
    this.date,
  });

  // Create from Map (for Firestore data)
  factory RiverDescent.fromMap(Map<String, dynamic> map, {String? docId}) {
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

    return RiverDescent(
      id: docId,
      riverName: map['riverName'] as String? ?? '',
      section: section,
      difficulty: map['difficulty'] as String? ?? 'Unknown',
      waterLevel: map['waterLevel'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userEmail: map['userEmail'] as String?,
      userName: map['userName'] as String?,
      timestamp: _timestampToDateTime(map['timestamp']),
      date: map['date'] as String?,
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'riverName': riverName,
      'section': section.toMap(),
      'difficulty': difficulty,
      'waterLevel': waterLevel,
      'notes': notes,
      'userId': userId,
    };

    if (userEmail != null) map['userEmail'] = userEmail;
    if (userName != null) map['userName'] = userName;
    if (timestamp != null) map['timestamp'] = Timestamp.fromDate(timestamp!);
    if (date != null) map['date'] = date;

    return map;
  }

  // Helper method to convert timestamp
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

  // Get full section display
  String get fullSectionDisplay {
    if (section.hasName) {
      return '${section.name} (${section.difficultyClass})';
    }
    return section.difficultyClass;
  }

  // Create a copy with modified values
  RiverDescent copyWith({
    String? id,
    String? riverName,
    RiverSection? section,
    String? difficulty,
    String? waterLevel,
    String? notes,
    String? userId,
    String? userEmail,
    String? userName,
    DateTime? timestamp,
    String? date,
  }) {
    return RiverDescent(
      id: id ?? this.id,
      riverName: riverName ?? this.riverName,
      section: section ?? this.section,
      difficulty: difficulty ?? this.difficulty,
      waterLevel: waterLevel ?? this.waterLevel,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      date: date ?? this.date,
    );
  }

  @override
  String toString() => '$riverName - ${section.name} on $formattedDate';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverDescent &&
        other.id == id &&
        other.riverName == riverName &&
        other.section == section &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, riverName, section, timestamp);
}
