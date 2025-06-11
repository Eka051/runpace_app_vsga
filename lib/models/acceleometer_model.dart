class AccelerometerModel {
  final int? id;
  final int activityId;
  final double xAxis;
  final double yAxis;
  final double zAxis;
  final double magnitude;
  final String timestamp;

  AccelerometerModel({
    this.id,
    required this.activityId,
    required this.xAxis,
    required this.yAxis,
    required this.zAxis,
    required this.magnitude,
    required this.timestamp,
  });

  factory AccelerometerModel.fromMap(Map<String, dynamic> map) {
    return AccelerometerModel(
      id: map['id'],
      activityId: map['activity_id'],
      xAxis: map['x_axis']?.toDouble() ?? 0.0,
      yAxis: map['y_axis']?.toDouble() ?? 0.0,
      zAxis: map['z_axis']?.toDouble() ?? 0.0,
      magnitude: map['magnitude']?.toDouble() ?? 0.0,
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'x_axis': xAxis,
      'y_axis': yAxis,
      'z_axis': zAxis,
      'magnitude': magnitude,
      'timestamp': timestamp,
    };
  }

  AccelerometerModel copyWith({
    int? id,
    int? activityId,
    double? xAxis,
    double? yAxis,
    double? zAxis,
    double? magnitude,
    String? timestamp,
  }) {
    return AccelerometerModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      zAxis: zAxis ?? this.zAxis,
      magnitude: magnitude ?? this.magnitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
