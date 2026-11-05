import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/teacher_school_links.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/school_portal/application/school_links_interactor.dart';
import 'package:studafy/features/school_portal/domain/school_links.dart';

class _Nothing implements SchoolLinksRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _teacher({required bool schoolPortal}) => UserProfile(
  id: 'teacher-1',
  displayName: 'Rania Haddad',
  email: 'rania@example.test',
  memberships: const [],
  schoolPortal: schoolPortal,
);

void main() {
  final links = SchoolLinksInteractor(
    links: _Nothing(),
    telemetry: const NoopTelemetry(),
  );

  test('the School Portal appears only while the server says it is on', () {
    expect(schoolLinksWhenOn(_teacher(schoolPortal: true), links), links);
    expect(schoolLinksWhenOn(_teacher(schoolPortal: false), links), isNull);
    expect(schoolLinksWhenOn(null, links), isNull);
    // A build with no server has no links to show, whatever the flag.
    expect(schoolLinksWhenOn(_teacher(schoolPortal: true), null), isNull);
  });
}
