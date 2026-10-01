import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account/role_switcher.dart';
import 'package:studafy/core/studafy_domain.dart';

/// One kind of account per email: a teacher may also be a parent and moves
/// between the two; a student account has nothing to switch to.
void main() {
  tearDown(ActiveContextController.instance.signOut);

  const teaching = SchoolMembership(
    id: 'm-teacher',
    schoolId: 'own-workspace',
    schoolName: 'Rana Haddad',
    role: StudafyRole.teacher,
    active: true,
  );
  const studying = SchoolMembership(
    id: 'm-student',
    schoolId: 'someone-elses-class',
    schoolName: 'Rara Nana',
    role: StudafyRole.student,
    active: true,
  );

  ActiveContextController signedIn(
    List<SchoolMembership> memberships, {
    SchoolMembership? active,
    required StudafyRole as,
    AccountKind? kind,
  }) => ActiveContextController.instance
    ..hydrate(
      authenticatedProfile: UserProfile(
        id: 'user',
        displayName: 'Someone',
        email: 'someone@example.test',
        memberships: memberships,
        accountKind: kind,
      ),
      activeMembership: active,
      signedInAs: as,
    );

  test('a teacher can move to being a parent', () {
    expect(
      switchableRoles(
        signedIn(const [teaching], active: teaching, as: StudafyRole.teacher),
      ),
      [StudafyRole.parent],
    );
  });

  test('a teacher acting as a parent can move back to teaching, '
      'whatever school the teaching is at', () {
    expect(
      switchableRoles(signedIn(const [teaching], as: StudafyRole.parent)),
      [StudafyRole.teacher],
    );
  });

  test('a parent with no workspace yet is offered teaching too', () {
    expect(
      switchableRoles(
        signedIn(const [], as: StudafyRole.parent, kind: AccountKind.adult),
      ),
      [StudafyRole.teacher],
    );
  });

  test('a student account has nothing to switch to', () {
    expect(
      switchableRoles(
        signedIn(const [studying], active: studying, as: StudafyRole.student),
      ),
      isEmpty,
    );
    expect(
      switchableRoles(
        signedIn(const [], as: StudafyRole.student, kind: AccountKind.student),
      ),
      isEmpty,
    );
  });
}
