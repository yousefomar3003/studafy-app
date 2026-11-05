import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/notifications/domain/notification_target.dart';

/// Each notification opens exactly what it is about, from the ids its own
/// payload carries - and nothing else from the payload.
void main() {
  NotificationTarget? from(String key, Map<String, dynamic> payload) =>
      NotificationTarget.fromPayload(key, payload);

  test('every main kind of notification names the thing it opens', () {
    final cases = <String, (Map<String, dynamic>, NotificationTargetKind)>{
      'communications.message_sent': (
        {'conversationId': 'c1', 'messageId': 'm1'},
        NotificationTargetKind.conversation,
      ),
      'communications.announcement_created': (
        {'id': 'an1', 'title': 'not used', 'body': 'not used'},
        NotificationTargetKind.announcement,
      ),
      'academic.assignment_published': (
        {'entityId': 'w1'},
        NotificationTargetKind.assignment,
      ),
      'academic.assessment_published': (
        {'entityId': 'a1'},
        NotificationTargetKind.assessment,
      ),
      'academic.grades_published': (
        {'entityId': 'a1'},
        NotificationTargetKind.assessmentGrades,
      ),
      'academic.grades_corrected': (
        {'entityId': 'a1'},
        NotificationTargetKind.assessmentGrades,
      ),
      'academic.grade_published': (
        {'entityId': 'g1'},
        NotificationTargetKind.grade,
      ),
      'academic.resource_published': (
        {'entityId': 'r1'},
        NotificationTargetKind.resource,
      ),
      'academic.wellbeing_shared': (
        {'entityId': 'wb1'},
        NotificationTargetKind.wellbeing,
      ),
      'meetings.scheduled': (
        {'meetingId': 'mt1'},
        NotificationTargetKind.meeting,
      ),
      'meetings.requested': ({'id': 'mt1'}, NotificationTargetKind.meeting),
      'family.guardian_link_requested': (
        {'id': 'l1', 'studentId': 's1'},
        NotificationTargetKind.guardianLink,
      ),
      'school_portal.link_requested': (
        {'id': 'sl1'},
        NotificationTargetKind.schoolLink,
      ),
      'billing.subscription_renewed': (
        {'featureKey': 'studafy_plus'},
        NotificationTargetKind.plan,
      ),
      'safety.report_resolved': (
        {'reportId': 'rp1', 'resolution': 'x'},
        NotificationTargetKind.report,
      ),
    };
    for (final MapEntry(:key, value: (payload, kind)) in cases.entries) {
      final target = from(key, payload);
      expect(target?.kind, kind, reason: key);
      expect(NotificationTarget.kindOf(key), kind, reason: key);
      expect(NotificationTarget.parse(target!.route)?.id, target.id);
    }
    expect(
      from('communications.message_sent', {'conversationId': 'c1'})!.id,
      'c1',
    );
  });

  test('a kind with nowhere to go, or a payload without a plain id, opens '
      'nothing', () {
    expect(from('invitations.issued', {'id': 'i1'}), isNull);
    expect(NotificationTarget.kindOf('support_access.requested'), isNull);
    expect(from('academic.assignment_published', {}), isNull);
    for (final bad in ['', '../x', 'a b', 'x' * 65, 42]) {
      expect(
        from('academic.assignment_published', {'entityId': bad}),
        isNull,
        reason: '$bad',
      );
    }
    expect(NotificationTarget.parse('nonsense:1'), isNull);
    expect(NotificationTarget.parse('assignment:'), isNull);
    expect(NotificationTarget.parse(null), isNull);
  });
}
