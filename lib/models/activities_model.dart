class ActivitiesModel {
  final int? id;
  final int userId;
  final String activityType;
  final double distance;
  final int duration;
  final double? averagePace;
  final String startTime;
  final String endTime;
  final String createdAt;

  ActivitiesModel({
    this.id,
    required this.userId,
    required this.activityType,
    required this.distance,
    required this.duration,
    this.averagePace,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory ActivitiesModel.fromMap(Map<String, dynamic> map) {
    return ActivitiesModel(
      id: map['id'],
      userId: map['user_id'],
      activityType: map['activity_type'] ?? 'running',
      distance: map['distance']?.toDouble() ?? 0.0,
      duration: map['duration'] ?? 0,
      averagePace: map['average_pace']?.toDouble(),
      startTime: map['start_time'],
      endTime: map['end_time'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'distance': distance,
      'duration': duration,
      'average_pace': averagePace,
      'start_time': startTime,
      'end_time': endTime,
      'created_at': createdAt,
    };
  }

  ActivitiesModel copyWith({
    int? id,
    int? userId,
    String? activityType,
    double? distance,
    int? duration,
    double? averagePace,
    String? startTime,
    String? endTime,
    String? createdAt,
  }) {
    return ActivitiesModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      averagePace: averagePace ?? this.averagePace,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
