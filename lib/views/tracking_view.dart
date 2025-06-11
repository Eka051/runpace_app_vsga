import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import '../providers/auth_provider.dart';
import '../helper/db_helper.dart';
import '../models/gps_point_model.dart';
import '../models/acceleometer_model.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({super.key});

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  bool _isTracking = false;
  bool _isPaused = false;

  double _distance = 0.0;
  int _duration = 0;
  double _averagePace = 0.0;
  double _currentSpeed = 0.0;
  Position? _lastPosition;
  final List<Position> _routePoints = [];
  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _accelerometerZ = 0.0;
  double _accelerometerMagnitude = 0.0;

  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<AccelerometerEvent>? _accelerometerStream;

  DateTime? _startTime;
  int? _currentActivityId;

  final DbHelper _dbHelper = DbHelper();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeAccelerometer();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
  }

  void _initializeAccelerometer() {
    _accelerometerStream = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (mounted) {
        setState(() {
          _accelerometerX = event.x;
          _accelerometerY = event.y;
          _accelerometerZ = event.z;
          _accelerometerMagnitude = sqrt(
            pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
          );
        });

        if (_isTracking && _currentActivityId != null) {
          _saveAccelerometerData(
            event.x,
            event.y,
            event.z,
            _accelerometerMagnitude,
          );
        }
      }
    });
  }

  Future<void> _startTracking() async {
    final auth = Provider.of<AppAuth>(context, listen: false);
    if (auth.currentUserId == null) return;

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _distance = 0.0;
      _duration = 0;
      _routePoints.clear();
      _startTime = DateTime.now();
    });

    final activityData = await _dbHelper.getDatabase();
    final result = await activityData.insert('activities', {
      'user_id': auth.currentUserId,
      'activity_type': 'running',
      'distance': 0.0,
      'duration': 0,
      'average_pace': 0.0,
      'start_time': _startTime!.toIso8601String(),
      'end_time': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    _currentActivityId = result;

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          ),
        ).listen((Position position) {
          if (_isTracking && !_isPaused) {
            _updatePosition(position);
          }
        });

    _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused) {
        setState(() {
          _duration++;
          if (_distance > 0 && _duration > 0) {
            _averagePace = _duration / (_distance / 1000) / 60;
          }
        });
      }
    });
  }

  void _updatePosition(Position position) {
    if (_lastPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _distance += distanceInMeters;
        _currentSpeed = position.speed * 3.6;
      });
    }

    _routePoints.add(position);
    _lastPosition = position;

    if (_currentActivityId != null) {
      _saveGpsPoint(position);
    }
  }

  Future<void> _saveGpsPoint(Position position) async {
    final gpsPoint = GpsPointModel(
      activityId: _currentActivityId!,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertGpsPoint(gpsPoint);
  }

  Future<void> _saveAccelerometerData(
    double x,
    double y,
    double z,
    double magnitude,
  ) async {
    final accelerometerData = AccelerometerModel(
      activityId: _currentActivityId!,
      xAxis: x,
      yAxis: y,
      zAxis: z,
      magnitude: magnitude,
      timestamp: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertAccelerometerData(accelerometerData);
  }

  void _pauseResumeTracking() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _stopTracking() async {
    final auth = Provider.of<AppAuth>(context, listen: false);
    if (auth.currentUserId == null || _currentActivityId == null) return;

    setState(() {
      _isTracking = false;
      _isPaused = false;
    });

    _positionStream?.cancel();
    _trackingTimer?.cancel();

    final db = await _dbHelper.getDatabase();
    await db.update(
      'activities',
      {
        'distance': _distance / 1000,
        'duration': _duration,
        'average_pace': _averagePace,
        'end_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [_currentActivityId],
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accelerometerStream?.cancel();
    _trackingTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Running Tracker'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duration',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    (_distance / 1000).toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Distance (km)',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentSpeed.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Speed (km/h)',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _averagePace.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Avg Pace (min/km)',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _accelerometerMagnitude.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Motion (m/s²)',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Accelerometer Data',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'X: ${_accelerometerX.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 60,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (_accelerometerX.abs() / 20).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Y: ${_accelerometerY.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 60,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (_accelerometerY.abs() / 20).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Z: ${_accelerometerZ.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 60,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (_accelerometerZ.abs() / 20).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_isTracking)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'START TRACKING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _pauseResumeTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPaused
                              ? Colors.green
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _isPaused ? 'RESUME' : 'PAUSE',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _stopTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'STOP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
