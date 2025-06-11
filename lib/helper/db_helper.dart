import 'package:runpace_app/models/acceleometer_model.dart';
import 'package:runpace_app/models/activities_model.dart';
import 'package:runpace_app/models/gps_point_model.dart';
import 'package:runpace_app/models/user_model.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? database;
  DbHelper._internal();

  factory DbHelper() {
    return _instance;
  }

  Future<Database> getDatabase() async {
    if (database != null) return database!;
    database = await openDatabase(
      'runpace.db',
      version: 1,
      onCreate: (db, version) => createTable(db, version),
    );
    return database!;
  }

  Future<void> createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        activity_type TEXT NOT NULL DEFAULT 'running',
        distance REAL NOT NULL,
        duration INTEGER NOT NULL,
        average_pace REAL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gps_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accelerometer_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        x_axis REAL NOT NULL,
        y_axis REAL NOT NULL,
        z_axis REAL NOT NULL,
        magnitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> insertUser(UserModel user) async {
    final db = await getDatabase();
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertActivity(ActivitiesModel activity) async {
    final db = await getDatabase();
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertGpsPoint(GpsPointModel gpsPoint) async {
    final db = await getDatabase();
    await db.insert(
      'gps_points',
      gpsPoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAccelerometerData(AccelerometerModel accelerometerData) async {
    final db = await getDatabase();
    await db.insert(
      'accelerometer_data',
      accelerometerData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await getDatabase();
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await getDatabase();
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUserActivities(
    int userId, {
    int? limit,
  }) async {
    final db = await getDatabase();
    return await db.query(
      'activities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> getUserStats(int userId) async {
    final db = await getDatabase();

    final totalActivities = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM activities WHERE user_id = ?
    ''',
      [userId],
    );

    final totalDistance = await db.rawQuery(
      '''
      SELECT SUM(distance) as total FROM activities WHERE user_id = ?
    ''',
      [userId],
    );
    final totalDuration = await db.rawQuery(
      '''
      SELECT SUM(duration) as total FROM activities WHERE user_id = ?
    ''',
      [userId],
    );

    return {
      'totalActivities': totalActivities.first['count'] ?? 0,
      'totalDistance': totalDistance.first['total'] ?? 0.0,
      'totalDuration': totalDuration.first['total'] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getActivityGpsPoints(
    int activityId,
  ) async {
    final db = await getDatabase();
    return await db.query(
      'gps_points',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getActivityAccelerometerData(
    int activityId,
  ) async {
    final db = await getDatabase();
    return await db.query(
      'accelerometer_data',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<bool> deleteActivity(int activityId) async {
    final db = await getDatabase();
    final rowsAffected = await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
    return rowsAffected > 0;
  }
}
