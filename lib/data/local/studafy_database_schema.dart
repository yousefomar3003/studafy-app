part of '../../studafy_database.dart';

mixin _StudafySchema on _StudafyDatabaseAccess {
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

  Future<void> _createQuestionGradeTables(Database db) async {
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
}
