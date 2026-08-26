import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The local mirror.
///
/// Under the client-held-token design this is the system of record, not a
/// cache: the client is the only thing that talks to GitHub, so it is the
/// client that captures history. See PLAN.md section 4.
class DatabaseService {
  DatabaseService._init();

  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  /// v1 stored push events. v2 stores contributions — a different question
  /// with a different answer. See PLAN.md section 1.
  static const _version = 2;

  Future<Database> get database async {
    return _database ??= await _initDB('olc.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) => _createV2(db),
      onUpgrade: _upgrade,
    );
  }

  Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      // Push events cannot be converted into contributions — the two do not
      // agree about which work counts. Drop and refetch.
      await db.execute('DROP TABLE IF EXISTS commit_events');
      await db.execute('DROP TABLE IF EXISTS app_state');
      await _createV2(db);
    }
  }

  Future<void> _createV2(Database db) async {
    // One row per contribution-graph cell. `date` is GitHub's own label.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contribution_days (
        date TEXT PRIMARY KEY,
        count INTEGER NOT NULL,
        level INTEGER NOT NULL,
        first_contribution_at TEXT,
        last_contribution_at TEXT,
        counted_pushes INTEGER NOT NULL DEFAULT 0,
        uncounted_pushes INTEGER NOT NULL DEFAULT 0,
        sealed INTEGER NOT NULL DEFAULT 0,
        taken_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS contribution_activity (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        repo_name TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        title TEXT,
        counted INTEGER NOT NULL DEFAULT 1,
        branch TEXT,
        is_private INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_occurred '
      'ON contribution_activity (occurred_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repo_activity (
        repo_name TEXT PRIMARY KEY,
        contribution_count INTEGER NOT NULL DEFAULT 0,
        uncounted_pushes INTEGER NOT NULL DEFAULT 0,
        last_activity_at TEXT NOT NULL,
        is_private INTEGER NOT NULL DEFAULT 0,
        is_fork INTEGER NOT NULL DEFAULT 0,
        primary_language TEXT
      )
    ''');

    // The part that cannot be refetched. Everything else in this database can
    // be rebuilt from GitHub; these rows exist only because we wrote them
    // down as they happened.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminder_events (
        id TEXT PRIMARY KEY,
        sent_at TEXT NOT NULL,
        streak_at_send INTEGER NOT NULL DEFAULT 0,
        contributions_at_send INTEGER NOT NULL DEFAULT 0,
        hours_left INTEGER,
        outcome TEXT NOT NULL,
        outcome_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Derived rows waiting to reach the server. Nothing is generated only in
    // flight, so nothing is lost to a failed request.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
