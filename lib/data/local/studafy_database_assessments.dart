part of '../../studafy_database.dart';

mixin _StudafyAssessmentQueries on _StudafyDatabaseAccess {
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
}
