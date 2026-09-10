part of '../../studafy_database.dart';

mixin _StudafyLearningQueries on _StudafyDatabaseAccess {
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
}
