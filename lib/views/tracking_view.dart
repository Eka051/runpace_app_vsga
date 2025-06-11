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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        title: Text(
          'Running Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duration',
                    style: TextStyle(
                      color: Colors.blue.shade100,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Distance',
                    value: '${(_distance / 1000).toStringAsFixed(2)} km',
                    color: Colors.green,
                    icon: Icons.straighten,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Speed',
                    value: '${_currentSpeed.toStringAsFixed(1)} km/h',
                    color: Colors.orange,
                    icon: Icons.speed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Avg Pace',
                    value: '${_averagePace.toStringAsFixed(1)} min/km',
                    color: Colors.purple,
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Motion',
                    value: '${_accelerometerMagnitude.toStringAsFixed(1)} m/s²',
                    color: Colors.red,
                    icon: Icons.vibration,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Accelerometer Data',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAccelerometerBar('X', _accelerometerX, Colors.red),
                      _buildAccelerometerBar(
                        'Y',
                        _accelerometerY,
                        Colors.green,
                      ),
                      _buildAccelerometerBar('Z', _accelerometerZ, Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (!_isTracking)
              _buildStartButton()
            else
              Row(
                children: [
                  Expanded(child: _buildPauseResumeButton()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStopButton()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccelerometerBar(String axis, double value, Color color) {
    return Column(
      children: [
        Text(
          '$axis: ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (value.abs() / 20).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _startTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'START TRACKING',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPauseResumeButton() {
    final color = _isPaused ? Colors.green : Colors.orange;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade400, color.shade600]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _pauseResumeTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          _isPaused ? 'RESUME' : 'PAUSE',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _stopTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'STOP',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
