import 'package:sqflite/sqflite.dart';

import '../../../../core/util/db_service.dart';
import '../../domain/entities/entities.dart';
import 'tracker_rows.dart';

/// The local mirror. Every read the UI performs comes from here.
abstract class TrackerLocalDataSource {
  Future<GitHubProfile?> getProfile();
  Future<void> saveProfile(GitHubProfile profile);

  Future<List<ContributionDay>> getCalendar({DateTime? from, DateTime? to});
  Future<void> saveCalendar(List<ContributionDay> days);

  Future<List<ContributionActivity>> getActivity({int limit});
  Future<void> saveActivity(List<ContributionActivity> items);

  Future<List<RepoContribution>> getRepos();
  Future<void> saveRepos(List<RepoContribution> repos);

  Future<List<ReminderEvent>> getReminders();
  Future<void> saveReminders(List<ReminderEvent> events);

  Future<DateTime?> getLastSyncedAt();
  Future<void> setLastSyncedAt(DateTime at);

  /// When the reminder check last ran.
  ///
  /// The high-water mark firings are reconstructed from. Null before the
  /// first check, which is not the same as "no reminders have fired" — it
  /// means we were not yet watching, and inventing history for that window
  /// would be worse than losing it.
  Future<DateTime?> getLastReminderCheckAt();
  Future<void> setLastReminderCheckAt(DateTime at);

  /// Marks every day before today as final. A day past its deadline will not
  /// change again, so a later write carrying stale data must not overwrite it.
  Future<void> sealDaysBefore(String todayLabel);

  Future<void> enqueue(String kind, String payload);

  /// Wipes the mirror, sealed rows included.
  ///
  /// Only for switching demo scenarios: a normal sync refuses to overwrite a
  /// sealed day, which is what stops a stale device clobbering good data.
  Future<void> clearAll();

  /// Drops only the rows that came from GitHub.
  ///
  /// Reminder events and the outbox are written by this device and can never
  /// be fetched again. A build change invalidates *parsing*, not history, so
  /// the resync must not take them with it.
  Future<void> clearRemoteMirror();

  /// The build that last wrote this mirror, or null if it has never been
  /// stamped.
  Future<String?> getBuildId();

  Future<void> setBuildId(String id);
}

class TrackerLocalDataSourceImpl implements TrackerLocalDataSource {
  const TrackerLocalDataSourceImpl({required this.databaseService});

  final DatabaseService databaseService;

  static const _kLastSynced = 'last_synced_at';
  static const _kLastReminderCheck = 'last_reminder_check_at';
  static const _kProfile = 'profile';
  static const _kBuildId = 'build_id';

  Future<Database> get _db => databaseService.database;

  Future<String?> _state(String key) async {
    final db = await _db;
    final rows = await db.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _setState(String key, String value) async {
    final db = await _db;
    await db.insert('sync_state', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<GitHubProfile?> getProfile() async {
    final raw = await _state(_kProfile);
    return raw == null ? null : TrackerRows.profileFromJson(raw);
  }

  @override
  Future<void> saveProfile(GitHubProfile profile) =>
      _setState(_kProfile, TrackerRows.profileToJson(profile));

  @override
  Future<List<ContributionDay>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(_label(from));
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(_label(to));
    }
    final rows = await db.query(
      'contribution_days',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date ASC',
    );
    return rows.map(TrackerRows.dayFromRow).toList();
  }

  @override
  Future<void> saveCalendar(List<ContributionDay> days) async {
    final db = await _db;
    final takenAt = DateTime.now().toUtc();
    await db.transaction((txn) async {
      for (final day in days) {
        // A sealed day is final. Writing it again would let a device that was
        // offline through the deadline overwrite a good row with stale data.
        final existing = await txn.query(
          'contribution_days',
          columns: ['sealed'],
          where: 'date = ?',
          whereArgs: [day.date],
          limit: 1,
        );
        if (existing.isNotEmpty && existing.first['sealed'] == 1) continue;

        await txn.insert(
          'contribution_days',
          TrackerRows.dayToRow(day, takenAt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<ContributionActivity>> getActivity({int limit = 20}) async {
    final db = await _db;
    final rows = await db.query(
      'contribution_activity',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(TrackerRows.activityFromRow).toList();
  }

  @override
  Future<void> saveActivity(List<ContributionActivity> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final a in items) {
        await txn.insert(
          'contribution_activity',
          TrackerRows.activityToRow(a),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<RepoContribution>> getRepos() async {
    final db = await _db;
    final rows = await db.query(
      'repo_activity',
      orderBy: 'contribution_count DESC',
    );
    return rows.map(TrackerRows.repoFromRow).toList();
  }

  @override
  Future<void> saveRepos(List<RepoContribution> repos) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final r in repos) {
        await txn.insert(
          'repo_activity',
          TrackerRows.repoToRow(r),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<ReminderEvent>> getReminders() async {
    final db = await _db;
    final rows = await db.query('reminder_events', orderBy: 'sent_at ASC');
    return rows.map(TrackerRows.reminderFromRow).toList();
  }

  @override
  Future<void> saveReminders(List<ReminderEvent> events) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final e in events) {
        await txn.insert(
          'reminder_events',
          TrackerRows.reminderToRow(e),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<DateTime?> getLastSyncedAt() async {
    final raw = await _state(_kLastSynced);
    return raw == null ? null : DateTime.parse(raw);
  }

  @override
  Future<void> setLastSyncedAt(DateTime at) =>
      _setState(_kLastSynced, at.toUtc().toIso8601String());

  @override
  Future<DateTime?> getLastReminderCheckAt() async {
    final raw = await _state(_kLastReminderCheck);
    return raw == null ? null : DateTime.parse(raw);
  }

  @override
  Future<void> setLastReminderCheckAt(DateTime at) =>
      _setState(_kLastReminderCheck, at.toUtc().toIso8601String());

  @override
  Future<void> sealDaysBefore(String todayLabel) async {
    final db = await _db;
    await db.update(
      'contribution_days',
      {'sealed': 1},
      where: 'date < ? AND sealed = 0',
      whereArgs: [todayLabel],
    );
  }

  @override
  Future<void> enqueue(String kind, String payload) async {
    final db = await _db;
    await db.insert('outbox', {
      'kind': kind,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<String?> getBuildId() => _state(_kBuildId);

  @override
  Future<void> setBuildId(String id) => _setState(_kBuildId, id);

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in const [
        'contribution_days',
        'contribution_activity',
        'repo_activity',
        'reminder_events',
        'outbox',
        'sync_state',
      ]) {
        await txn.delete(table);
      }
    });
  }

  @override
  Future<void> clearRemoteMirror() async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in const [
        'contribution_days',
        'contribution_activity',
        'repo_activity',
      ]) {
        await txn.delete(table);
      }
      // The mirror is empty, so nothing may claim to have been synced.
      await txn.delete(
        'sync_state',
        where: 'key IN (?, ?)',
        whereArgs: const [_kLastSynced, _kProfile],
      );
    });
  }

  static String _label(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }
}
