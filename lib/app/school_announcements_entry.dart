import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/studafy_domain.dart';
import '../features/school_portal/presentation/school_announcements_page.dart';
import 'account_scope.dart';

/// Opens "From your school" from a tapped notification or the account
/// screen, while the server runs the School Portal; null otherwise.
VoidCallback? openSchoolAnnouncementsIn(BuildContext context) {
  final links = AccountScope.schoolLinksOf(context);
  if (links == null ||
      ActiveContextController.instance.profile?.schoolPortal != true) {
    return null;
  }
  return () => Navigator.of(context).pushOnce(
    MaterialPageRoute<void>(
      builder: (_) => SchoolAnnouncementsPage(links: links),
    ),
  );
}
