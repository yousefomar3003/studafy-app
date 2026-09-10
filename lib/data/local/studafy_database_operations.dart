part of '../../studafy_database.dart';

mixin _StudafyOperationsQueries on _StudafyDatabaseAccess {
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
}
