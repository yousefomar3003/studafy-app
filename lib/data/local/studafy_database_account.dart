part of '../../studafy_database.dart';

mixin _StudafyAccountQueries on _StudafyDatabaseAccess {
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
