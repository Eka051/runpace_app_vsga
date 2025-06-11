import 'package:flutter/material.dart';
import '../helper/db_helper.dart';
import '../models/activities_model.dart';
import '../models/gps_point_model.dart';
import '../models/acceleometer_model.dart';
import 'dart:math';

class ActivityDetailView extends StatefulWidget {
  final int activityId;

  const ActivityDetailView({super.key, required this.activityId});

  @override
  State<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends State<ActivityDetailView> {
  final DbHelper _dbHelper = DbHelper();
  ActivitiesModel? _activity;
  List<GpsPointModel> _gpsPoints = [];
  List<AccelerometerModel> _accelerometerData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    try {
      final db = await _dbHelper.getDatabase();

      final activityResult = await db.query(
        'activities',
        where: 'id = ?',
        whereArgs: [widget.activityId],
      );

      if (activityResult.isNotEmpty) {
        _activity = ActivitiesModel.fromMap(activityResult.first);
      }

      final gpsResult = await _dbHelper.getActivityGpsPoints(widget.activityId);
      _gpsPoints = gpsResult
          .map((data) => GpsPointModel.fromMap(data))
          .toList();

      final accelerometerResult = await _dbHelper.getActivityAccelerometerData(
        widget.activityId,
      );
      _accelerometerData = accelerometerResult
          .map((data) => AccelerometerModel.fromMap(data))
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildRouteVisualization() {
    if (_gpsPoints.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No GPS data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    double minLat = _gpsPoints.map((p) => p.latitude).reduce(min);
    double maxLat = _gpsPoints.map((p) => p.latitude).reduce(max);
    double minLng = _gpsPoints.map((p) => p.longitude).reduce(min);
    double maxLng = _gpsPoints.map((p) => p.longitude).reduce(max);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: CustomPaint(
        painter: RoutePainter(_gpsPoints, minLat, maxLat, minLng, maxLng),
        child: Container(),
      ),
    );
  }

  Widget _buildAccelerometerChart() {
    if (_accelerometerData.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No accelerometer data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: CustomPaint(
        painter: AccelerometerChartPainter(_accelerometerData),
        child: Container(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    if (_activity == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Activity not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Activity Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _activity!.distance.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Distance (km)',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatDuration(_activity!.duration),
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Duration',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _activity!.averagePace?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Avg Pace',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'GPS Route',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRouteVisualization(),
            const SizedBox(height: 24),
            Text(
              'Motion Analysis',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildAccelerometerChart(),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Summary',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Type:', style: TextStyle(color: Colors.grey[400])),
                      Text(
                        _activity!.activityType.toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GPS Points:',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      Text(
                        '${_gpsPoints.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Motion Data:',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      Text(
                        '${_accelerometerData.length} samples',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start Time:',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      Text(
                        DateTime.parse(
                          _activity!.startTime,
                        ).toString().substring(0, 16),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<GpsPointModel> points;
  final double minLat, maxLat, minLng, maxLng;

  RoutePainter(this.points, this.minLat, this.maxLat, this.minLng, this.maxLng);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final startPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final endPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = ((point.longitude - minLng) / (maxLng - minLng)) * size.width;
      final y =
          size.height -
          ((point.latitude - minLat) / (maxLat - minLat)) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        canvas.drawCircle(Offset(x, y), 6, startPaint);
      } else {
        path.lineTo(x, y);
        if (i == points.length - 1) {
          canvas.drawCircle(Offset(x, y), 6, endPaint);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AccelerometerChartPainter extends CustomPainter {
  final List<AccelerometerModel> data;

  AccelerometerChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintX = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintY = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintZ = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintMag = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pathX = Path();
    final pathY = Path();
    final pathZ = Path();
    final pathMag = Path();

    final maxValue = data
        .map((d) => [d.xAxis.abs(), d.yAxis.abs(), d.zAxis.abs(), d.magnitude])
        .expand((x) => x)
        .reduce(max);
    final minValue = -maxValue;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final yX =
          size.height / 2 -
          ((data[i].xAxis - 0) / (maxValue - minValue)) * size.height / 2;
      final yY =
          size.height / 2 -
          ((data[i].yAxis - 0) / (maxValue - minValue)) * size.height / 2;
      final yZ =
          size.height / 2 -
          ((data[i].zAxis - 0) / (maxValue - minValue)) * size.height / 2;
      final yMag =
          size.height -
          ((data[i].magnitude - 0) / (maxValue - 0)) * size.height;

      if (i == 0) {
        pathX.moveTo(x, yX);
        pathY.moveTo(x, yY);
        pathZ.moveTo(x, yZ);
        pathMag.moveTo(x, yMag);
      } else {
        pathX.lineTo(x, yX);
        pathY.lineTo(x, yY);
        pathZ.lineTo(x, yZ);
        pathMag.lineTo(x, yMag);
      }
    }

    canvas.drawPath(pathX, paintX);
    canvas.drawPath(pathY, paintY);
    canvas.drawPath(pathZ, paintZ);
    canvas.drawPath(pathMag, paintMag);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = const TextSpan(
      text: 'X',
      style: TextStyle(color: Colors.red, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(10, 10));

    textPainter.text = const TextSpan(
      text: 'Y',
      style: TextStyle(color: Colors.green, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(30, 10));

    textPainter.text = const TextSpan(
      text: 'Z',
      style: TextStyle(color: Colors.blue, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(50, 10));

    textPainter.text = const TextSpan(
      text: 'Mag',
      style: TextStyle(color: Colors.orange, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(70, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
