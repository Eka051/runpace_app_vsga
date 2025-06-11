class GpsPointModel {
  final int? id;
  final int activityId;
  final double latitude;
  final double longitude;
  final String timestamp;

  GpsPointModel({
    this.id,
    required this.activityId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory GpsPointModel.fromMap(Map<String, dynamic> map) {
    return GpsPointModel(
      id: map['id'],
      activityId: map['activity_id'],
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }

  GpsPointModel copyWith({
    int? id,
    int? activityId,
    double? latitude,
    double? longitude,
    String? timestamp,
  }) {
    return GpsPointModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
