import 'package:flutter/widgets.dart';

import '../core/ai_consent.dart';
import '../core/ai_consent_sheet.dart';

/// The AI notice before a student's first AI use, wherever it starts
/// (ADR-0043): the data layer asks the gate, and the gate shows the notice
/// over whatever screen [navigatorKey] has open.
void attachAiConsentGate(
  AiConsentRepository? repository,
  GlobalKey<NavigatorState> navigatorKey,
) {
  AiConsentGate.instance.attach(
    repository: repository,
    ask: () async {
      final navigatorContext = navigatorKey.currentContext;
      if (repository == null || navigatorContext == null) return false;
      return showAiConsentNotice(navigatorContext, repository: repository);
    },
    explainGuardian: () async {
      final navigatorContext = navigatorKey.currentContext;
      if (navigatorContext == null) return;
      await showAiConsentGuardianNeeded(navigatorContext);
    },
  );
}
