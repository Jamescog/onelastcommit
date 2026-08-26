import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/util/db_service.dart';
import '../models/commit_event_model.dart';

abstract class TrackerLocalDataSource {
  Future<List<CommitEventModel>> getLastEvents();
  Future<void> cacheEvents(List<CommitEventModel> events);
  Future<String?> getEtag();
  Future<void> saveEtag(String etag);
  Future<DateTime?> getLastFetchedAt();
  Future<void> saveLastFetchedAt(DateTime time);
}

class TrackerLocalDataSourceImpl implements TrackerLocalDataSource {
  final SharedPreferences sharedPreferences;
  final DatabaseService databaseService;

  TrackerLocalDataSourceImpl({
    required this.sharedPreferences,
    required this.databaseService,
  });

  @override
  Future<List<CommitEventModel>> getLastEvents() async {
    final db = await databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'commit_events',
      orderBy: 'occurred_at_utc DESC',
    );

    return maps.map((m) => CommitEventModel.fromMap(m)).toList();
  }

  @override
  Future<void> cacheEvents(List<CommitEventModel> events) async {
    final db = await databaseService.database;

    await db.transaction((txn) async {
      for (var event in events) {
        await txn.insert(
          'commit_events',
          event.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<String?> getEtag() async {
    return sharedPreferences.getString('etag');
  }

  @override
  Future<void> saveEtag(String etag) async {
    await sharedPreferences.setString('etag', etag);
  }

  @override
  Future<DateTime?> getLastFetchedAt() async {
    final str = sharedPreferences.getString('last_fetched_at');
    if (str != null) return DateTime.parse(str);
    return null;
  }

  @override
  Future<void> saveLastFetchedAt(DateTime time) async {
    await sharedPreferences.setString(
      'last_fetched_at',
      time.toUtc().toIso8601String(),
    );
  }
}
