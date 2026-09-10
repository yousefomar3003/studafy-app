import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'data/backend.dart';

class StudafyDatabase {
  StudafyDatabase._();
  static final instance = StudafyDatabase._();
  Database? _database;

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

  Future<void> _createRemoteCacheKeys(Database db) async {
    Future<void> addRemoteId(String table) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN remote_id TEXT');
      } catch (_) {}
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ${table}_remote_id_idx ON $table(remote_id) WHERE remote_id IS NOT NULL',
      );
    }

    for (final table in [
      'classes',
      'students',
      'assessment_submissions',
      'assessment_questions',
      'assessments',
      'assignments',
      'lesson_notes',
    ]) {
      await addRemoteId(table);
    }
  }

  Future<void> _createProductionFoundation(Database db) async {
    Future<void> addColumn(String table, String definition) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $definition');
      } catch (_) {}
    }

    await addColumn('students', 'provisional INTEGER NOT NULL DEFAULT 0');
    await addColumn(
      'assessment_submissions',
      'publication_state TEXT NOT NULL DEFAULT \'published\'',
    );
    await addColumn('assessment_submissions', 'reviewed_at TEXT');
    await addColumn('assessment_submissions', 'reviewed_by TEXT');
    await addColumn('notifications', 'route TEXT');
    await addColumn('notifications', 'user_key TEXT NOT NULL DEFAULT \'demo\'');
    await db.execute(
      'CREATE TABLE IF NOT EXISTS audit_events(id INTEGER PRIMARY KEY AUTOINCREMENT, actor_key TEXT NOT NULL, action TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT, before_value TEXT, after_value TEXT, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS account_deletion_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, user_key TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'grace_period\', requested_at TEXT NOT NULL, execute_after TEXT NOT NULL, cancelled_at TEXT)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS subscription_entitlements(user_key TEXT PRIMARY KEY, product_id TEXT NOT NULL, source TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0, expires_at TEXT, verified_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS audit_events_created_idx ON audit_events(created_at DESC)',
    );
  }

  Future<void> _createAiGradingTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS ai_grading_runs(id INTEGER PRIMARY KEY AUTOINCREMENT, submission_id INTEGER NOT NULL, scan_uri TEXT NOT NULL, strictness TEXT NOT NULL, proposed_score REAL NOT NULL, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS question_grades(id INTEGER PRIMARY KEY AUTOINCREMENT, submission_id INTEGER NOT NULL, question_id INTEGER NOT NULL, score REAL NOT NULL, max_score REAL NOT NULL, rationale TEXT, overridden INTEGER NOT NULL DEFAULT 0, UNIQUE(submission_id, question_id))',
    );
  }

  Future<void> _createMeetingsFields(Database db) async {
    Future<void> add(String definition) async {
      try {
        await db.execute('ALTER TABLE notices ADD COLUMN $definition');
      } catch (_) {}
    }

    await add('audience TEXT NOT NULL DEFAULT \'both\'');
    await add('meeting_url TEXT');
    await add('meeting_at TEXT');
    await add('title TEXT');
  }

  Future<void> _createProductV6Tables(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE classes ADD COLUMN weekly_sessions INTEGER NOT NULL DEFAULT 1',
      );
    } catch (_) {}
    await db.execute(
      'CREATE TABLE IF NOT EXISTS class_sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, weekday INTEGER NOT NULL, session_number INTEGER NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL, UNIQUE(class_id, weekday, session_number), FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS lesson_notes(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, day TEXT NOT NULL, session_number INTEGER NOT NULL DEFAULT 1, lesson TEXT NOT NULL, homework TEXT, UNIQUE(class_id, day, session_number), FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS attachments(id INTEGER PRIMARY KEY AUTOINCREMENT, owner_type TEXT NOT NULL, owner_id INTEGER NOT NULL, kind TEXT NOT NULL, name TEXT NOT NULL, uri TEXT NOT NULL, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS attachments_owner_idx ON attachments(owner_type, owner_id)',
    );
    await db.execute('UPDATE assessments SET delivery=\'online\'');

    final oldSchedules = await db.rawQuery(
      'SELECT s.*, c.start_time default_start, c.end_time default_end FROM class_schedule s JOIN classes c ON c.id=s.class_id',
    );
    for (final row in oldSchedules) {
      await db.insert('class_sessions', {
        'class_id': row['class_id'],
        'weekday': row['weekday'],
        'session_number': 1,
        'start_time': row['start_time'] ?? row['default_start'],
        'end_time': row['end_time'] ?? row['default_end'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final classes = await db.query('classes');
    for (final row in classes) {
      final classId = row['id'] as int;
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM class_sessions WHERE class_id=?',
              [classId],
            ),
          ) ??
          0;
      if (count == 0) {
        await db.insert('class_sessions', {
          'class_id': classId,
          'weekday': 1,
          'session_number': 1,
          'start_time': row['start_time'],
          'end_time': row['end_time'],
        });
      }
      await db.update(
        'classes',
        {'weekly_sessions': count == 0 ? 1 : count},
        where: 'id=?',
        whereArgs: [classId],
      );
    }
    final oldNotes = await db.query('notebooks');
    for (final note in oldNotes) {
      await db.insert('lesson_notes', {
        'class_id': note['class_id'],
        'day': note['day'],
        'session_number': 1,
        'lesson': note['lesson'],
        'homework': note['homework'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createIdentityTables(Database db) async {
    Future<void> addColumn(String table, String definition) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $definition');
      } catch (_) {}
    }

    await addColumn('teacher_profile', 'photo_path TEXT');
    await addColumn('attendance', 'status TEXT NOT NULL DEFAULT \'present\'');
    await addColumn('attendance', 'reason TEXT');
    await db.execute(
      'UPDATE attendance SET status=CASE WHEN present=1 THEN \'present\' ELSE \'absent\' END WHERE status IS NULL OR status=\'\'',
    );
    final accepted =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM connection_requests WHERE status=\'accepted\'',
          ),
        ) ??
        0;
    if (accepted == 0) {
      final students = await db.query('students', limit: 2);
      for (final student in students) {
        await db.insert('connection_requests', {
          'requester_id': 'ST-2H9X-46B',
          'student_id': student['id'],
          'status': 'accepted',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _createLearningTables(Database db) async {
    Future<void> addColumn(String table, String definition) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $definition');
      } catch (_) {}
    }

    await addColumn('assessments', 'delivery TEXT NOT NULL DEFAULT \'online\'');
    await addColumn('assessments', 'scheduled_at TEXT');
    await addColumn('students', 'studafy_id TEXT');
    await db.execute(
      'CREATE TABLE IF NOT EXISTS assessment_questions(id INTEGER PRIMARY KEY AUTOINCREMENT, assessment_id INTEGER NOT NULL, prompt TEXT NOT NULL, type TEXT NOT NULL, points INTEGER NOT NULL, options TEXT, answer TEXT, FOREIGN KEY(assessment_id) REFERENCES assessments(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS assessment_submissions(id INTEGER PRIMARY KEY AUTOINCREMENT, assessment_id INTEGER NOT NULL, student_id INTEGER NOT NULL, answer_text TEXT, score REAL, feedback TEXT, submitted_at TEXT, UNIQUE(assessment_id,student_id))',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS connection_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, requester_id TEXT NOT NULL, student_id INTEGER NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', created_at TEXT NOT NULL)',
    );
    final students = await db.query('students');
    for (final student in students) {
      if (student['studafy_id'] == null) {
        await db.update(
          'students',
          {
            'studafy_id':
                'STU-${(student['id'] as int).toString().padLeft(4, '0')}',
          },
          where: 'id=?',
          whereArgs: [student['id']],
        );
      }
    }
    final assessments = await db.query('assessments');
    for (final assessment in assessments) {
      final aid = assessment['id'] as int;
      final qCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM assessment_questions WHERE assessment_id=?',
              [aid],
            ),
          ) ??
          0;
      if (qCount == 0) {
        await db.insert('assessment_questions', {
          'assessment_id': aid,
          'prompt': 'Explain the key concept in your own words.',
          'type': 'long_answer',
          'points': assessment['max_score'],
          'options': null,
          'answer': null,
        });
      }
      final classId = assessment['class_id'] as int;
      final enrolled = await db.rawQuery(
        'SELECT student_id FROM enrollments WHERE class_id=?',
        [classId],
      );
      for (final student in enrolled.take(3)) {
        await db.insert('assessment_submissions', {
          'assessment_id': aid,
          'student_id': student['student_id'],
          'answer_text': 'My submitted response for this assessment.',
          'score': null,
          'feedback': null,
          'submitted_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _createTeacherTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS class_schedule(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, weekday INTEGER NOT NULL, start_time TEXT NOT NULL, end_time TEXT NOT NULL, UNIQUE(class_id, weekday), FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS teacher_profile(id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, email TEXT NOT NULL, school TEXT NOT NULL, do_not_disturb INTEGER NOT NULL DEFAULT 0, submissions INTEGER NOT NULL DEFAULT 1, gradebook INTEGER NOT NULL DEFAULT 1, messages INTEGER NOT NULL DEFAULT 1, attendance_reminder INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS notifications(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, kind TEXT NOT NULL, created_at TEXT NOT NULL, is_read INTEGER NOT NULL DEFAULT 0)',
    );
    await db.insert('teacher_profile', {
      'id': 1,
      'name': 'Rania Haddad',
      'email': 'r.haddad@alnoor.edu',
      'school': 'Al-Noor International',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM notifications'),
        ) ??
        0;
    if (count == 0) {
      final rows = [
        [
          'New submission',
          'Layla Hassan submitted the photosynthesis lab report.',
          'submission',
        ],
        [
          'Gradebook approved',
          'Quiz 4 — Photosynthesis was approved and published.',
          'gradebook',
        ],
        [
          'Attendance missing',
          'Grade 10 B attendance has not been recorded.',
          'attendance',
        ],
        [
          'Timetable change',
          'Thursday period 3 moves to Lab 1 this week.',
          'schedule',
        ],
        [
          'Incident update',
          'Your incident report is now under review.',
          'incident',
        ],
      ];
      for (final row in rows) {
        await db.insert('notifications', {
          'title': row[0],
          'body': row[1],
          'kind': row[2],
          'created_at': DateTime.now().toIso8601String(),
          'is_read': 0,
        });
      }
    }
  }

  Future<void> _createMessagingTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS invitations(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, token TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS chats(id INTEGER PRIMARY KEY AUTOINCREMENT, contact_name TEXT NOT NULL, context TEXT, initials TEXT NOT NULL, color INTEGER NOT NULL, updated_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id INTEGER NOT NULL, body TEXT NOT NULL, sent_by_me INTEGER NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE)',
    );
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM chats'),
        ) ??
        0;
    if (count == 0) {
      final contacts = [
        [
          'Nadia Hassan',
          'Layla · Grade 10 B',
          'NH',
          0xFF241D73,
          'Thank you, I’ll go through it with her tonight.',
        ],
        [
          'Dr. Samy Farouk',
          'School leadership',
          'SF',
          0xFF20C6E8,
          'Please send the Grade 10 midterm sheet.',
        ],
        [
          'Mr. Ferreira',
          'Mathematics',
          'MF',
          0xFF7737EE,
          'Can we swap Lab 2 on Thursday?',
        ],
        [
          'Ms. Duarte',
          'English · Grade 9',
          'MD',
          0xFF0D8ECC,
          'Ali settled in well this week.',
        ],
        [
          'Hoda Kamal',
          'Youssef · Grade 10 A',
          'HK',
          0xFFEF1748,
          'Is there extra practice for the titration unit?',
        ],
      ];
      for (final item in contacts) {
        final chatId = await db.insert('chats', {
          'contact_name': item[0],
          'context': item[1],
          'initials': item[2],
          'color': item[3],
          'updated_at': DateTime.now().toIso8601String(),
        });
        await db.insert('messages', {
          'chat_id': chatId,
          'body': item[4],
          'sent_by_me': 0,
          'created_at': DateTime.now()
              .subtract(const Duration(minutes: 18))
              .toIso8601String(),
        });
      }
    }
  }

  Future<void> _seed(Database db) async {
    final classes = [
      ['Biology', 10, 'B', 'Lab 2', '08:30', '09:20', 0xFF241D73],
      ['Biology', 9, 'A', 'Lab 2', '09:30', '10:20', 0xFF20C6E8],
      ['Chemistry', 10, 'A', 'Lab 1', '11:00', '11:50', 0xFF7737EE],
      ['Science', 8, 'C', 'Room 12', '13:40', '14:30', 0xFF0D8ECC],
    ];
    for (final c in classes) {
      await db.insert('classes', {
        'name': c[0],
        'grade': c[1],
        'section': c[2],
        'room': c[3],
        'start_time': c[4],
        'end_time': c[5],
        'color': c[6],
      });
    }
    const names = [
      'Layla Hassan',
      'Omar Fathy',
      'Mariam Adel',
      'Youssef Kamal',
      'Salma Nabil',
      'Adam Mostafa',
    ];
    for (var i = 0; i < names.length; i++) {
      final id = await db.insert('students', {
        'name': names[i],
        'email': 'student${i + 1}@alnoor.edu',
      });
      for (var classId = 1; classId <= 4; classId++) {
        await db.insert('enrollments', {'class_id': classId, 'student_id': id});
      }
    }
    final assessments = [
      [4, 'Exam', 'Midterm — Cells & energy', 20, 'Draft'],
      [4, 'Quiz', 'Quiz 4 — Photosynthesis', 10, 'Published'],
      [4, 'Quiz', 'Quiz 3 — Cell transport', 10, 'Rejected'],
      [4, 'Exam', 'Unit 2 test', 20, 'Published'],
    ];
    for (final a in assessments) {
      await db.insert('assessments', {
        'class_id': a[0],
        'type': a[1],
        'title': a[2],
        'max_score': a[3],
        'status': a[4],
      });
    }
    final assignments = [
      [1, 'Photosynthesis lab report', '2026-09-18T15:00:00'],
      [2, 'Cell diagram worksheet', '2026-09-16T09:00:00'],
      [3, 'Titration write-up', '2026-09-14T15:00:00'],
      [4, 'Food chains poster', '2026-09-22T15:00:00'],
    ];
    for (final a in assignments) {
      await db.insert('assignments', {
        'class_id': a[0],
        'title': a[1],
        'due_at': a[2],
        'kind': 'assignment',
      });
    }
    final notices = [
      [1, 'Bring safety goggles on Thursday', 1],
      [1, 'Chapter 4 revision pack is up', 0],
      [2, 'Worksheet deadline moved to Monday', 0],
    ];
    for (final n in notices) {
      await db.insert('notices', {
        'class_id': n[0],
        'message': n[1],
        'mandatory': n[2],
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, Object?>>> classes() async =>
      (await database).rawQuery(
        'SELECT c.*, COUNT(e.student_id) student_count FROM classes c LEFT JOIN enrollments e ON e.class_id=c.id GROUP BY c.id ORDER BY c.id DESC',
      );
  Future<int?> classIdForLabel(String label) async {
    final rows = await classes();
    for (final row in rows) {
      if (label.contains('${row['name']}') &&
          label.contains('Grade ${row['grade']} ${row['section']}')) {
        return row['id'] as int;
      }
    }
    return null;
  }

  Future<List<Map<String, Object?>>> students([int? classId]) async =>
      (await database).rawQuery(
        classId == null ? 'SELECT * FROM students ORDER BY name' : 'SELECT s.* FROM students s JOIN enrollments e ON e.student_id=s.id WHERE e.class_id=? ORDER BY s.name',
        classId == null ? [] : [classId],
      );

  Future<List<Map<String, Object?>>> classesForStudent(int studentId) async =>
      (await database).rawQuery(
        'SELECT c.* FROM classes c JOIN enrollments e ON e.class_id=c.id WHERE e.student_id=? ORDER BY c.name, c.grade, c.section',
        [studentId],
      );

  Future<List<Map<String, Object?>>> todaySessionsForStudent(
    int studentId, {
    DateTime? day,
  }) async {
    final localDay = day ?? DateTime.now();
    return (await database).rawQuery(
      'SELECT c.*, cs.id session_id, cs.session_number, cs.start_time session_start_time, cs.end_time session_end_time '
      'FROM class_sessions cs '
      'JOIN classes c ON c.id=cs.class_id '
      'JOIN enrollments e ON e.class_id=c.id '
      'WHERE e.student_id=? AND cs.weekday=? '
      'ORDER BY cs.start_time, cs.session_number, cs.id',
      [studentId, localDay.weekday],
    );
  }

  Future<List<Map<String, Object?>>> workForStudent(int studentId) async =>
      (await database).rawQuery(
        'SELECT a.*, c.name class_name, s.id submission_id, s.submitted_at, s.score FROM assignments a JOIN classes c ON c.id=a.class_id JOIN enrollments e ON e.class_id=a.class_id LEFT JOIN submissions s ON s.assignment_id=a.id AND s.student_id=e.student_id WHERE e.student_id=? ORDER BY a.due_at',
        [studentId],
      );

  Future<List<Map<String, Object?>>> behavioursForStudent(
    int studentId,
  ) async => (await database).query(
    'behaviours',
    where: 'student_id=?',
    whereArgs: [studentId],
    orderBy: 'created_at DESC',
  );

  Future<Map<String, num>> insightMetricsForStudent(
    int studentId, {
    DateTime? since,
  }) async {
    final db = await database;
    final sinceDay = since?.toIso8601String().substring(0, 10);
    final sinceTimestamp = since?.toIso8601String();
    final attendance = await db.rawQuery(
      'SELECT '
      'SUM(CASE WHEN status!=\'excused\' THEN 1 ELSE 0 END) total, '
      'SUM(CASE WHEN status=\'present\' OR (status IS NULL AND present=1) THEN 1 ELSE 0 END) present, '
      'SUM(CASE WHEN status=\'tardy\' THEN 1 ELSE 0 END) tardy, '
      'SUM(CASE WHEN status=\'absent\' OR (status IS NULL AND present=0) THEN 1 ELSE 0 END) absent, '
      'SUM(CASE WHEN status=\'excused\' THEN 1 ELSE 0 END) excused '
      'FROM attendance WHERE student_id=? ${sinceDay == null ? '' : 'AND day>=?'}',
      sinceDay == null ? [studentId] : [studentId, sinceDay],
    );
    final work = await db.rawQuery(
      'SELECT COUNT(a.id) assigned, '
      'SUM(CASE WHEN s.submitted_at IS NOT NULL THEN 1 ELSE 0 END) submitted, '
      'SUM(CASE WHEN s.submitted_at IS NULL THEN 1 ELSE 0 END) missing, '
      'SUM(CASE WHEN s.submitted_at IS NOT NULL AND s.submitted_at<=a.due_at THEN 1 ELSE 0 END) on_time, '
      'SUM(CASE WHEN s.submitted_at IS NOT NULL AND s.submitted_at>a.due_at THEN 1 ELSE 0 END) late '
      'FROM assignments a JOIN enrollments e ON e.class_id=a.class_id '
      'LEFT JOIN submissions s ON s.assignment_id=a.id AND s.student_id=e.student_id '
      'WHERE e.student_id=? AND a.due_at<=? ${sinceTimestamp == null ? '' : 'AND a.due_at>=?'}',
      sinceTimestamp == null
          ? [studentId, DateTime.now().toIso8601String()]
          : [studentId, DateTime.now().toIso8601String(), sinceTimestamp],
    );
    final grades = await db.rawQuery(
      'SELECT COUNT(s.id) graded_count, '
      'AVG(CASE WHEN s.score IS NOT NULL AND a.max_score>0 THEN (s.score * 100.0 / a.max_score) END) grade_average '
      'FROM assessment_submissions s JOIN assessments a ON a.id=s.assessment_id '
      'WHERE s.student_id=? AND s.score IS NOT NULL AND s.publication_state=\'published\' '
      '${sinceTimestamp == null ? '' : 'AND COALESCE(s.submitted_at,a.scheduled_at)>=?'}',
      sinceTimestamp == null ? [studentId] : [studentId, sinceTimestamp],
    );
    final behaviour = await db.rawQuery(
      'SELECT COUNT(*) total, SUM(CASE WHEN LOWER(kind) LIKE "%positive%" OR LOWER(kind) LIKE "%praise%" THEN 1 ELSE 0 END) positive, SUM(CASE WHEN LOWER(kind) LIKE "%negative%" OR LOWER(kind) LIKE "%concern%" THEN 1 ELSE 0 END) concerns FROM behaviours WHERE student_id=? ${sinceTimestamp == null ? '' : 'AND created_at>=?'}',
      sinceTimestamp == null ? [studentId] : [studentId, sinceTimestamp],
    );
    final classes =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM enrollments WHERE student_id=?',
            [studentId],
          ),
        ) ??
        0;
    num value(Map<String, Object?> row, String key) => row[key] as num? ?? 0;
    return {
      'attendance_total': value(attendance.first, 'total'),
      'present': value(attendance.first, 'present'),
      'tardy': value(attendance.first, 'tardy'),
      'absent': value(attendance.first, 'absent'),
      'excused': value(attendance.first, 'excused'),
      'assigned': value(work.first, 'assigned'),
      'submitted': value(work.first, 'submitted'),
      'missing': value(work.first, 'missing'),
      'on_time': value(work.first, 'on_time'),
      'late': value(work.first, 'late'),
      'graded_count': value(grades.first, 'graded_count'),
      'grade_average': value(grades.first, 'grade_average'),
      'behaviour_total': value(behaviour.first, 'total'),
      'positive': value(behaviour.first, 'positive'),
      'concerns': value(behaviour.first, 'concerns'),
      'classes': classes,
    };
  }

  Future<List<Map<String, Object?>>> gradesForStudent(int studentId) async =>
      (await database).rawQuery(
        'SELECT s.*, a.title, a.type, a.max_score, c.name class_name, c.color FROM assessment_submissions s JOIN assessments a ON a.id=s.assessment_id JOIN classes c ON c.id=a.class_id WHERE s.student_id=? AND s.score IS NOT NULL ORDER BY s.id DESC',
        [studentId],
      );

  Future<List<Map<String, Object?>>> noticesForStudent(int studentId) async =>
      (await database).rawQuery(
        'SELECT DISTINCT n.*, c.name class_name, c.grade, c.section FROM notices n JOIN classes c ON c.id=n.class_id JOIN enrollments e ON e.class_id=c.id WHERE e.student_id=? AND COALESCE(n.audience,"both") IN ("students","both") ORDER BY n.created_at DESC',
        [studentId],
      );

  Future<List<Map<String, Object?>>> parentNotices() async =>
      (await database).rawQuery(
        'SELECT n.*, c.name class_name, c.grade, c.section, COUNT(e.student_id) reach FROM notices n JOIN classes c ON c.id=n.class_id LEFT JOIN enrollments e ON e.class_id=c.id WHERE COALESCE(n.audience,"both") IN ("parents","both") GROUP BY n.id ORDER BY n.created_at DESC',
      );

  Future<List<Map<String, Object?>>> assessmentsForStudent(
    int studentId,
  ) async => (await database).rawQuery(
    'SELECT DISTINCT a.*, c.name class_name, c.color, s.id submission_id, s.score, s.feedback, s.submitted_at, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'exam\' AND x.owner_id=a.id) attachment_count FROM assessments a JOIN classes c ON c.id=a.class_id JOIN enrollments e ON e.class_id=c.id LEFT JOIN assessment_submissions s ON s.assessment_id=a.id AND s.student_id=e.student_id WHERE e.student_id=? ORDER BY COALESCE(a.scheduled_at, \'9999\')',
    [studentId],
  );

  Future<int> submitAssignment(int assignmentId, int studentId) async {
    final db = await database;
    final existing = await db.query(
      'submissions',
      where: 'assignment_id=? AND student_id=?',
      whereArgs: [assignmentId, studentId],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'submissions',
        {'submitted_at': now},
        where: 'id=?',
        whereArgs: [id],
      );
      return id;
    }
    return db.insert('submissions', {
      'assignment_id': assignmentId,
      'student_id': studentId,
      'submitted_at': now,
    });
  }

  Future<void> submitAssessment(
    int assessmentId,
    int studentId,
    String answers,
  ) async {
    await (await database).insert('assessment_submissions', {
      'assessment_id': assessmentId,
      'student_id': studentId,
      'answer_text': answers,
      'submitted_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> assessments() async =>
      (await database).rawQuery(
        'SELECT a.*, c.name class_name, c.grade, c.section, c.color, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'exam\' AND x.owner_id=a.id) attachment_count FROM assessments a JOIN classes c ON c.id=a.class_id ORDER BY a.id DESC',
      );
  Future<List<Map<String, Object?>>> assessmentQuestions(
    int assessmentId,
  ) async => (await database).query(
    'assessment_questions',
    where: 'assessment_id=?',
    whereArgs: [assessmentId],
    orderBy: 'id',
  );
  Future<List<Map<String, Object?>>> assessmentSubmissions(
    int assessmentId,
  ) async => (await database).rawQuery(
    'SELECT s.*, st.name student_name, st.studafy_id FROM assessment_submissions s JOIN students st ON st.id=s.student_id WHERE s.assessment_id=? ORDER BY s.submitted_at DESC',
    [assessmentId],
  );
  Future<List<Map<String, Object?>>> allAssessmentSubmissions([
    int? classId,
  ]) async => (await database).rawQuery(
    'SELECT s.*, st.name student_name, a.title assessment_title, a.max_score, a.class_id, a.delivery, c.grade, c.section FROM assessment_submissions s JOIN students st ON st.id=s.student_id JOIN assessments a ON a.id=s.assessment_id JOIN classes c ON c.id=a.class_id ${classId == null ? '' : 'WHERE a.class_id=?'} ORDER BY s.submitted_at DESC',
    classId == null ? [] : [classId],
  );
  Future<void> addQuestion(Map<String, Object?> value) async {
    await (await database).insert('assessment_questions', value);
  }

  Future<void> gradeSubmission(int id, double score, String feedback) async {
    await (await database).update(
      'assessment_submissions',
      {
        'score': score,
        'feedback': feedback,
        'publication_state': 'reviewed',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': 'teacher-demo',
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> publishGradeSubmission(int id) async {
    final db = await database;
    final before = await db.query(
      'assessment_submissions',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (before.isEmpty || before.first['publication_state'] != 'reviewed') {
      throw StateError('A grade must be reviewed before publication.');
    }
    await db.transaction((txn) async {
      await txn.update(
        'assessment_submissions',
        {'publication_state': 'published'},
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.insert('audit_events', {
        'actor_key': 'teacher-demo',
        'action': 'grade_published',
        'entity_type': 'assessment_submission',
        'entity_id': '$id',
        'before_value': 'reviewed',
        'after_value': 'published',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> saveAiGradeProposal({
    required int submissionId,
    required String scanUri,
    required String strictness,
    required List<Map<String, Object?>> grades,
  }) async {
    final db = await database;
    final total = grades.fold<double>(
      0,
      (sum, item) => sum + (item['score'] as num).toDouble(),
    );
    await db.transaction((txn) async {
      await txn.insert('ai_grading_runs', {
        'submission_id': submissionId,
        'scan_uri': scanUri,
        'strictness': strictness,
        'proposed_score': total,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final item in grades) {
        await txn.insert('question_grades', {
          'submission_id': submissionId,
          'question_id': item['question_id'],
          'score': item['score'],
          'max_score': item['max_score'],
          'rationale': item['rationale'],
          'overridden': item['overridden'] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> updateQuestionAnswer(int questionId, String answer) async {
    await (await database).update(
      'assessment_questions',
      {'answer': answer},
      where: 'id=?',
      whereArgs: [questionId],
    );
  }

  Future<List<Map<String, Object?>>> assignments() async =>
      (await database).rawQuery(
        'SELECT a.*, c.name class_name, c.grade, c.section, c.color, COUNT(s.id) submitted, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'assignment\' AND x.owner_id=a.id) attachment_count FROM assignments a JOIN classes c ON c.id=a.class_id LEFT JOIN submissions s ON s.assignment_id=a.id AND s.submitted_at IS NOT NULL GROUP BY a.id ORDER BY due_at',
      );
  Future<List<Map<String, Object?>>> notices() async =>
      (await database).rawQuery(
        'SELECT n.*, c.name class_name, c.grade, c.section, COUNT(e.student_id) reach, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'announcement\' AND x.owner_id=n.id) attachment_count FROM notices n JOIN classes c ON c.id=n.class_id LEFT JOIN enrollments e ON e.class_id=c.id GROUP BY n.id ORDER BY n.id DESC',
      );
  Future<int> addClass(Map<String, Object?> value) async =>
      (await database).insert('classes', value);
  Future<int> addClassWithSchedule(
    Map<String, Object?> value,
    List<Map<String, Object?>> schedule,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('classes', value);
      for (var i = 0; i < schedule.length; i++) {
        final slot = schedule[i];
        await txn.insert('class_sessions', {
          'class_id': id,
          'weekday': slot['weekday'],
          'session_number': slot['session_number'] ?? i + 1,
          'start_time': slot['start_time'],
          'end_time': slot['end_time'],
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> classSchedule(int classId) async =>
      (await database).query(
        'class_sessions',
        where: 'class_id=?',
        whereArgs: [classId],
        orderBy: 'weekday, start_time, session_number',
      );
  Future<void> inviteStudent(int classId, String email) async {
    final db = await database;
    var rows = await db.query('students', where: 'email=?', whereArgs: [email]);
    final id = rows.isEmpty
        ? await db.insert('students', {
            'name': email.split('@').first,
            'email': email,
          })
        : rows.first['id'] as int;
    await db.insert('enrollments', {
      'class_id': classId,
      'student_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<String> createInviteLink(int classId) async {
    final token =
        '${classId.toRadixString(36)}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
            .toUpperCase();
    await (await database).insert('invitations', {
      'class_id': classId,
      'token': token,
      'created_at': DateTime.now().toIso8601String(),
    });
    return 'https://studafy.app/join/$token';
  }

  Future<List<Map<String, Object?>>> chats([String query = '']) async =>
      (await database).rawQuery(
        "SELECT c.*, (SELECT body FROM messages WHERE chat_id=c.id ORDER BY id DESC LIMIT 1) last_message FROM chats c WHERE contact_name LIKE ? OR context LIKE ? ORDER BY updated_at DESC",
        ['%$query%', '%$query%'],
      );
  Future<List<Map<String, Object?>>> messages(int chatId) async =>
      (await database).rawQuery(
        'SELECT m.*, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'message\' AND x.owner_id=m.id) attachment_count FROM messages m WHERE m.chat_id=? ORDER BY m.id ASC',
        [chatId],
      );
  Future<int> sendMessage(int chatId, String body) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('messages', {
      'chat_id': chatId,
      'body': body,
      'sent_by_me': 1,
      'created_at': now,
    });
    await db.update(
      'chats',
      {'updated_at': now},
      where: 'id=?',
      whereArgs: [chatId],
    );
    return id;
  }

  Future<void> saveAttendance(
    int classId,
    Map<int, bool> values, [
    DateTime? date,
  ]) async {
    final db = await database;
    final day = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    await db.transaction((txn) async {
      for (final e in values.entries) {
        await txn.insert('attendance', {
          'class_id': classId,
          'student_id': e.key,
          'day': day,
          'present': e.value ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<Map<int, bool>> attendanceFor(int classId, DateTime date) async {
    final rows = await (await database).query(
      'attendance',
      where: 'class_id=? AND day=?',
      whereArgs: [classId, date.toIso8601String().substring(0, 10)],
    );
    return {
      for (final row in rows)
        row['student_id'] as int: (row['present'] as int) == 1,
    };
  }

  Future<List<Map<String, Object?>>> attendanceForStudent(
    int studentId,
  ) async => (await database).rawQuery(
    '''SELECT a.*, c.name class_name, c.grade, c.section, c.color
       FROM attendance a
       JOIN classes c ON c.id=a.class_id
       WHERE a.student_id=?
       ORDER BY a.day DESC''',
    [studentId],
  );

  Future<Map<String, Object?>> profile() async => (await database)
      .query('teacher_profile', where: 'id=1')
      .then((v) => v.first);
  Future<void> updateProfile(Map<String, Object?> values) async {
    await (await database).update('teacher_profile', values, where: 'id=1');
  }

  Future<List<Map<String, Object?>>> notifications() async =>
      (await database).query('notifications', orderBy: 'is_read ASC, id DESC');
  Future<void> markNotificationsRead() async {
    await (await database).update('notifications', {'is_read': 1});
  }

  Future<int> saveNotebook(
    int classId,
    String lesson,
    String homework, [
    DateTime? date,
    int sessionNumber = 1,
  ]) async {
    final db = await database;
    final day = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    final existing = await db.query(
      'lesson_notes',
      columns: ['id'],
      where: 'class_id=? AND day=? AND session_number=?',
      whereArgs: [classId, day, sessionNumber],
    );
    final values = {
      'class_id': classId,
      'day': day,
      'session_number': sessionNumber,
      'lesson': lesson,
      'homework': homework,
    };
    if (existing.isEmpty) return db.insert('lesson_notes', values);
    final id = existing.first['id'] as int;
    await db.update('lesson_notes', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<int> addAssessment(Map<String, Object?> value) async =>
      (await database).insert('assessments', value);

  Future<void> prepareAssessmentRoster(int assessmentId, int classId) async {
    final db = await database;
    final students = await db.query(
      'enrollments',
      columns: ['student_id'],
      where: 'class_id=?',
      whereArgs: [classId],
    );
    for (final student in students) {
      await db.insert('assessment_submissions', {
        'assessment_id': assessmentId,
        'student_id': student['student_id'],
        'answer_text': null,
        'submitted_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Map<String, Object?>>> attendanceDates(int classId) async =>
      (await database).rawQuery(
        'SELECT day, COUNT(*) total, SUM(present) present FROM attendance WHERE class_id=? GROUP BY day ORDER BY day DESC',
        [classId],
      );
  Future<Map<int, Map<String, String?>>> attendanceDetails(
    int classId,
    DateTime date,
  ) async {
    final rows = await (await database).query(
      'attendance',
      where: 'class_id=? AND day=?',
      whereArgs: [classId, date.toIso8601String().substring(0, 10)],
    );
    return {
      for (final row in rows)
        row['student_id'] as int: {
          'status':
              row['status'] as String? ??
              ((row['present'] as int) == 1 ? 'present' : 'absent'),
          'reason': row['reason'] as String?,
        },
    };
  }

  Future<void> saveAttendanceDetails(
    int classId,
    DateTime date,
    Map<int, Map<String, String?>> values,
  ) async {
    final db = await database, day = date.toIso8601String().substring(0, 10);
    await db.transaction((txn) async {
      for (final entry in values.entries) {
        final status = entry.value['status'] ?? 'present';
        await txn.insert('attendance', {
          'class_id': classId,
          'student_id': entry.key,
          'day': day,
          'present': status == 'present' || status == 'tardy' ? 1 : 0,
          'status': status,
          'reason': entry.value['reason'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, Object?>>> notebooksForClass(int classId) async =>
      (await database).rawQuery(
        'SELECT n.*, (SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'notebook\' AND x.owner_id=n.id) attachment_count FROM lesson_notes n WHERE n.class_id=? ORDER BY n.day DESC, n.session_number',
        [classId],
      );

  Future<List<Map<String, Object?>>> missingNotebookSessionsThisWeek(
    int classId,
  ) async {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final schedule = await classSchedule(classId);
    final missing = <Map<String, Object?>>[];
    for (final slot in schedule) {
      final date = monday.add(Duration(days: (slot['weekday'] as int) - 1));
      if (date.isAfter(now)) continue;
      final found = await (await database).query(
        'lesson_notes',
        columns: ['id'],
        where: 'class_id=? AND day=? AND session_number=?',
        whereArgs: [
          classId,
          date.toIso8601String().substring(0, 10),
          slot['session_number'],
        ],
      );
      if (found.isEmpty) {
        missing.add({...slot, 'day': date.toIso8601String().substring(0, 10)});
      }
    }
    return missing;
  }

  Future<void> addAttachments(
    String ownerType,
    int ownerId,
    Iterable<Map<String, String>> items,
  ) async {
    final db = await database;
    for (final item in items) {
      await db.insert('attachments', {
        'owner_type': ownerType,
        'owner_id': ownerId,
        'kind': item['kind'],
        'name': item['name'],
        'uri': item['uri'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<String> persistAttachmentFile(String sourcePath, String name) async {
    final root = await getDatabasesPath();
    final folder = Directory(join(root, 'studafy_attachments'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = join(
      folder.path,
      '${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    return (await File(sourcePath).copy(target)).path;
  }

  Future<List<Map<String, Object?>>> attachments(
    String ownerType,
    int ownerId,
  ) async => (await database).query(
    'attachments',
    where: 'owner_type=? AND owner_id=?',
    whereArgs: [ownerType, ownerId],
    orderBy: 'id',
  );
  Future<void> requestConnection(
    String requesterId,
    String studentUniqueId,
  ) async {
    final db = await database;
    final found = await db.query(
      'students',
      where: 'studafy_id=?',
      whereArgs: [studentUniqueId.toUpperCase()],
    );
    if (found.isEmpty) throw StateError('No user found with that Studafy ID');
    await db.insert('connection_requests', {
      'requester_id': requesterId,
      'student_id': found.first['id'],
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> connectionRequests() async =>
      (await database).rawQuery(
        'SELECT r.*,s.name student_name,s.studafy_id FROM connection_requests r JOIN students s ON s.id=r.student_id ORDER BY r.id DESC',
      );

  Future<void> updateConnectionStatus(int requestId, String status) async {
    if (!const ['accepted', 'declined'].contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final db = await database;
    await db.transaction((txn) async {
      final before = await txn.query(
        'connection_requests',
        where: 'id=?',
        whereArgs: [requestId],
        limit: 1,
      );
      await txn.update(
        'connection_requests',
        {'status': status},
        where: 'id=?',
        whereArgs: [requestId],
      );
      await txn.insert('audit_events', {
        'actor_key': 'trusted-backend-demo',
        'action': 'guardian_link_$status',
        'entity_type': 'connection_request',
        'entity_id': '$requestId',
        'before_value': before.isEmpty ? null : before.first.toString(),
        'after_value': status,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> auditEvents() async => (await database)
      .query('audit_events', orderBy: 'created_at DESC', limit: 100);

  Future<int> unreadNotificationCount({String userKey = 'demo'}) async {
    final result = await (await database).rawQuery(
      'SELECT COUNT(*) FROM notifications WHERE is_read=0 AND user_key=?',
      [userKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> requestAccountDeletion({String userKey = 'demo'}) async {
    final db = await database;
    final now = DateTime.now().toUtc();
    await db.transaction((txn) async {
      await txn.insert('account_deletion_requests', {
        'user_key': userKey,
        'state': 'grace_period',
        'requested_at': now.toIso8601String(),
        'execute_after': now.add(const Duration(days: 14)).toIso8601String(),
      });
      await txn.insert('audit_events', {
        'actor_key': userKey,
        'action': 'account_deletion_requested',
        'entity_type': 'profile',
        'entity_id': userKey,
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> linkedChildren() async =>
      (await database).rawQuery(
        'SELECT r.*, s.name student_name, s.studafy_id, s.provisional, s.id student_id FROM connection_requests r JOIN students s ON s.id=r.student_id WHERE r.status=\'accepted\' ORDER BY s.name',
      );
  Future<Map<String, Object?>?> studentByStudafyId(String studafyId) async {
    final rows = await (await database).query(
      'students',
      where: 'UPPER(studafy_id)=?',
      whereArgs: [studafyId.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> linkChild(int studentId) async {
    final db = await database;
    final existing = await db.query(
      'connection_requests',
      where: 'requester_id=? AND student_id=?',
      whereArgs: ['PARENT-DEMO', studentId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'connection_requests',
        {'status': 'accepted'},
        where: 'id=?',
        whereArgs: [existing.first['id']],
      );
      return;
    }
    await db.insert('connection_requests', {
      'requester_id': 'PARENT-DEMO',
      'student_id': studentId,
      'status': 'accepted',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> createAndLinkChild({
    required String name,
    required String email,
  }) async {
    final db = await database;
    final id = await db.insert('students', {
      'name': name.trim(),
      'email': email.trim().isEmpty ? null : email.trim(),
      'provisional': 1,
    });
    final uniqueId = 'STU-${id.toString().padLeft(4, '0')}';
    await db.update(
      'students',
      {'studafy_id': uniqueId},
      where: 'id=?',
      whereArgs: [id],
    );
    await linkChild(id);
    return id;
  }

  Future<List<Map<String, Object?>>> studentNotebooks(int studentId) async =>
      (await database).rawQuery(
        'SELECT n.*,c.name class_name,c.grade,c.section,(SELECT COUNT(*) FROM attachments x WHERE x.owner_type=\'notebook\' AND x.owner_id=n.id) attachment_count FROM lesson_notes n JOIN classes c ON c.id=n.class_id JOIN enrollments e ON e.class_id=c.id WHERE e.student_id=? ORDER BY n.day DESC, n.session_number',
        [studentId],
      );
  Future<int> addAssignment(Map<String, Object?> value) async =>
      (await database).insert('assignments', value);
  Future<int> addNotice(Map<String, Object?> value) async =>
      (await database).insert('notices', value);
  Future<int> addBehaviour(Map<String, Object?> value) async =>
      (await database).insert('behaviours', value);
  Future<int> addIncident(Map<String, Object?> value) async =>
      (await database).insert('incidents', value);
}
