class MedicineReminder {
  final String id;
  final String userId;
  final String medicineName;
  final String dosage;
  final String scheduleTime; // HH:mm format
  final bool isActive;

  MedicineReminder({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.dosage,
    required this.scheduleTime,
    this.isActive = true,
  });

  factory MedicineReminder.fromJson(Map<String, dynamic> json) {
    return MedicineReminder(
      id: json['id'],
      userId: json['user_id'],
      medicineName: json['medicine_name'],
      dosage: json['dosage'],
      scheduleTime: json['schedule_time'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'medicine_name': medicineName,
      'dosage': dosage,
      'schedule_time': scheduleTime,
      'is_active': isActive,
    };
  }
}
