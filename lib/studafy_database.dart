import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'data/backend.dart';

part 'data/local/studafy_database_schema.dart';
part 'data/local/studafy_database_learning.dart';
part 'data/local/studafy_database_assessments.dart';
part 'data/local/studafy_database_teaching.dart';
part 'data/local/studafy_database_operations.dart';
part 'data/local/studafy_database_account.dart';

abstract class _StudafyDatabaseAccess {
  Future<Database> get database;

  Future<List<Map<String, Object?>>> classSchedule(int classId);
}

class StudafyDatabase extends _StudafyDatabaseAccess
    with
        _StudafySchema,
        _StudafyLearningQueries,
        _StudafyAssessmentQueries,
        _StudafyTeachingQueries,
        _StudafyOperationsQueries,
        _StudafyAccountQueries {
  StudafyDatabase._();
  static final instance = StudafyDatabase._();
  Database? _database;

  @override
  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    // Production and synthetic preview data must never share a cache file.
    // This also prevents a developer who later adds Supabase credentials from
    // carrying seeded identities or records into an authenticated session.
    final filename = StudafyBackend.isRemote
        ? 'studafy_cache.db'
        : 'studafy_preview.db';
    return openDatabase(
      join(root, filename),
      version: 10,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE classes(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, grade INTEGER NOT NULL, section TEXT NOT NULL, room TEXT NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL, color INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE students(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT UNIQUE)',
        );
        await db.execute(
          'CREATE TABLE enrollments(class_id INTEGER NOT NULL, student_id INTEGER NOT NULL, PRIMARY KEY(class_id, student_id), FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE, FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, student_id INTEGER NOT NULL, day TEXT NOT NULL, present INTEGER NOT NULL, UNIQUE(class_id, student_id, day))',
        );
        await db.execute(
          'CREATE TABLE notebooks(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, day TEXT NOT NULL, lesson TEXT NOT NULL, homework TEXT, UNIQUE(class_id, day))',
        );
        await db.execute(
          'CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, max_score INTEGER NOT NULL, status TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE assignments(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, title TEXT NOT NULL, due_at TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'assignment\')',
        );
        await db.execute(
          'CREATE TABLE submissions(id INTEGER PRIMARY KEY AUTOINCREMENT, assignment_id INTEGER NOT NULL, student_id INTEGER NOT NULL, score REAL, submitted_at TEXT, UNIQUE(assignment_id, student_id))',
        );
        await db.execute(
          'CREATE TABLE notices(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, message TEXT NOT NULL, mandatory INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE behaviours(id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL, kind TEXT NOT NULL, tag TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE incidents(id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL, category TEXT NOT NULL, severity TEXT NOT NULL, description TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
        await _createMessagingTables(db);
        await _createTeacherTables(db);
        await _createLearningTables(db);
        await _createIdentityTables(db);
        if (!StudafyBackend.isRemote) await _seed(db);
        await _createProductV6Tables(db);
        await _createAiGradingTables(db);
        await _createMeetingsFields(db);
        await _createProductionFoundation(db);
        await _createRemoteCacheKeys(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createMessagingTables(db);
        if (oldVersion < 3) await _createTeacherTables(db);
        if (oldVersion < 4) await _createLearningTables(db);
        if (oldVersion < 5) await _createIdentityTables(db);
        if (oldVersion < 6) await _createProductV6Tables(db);
        if (oldVersion < 7) await _createAiGradingTables(db);
        if (oldVersion < 8) await _createMeetingsFields(db);
        if (oldVersion < 9) await _createProductionFoundation(db);
        if (oldVersion < 10) await _createRemoteCacheKeys(db);
      },
    );
  }
}
