part of '../../studafy_database.dart';

mixin _StudafyTeachingQueries on _StudafyDatabaseAccess {
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

  @override
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
}
