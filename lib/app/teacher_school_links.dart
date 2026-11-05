import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/studafy_domain.dart';
import '../features/school_portal/application/school_links_interactor.dart';
import '../features/school_portal/presentation/school_link_banner.dart';
import '../features/school_portal/presentation/school_link_request_page.dart';
import '../features/school_portal/presentation/schools_page.dart';
import 'app_dependencies.dart';

/// [links] while the server runs the School Portal (GET /v1/me says so),
/// or null: then nothing of it appears.
SchoolLinksInteractor? schoolLinksWhenOn(
  UserProfile? profile,
  SchoolLinksInteractor? links,
) => profile?.schoolPortal == true ? links : null;

/// The signed-in teacher's School Portal links, or null.
SchoolLinksInteractor? teacherSchoolLinks(AppDependencies deps) =>
    schoolLinksWhenOn(
      ActiveContextController.instance.profile,
      deps.schoolLinks,
    );

/// "Your classes are visible to (the school)." for the Today tab, or null.
Widget? teacherSchoolBanner(AppDependencies deps) =>
    switch (teacherSchoolLinks(deps)) {
      final links? => SchoolLinkBanner(links: links),
      null => null,
    };

/// The Classes tab's header with the same banner under it.
Widget withSchoolBanner(Widget header, AppDependencies deps) =>
    switch (teacherSchoolBanner(deps)) {
      final banner? => Column(
        children: [
          header,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
            child: banner,
          ),
        ],
      ),
      null => header,
    };

/// Where a tapped "a school asked to link" notification goes: the request
/// itself, or the Schools list when it names none.
void Function(String? linkId)? openSchoolLinkFrom(
  BuildContext context,
  AppDependencies deps,
) {
  final links = teacherSchoolLinks(deps);
  if (links == null) return null;
  return (linkId) => Navigator.of(context).pushOnce(
    MaterialPageRoute<void>(
      builder: (_) => linkId == null
          ? SchoolsPage(links: links)
          : SchoolLinkRequestPage(links: links, linkId: linkId),
    ),
  );
}
