import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'cache_scope.dart';

/// Local cache vNext (MOB-070). One SQLite file per [CacheScope], entirely
/// separate from the legacy `StudafyDatabase` preview adapter: this is the
/// production offline store, not a synthetic fixture, and it must never be
/// reachable from `StudafyBackend.isRemote == false` demo code paths.
///
/// Scoping by *file* rather than by a `WHERE user_id = ?` column is
/// deliberate: a forgotten filter clause cannot leak another tenant's rows
/// when there is no other tenant's rows in the file to begin with.
class OfflineCacheDatabase {
  OfflineCacheDatabase._(this.scope, this._db);

  final CacheScope scope;
  final Database _db;

  static final Map<String, OfflineCacheDatabase> _open = {};

  /// Opens (or returns the already-open) database for [scope]. Safe to call
  /// repeatedly; callers never hold a stale handle across a re-key because
  /// they ask for it by scope every time rather than caching the instance.
  static Future<OfflineCacheDatabase> open(CacheScope scope) async {
    final existing = _open[scope.fileKey];
    if (existing != null) return existing;
    final root = await getDatabasesPath();
    final db = await openDatabase(
      join(root, 'studafy_cache_${scope.fileKey}.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries(
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            version TEXT,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            tombstoned INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (entity_type, entity_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE mutation_outbox(
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at TEXT NOT NULL,
            last_error TEXT,
            status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_cursor(
            entity_type TEXT PRIMARY KEY,
            cursor TEXT,
            synced_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX outbox_status_idx ON mutation_outbox(status, next_attempt_at)',
        );
      },
    );
    final opened = OfflineCacheDatabase._(scope, db);
    _open[scope.fileKey] = opened;
    return opened;
  }

  Database get raw => _db;

  /// Closes the handle without deleting the file. Used on a same-user
  /// school/role switch, where the cache is still valid and simply not the
  /// active one right now.
  Future<void> close() async {
    _open.remove(scope.fileKey);
    await _db.close();
  }

  /// Closes and permanently deletes this scope's cache file. Used on
  /// sign-out and on explicit "erase my offline data" requests — never on a
  /// mere session switch between two still-valid memberships.
  static Future<void> wipe(CacheScope scope) async {
    final opened = _open.remove(scope.fileKey);
    if (opened != null) await opened._db.close();
    final root = await getDatabasesPath();
    await deleteDatabase(join(root, 'studafy_cache_${scope.fileKey}.db'));
  }
}
