import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../data/backend.dart';
import '../domain/classroom.dart';
import '../domain/classroom_repository.dart';

/// Remote adapter over PostgREST (RLS-scoped): the teacher sees exactly the
/// classrooms `can_access_classroom` allows. Write paths are not available
/// until the classes service exists; they fail closed with typed failures.
class SupabaseClassroomRepository implements ClassroomRepository {
  SupabaseClient get _client => StudafyBackend.client;

  @override
  Future<List<ClassroomSummary>> listClasses() async {
    final rows = await _client
        .from('classrooms')
        .select(
          'id, name, grade, section, archived_at, terms(name), '
          'enrollments(count)',
        )
        .isFilter('archived_at', null)
        .order('name');
    return [
      for (final row in rows)
        ClassroomSummary(
          id: ClassroomId(row['id'] as String),
          name: row['name'] as String,
          grade: '${row['grade'] ?? ''}',
          section: '${row['section'] ?? ''}',
          room: null,
          colorValue: null,
          studentCount: _countFor(row['enrollments']),
          weeklySessions: null,
          termName: (row['terms'] as Map<String, dynamic>?)?['name'] as String?,
        ),
    ];
  }

  @override
  Future<void> createClass(NewClassDraft draft) async {
    throw const Failure.unsupported(
      'Creating classes will be available once the classes service launches.',
    );
  }

  @override
  Future<String> inviteLinkFor(ClassroomId id) async {
    throw const Failure.unsupported(
      'Inviting students will be available once the classes service launches.',
    );
  }

  static int _countFor(Object? aggregated) {
    final rows = aggregated as List<dynamic>? ?? const [];
    if (rows.isEmpty) return 0;
    return (rows.first as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
