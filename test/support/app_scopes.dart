import 'package:flutter/widgets.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/app/app_dependencies.dart';
import 'package:studafy/app/session_scope.dart';
import 'package:studafy/core/uploads_scope.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/meetings/presentation/meetings_scope.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';

/// The scopes `lib/main.dart` puts above every screen, from one set of
/// dependencies, for widget tests that render a whole shell.
Widget appScopes(AppDependencies deps, Widget child) => SessionScope(
  session: deps.session,
  child: AccountScope(
    account: deps.account,
    child: UploadsScope(
      uploads: deps.fileUploads,
      child: MeetingsScope(
        repository: deps.meetings,
        child: NotificationsScope(
          interactor: deps.notifications,
          child: MessagingScope(
            interactor: deps.messaging,
            child: FamilyScope(interactor: deps.family, child: child),
          ),
        ),
      ),
    ),
  ),
);
