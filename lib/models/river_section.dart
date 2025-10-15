class RiverSection {
  final String name;
  final String difficultyClass;

  const RiverSection({required this.name, required this.difficultyClass});

  // Create from Map (for Firestore data)
  factory RiverSection.fromMap(Map<String, dynamic> map) {
    return RiverSection(
      name: map['name'] as String? ?? '',
      difficultyClass: map['class'] as String? ?? 'Unknown',
    );
  }

  // Create from legacy string format (for backward compatibility)
  factory RiverSection.fromString(String section, String? defaultClass) {
    return RiverSection(
      name: section,
      difficultyClass: defaultClass ?? 'Unknown',
    );
  }

  // Convert to Map (for Firestore storage)
  Map<String, dynamic> toMap() {
    return {'name': name, 'class': difficultyClass};
  }

  // Create empty section
  factory RiverSection.empty() {
    return const RiverSection(name: '', difficultyClass: 'Unknown');
  }

  // Check if section has a name
  bool get hasName => name.isNotEmpty;

  @override
  String toString() =>
      name.isNotEmpty ? '$name ($difficultyClass)' : difficultyClass;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiverSection &&
        other.name == name &&
        other.difficultyClass == difficultyClass;
  }

  @override
  int get hashCode => name.hashCode ^ difficultyClass.hashCode;

  // Create a copy with modified values
  RiverSection copyWith({String? name, String? difficultyClass}) {
    return RiverSection(
      name: name ?? this.name,
      difficultyClass: difficultyClass ?? this.difficultyClass,
    );
  }
}
