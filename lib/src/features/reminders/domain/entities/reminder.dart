class Reminder {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final bool voiceEnabled;
  final bool notificationEnabled;
  final bool completed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.dateTime,
    required this.voiceEnabled,
    required this.notificationEnabled,
    required this.completed,
    required this.createdAt,
    this.updatedAt,
  });

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? voiceEnabled,
    bool? notificationEnabled,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}