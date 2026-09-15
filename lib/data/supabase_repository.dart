import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/studafy_domain.dart';
import 'backend.dart';
import 'studafy_repository.dart';

/// Production repository. All privileged mutations are delegated to audited
/// Edge Functions; the mobile client never receives a service-role key.
class SupabaseStudafyRepository
    implements StudafyRepository, MeetingRepository {
  SupabaseClient get _client => StudafyBackend.client;

  @override
  Future<UserProfile?> currentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profile = await _client
        .from('profiles')
        .select(
          'id, display_name, memberships(id, school_id, role, active, schools(name))',
        )
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) return null;
    final memberships = (profile['memberships'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (row) => SchoolMembership(
            id: row['id'] as String,
            schoolId: row['school_id'] as String,
            schoolName:
                ((row['schools'] as Map<String, dynamic>?)?['name']
                    as String?) ??
                'School',
            role: _role(row['role'] as String),
            active: row['active'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
    return UserProfile(
      id: user.id,
      displayName: profile['display_name'] as String,
      email: user.email ?? '',
      memberships: memberships,
    );
  }

  @override
  Future<List<StudentSummary>> linkedStudents() async {
    final rows = await _client
        .from('guardian_links')
        .select('status, students(id, studafy_id, display_name, provisional)')
        .eq('status', 'verified');
    return rows
        .map((row) {
          final student = row['students'] as Map<String, dynamic>;
          return StudentSummary(
            id: student['id'] as String,
            studafyId: student['studafy_id'] as String,
            displayName: student['display_name'] as String,
            verified: !(student['provisional'] as bool? ?? true),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<int> unreadNotificationCount() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);
    return rows.length;
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Authentication required');
    await _client.rpc('mark_notifications_read');
  }

  @override
  Future<void> requestAccountDeletion({required String confirmation}) async {
    if (confirmation != 'DELETE') {
      throw ArgumentError.value(confirmation, 'confirmation');
    }
    await _invoke('request-account-deletion', {'confirmation': confirmation});
  }

  @override
  Future<Uri> createGoogleMeet({
    required String classroomId,
    required String title,
    required DateTime startsAt,
    required Duration duration,
    required MeetingAudience audience,
  }) async {
    final data = await _invoke('create-google-meet', {
      'classroom_id': classroomId,
      'title': title,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': startsAt.add(duration).toUtc().toIso8601String(),
      'audience': audience.name,
    });
    final url = data['meet_url'] as String?;
    if (url == null) throw StateError('Meet creation returned no URL');
    return Uri.parse(url);
  }

  @override
  Future<void> cancelMeeting(String meetingId) async {
    await _invoke('cancel-google-meet', {'meeting_id': meetingId});
  }

  /// The contained proposal source remains unavailable until AI-072.
  Future<AiGradingDraft> proposeGrade({
    required String submissionId,
    required Uri privateScan,
    required GradingStrictness strictness,
  }) async {
    throw StateError('AI grading is temporarily unavailable.');
  }

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(name, body: body);
    if (response.status < 200 || response.status >= 300) {
      throw StateError('$name failed (${response.status})');
    }
    return (response.data as Map).cast<String, dynamic>();
  }

  StudafyRole _role(String value) => switch (value) {
    'teacher' => StudafyRole.teacher,
    'parent' => StudafyRole.parent,
    'student' => StudafyRole.student,
    _ => throw StateError('Unsupported role: $value'),
  };
}
