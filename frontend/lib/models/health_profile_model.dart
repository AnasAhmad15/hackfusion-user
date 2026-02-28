class HealthProfile {
  final String id;
  final List<String> allergies;
  final List<String> chronicConditions;
  final DateTime updatedAt;

  HealthProfile({
    required this.id,
    required this.allergies,
    required this.chronicConditions,
    required this.updatedAt,
  });

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      id: json['id'],
      allergies: List<String>.from(json['allergies'] ?? []),
      chronicConditions: List<String>.from(json['chronic_conditions'] ?? []),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
