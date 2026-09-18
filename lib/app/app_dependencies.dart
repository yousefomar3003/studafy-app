import 'package:flutter/foundation.dart';

import '../core/runtime_environment.dart';
import '../core/studafy_domain.dart';
import '../core/telemetry.dart';
import '../data/backend.dart';
import '../data/billing/v1_billing_api.dart';
import '../data/contracts/v1_http_transport.dart';
import '../data/contracts/v1_client.generated.dart';
import '../data/local_cache/session_cache_binder.dart';
import '../data/secure/keychain_secure_store.dart';
import '../data/subscription_service.dart';
import '../features/account/application/account_interactor.dart';
import '../features/account/data/session_account_repository.dart';
import '../features/academic/data/api_academic_repository.dart';
import '../features/academic/data/preview_academic_repository.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/data/preview_classroom_repository.dart';
import '../features/classes/data/api_classroom_repository.dart';
import '../features/classes/domain/classroom_repository.dart';
import '../features/notifications/application/notifications_interactor.dart';
import '../features/notifications/data/api_notifications_repository.dart';
import '../features/notifications/data/preview_notifications_repository.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/files/data/preview_file_upload_repository.dart';
import '../features/files/data/unavailable_file_upload_repository.dart';
import '../features/files/domain/file_upload_repository.dart';
import '../features/parent/data/preview_parent_repository.dart';
import '../features/parent/data/unavailable_parent_repository.dart';
import '../features/parent/domain/parent_repository.dart';
import '../features/parent/domain/parent_subscription_repository.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/data/demo_session_repository.dart';
import '../features/session/data/api_session_repository.dart';
import '../features/session/domain/session_repository.dart';
import '../features/study_coach/application/study_coach_interactor.dart';
import '../features/study_coach/data/supabase_study_coach_repository.dart';
import '../features/study_coach/data/unavailable_study_coach_repository.dart';
import '../features/teacher_dashboard/data/preview_teacher_dashboard_repository.dart';
import '../features/teacher_dashboard/data/unavailable_teacher_dashboard_repository.dart';
import '../features/teacher_dashboard/domain/teacher_dashboard_repository.dart';

/// Composition root (ARC-011). Builds the interactors once, choosing
/// adapters by runtime policy: synthetic builds get the demo/preview pair;
/// remote builds get the Supabase pair. No widget ever constructs a
/// repository or sees an adapter type.
@immutable
class AppDependencies {
  const AppDependencies({
    required this.session,
    required this.classes,
    required this.parent,
    required this.teacherDashboard,
    required this.studyCoach,
    required this.parentSubscription,
    required this.account,
    required this.academicApi,
    required this.academic,
    required this.notifications,
    required this.cacheBinder,
    required this.fileUploads,
  });

  final SessionInteractor session;
  final ClassListInteractor classes;
  final ParentRepository parent;
  final TeacherDashboardRepository teacherDashboard;
  final StudyCoachInteractor studyCoach;
  final ParentSubscriptionRepository parentSubscription;
  final AccountInteractor account;
  final V1ApiClient? academicApi;
  final AcademicRepository academic;
  final NotificationsInteractor notifications;

  /// Keeps the on-disk cache re-keyed and wiped as the session changes
  /// (MOB-070). Held here, not discarded after construction, so it stays
  /// alive and listening for the app's whole lifetime.
  final SessionCacheBinder cacheBinder;
  final FileUploadRepository fileUploads;

  static AppDependencies forPolicy(RuntimePolicy policy) {
    final telemetry = const DebugLogTelemetry();
    final context = ActiveContextController.instance;
    final remote = policy.isSynthetic ? null : _remoteClients();
    final SessionRepository sessionRepository = policy.isSynthetic
        ? const DemoSessionRepository()
        : remote!.session;
    final ClassroomRepository classroomRepository = policy.isSynthetic
        ? const PreviewClassroomRepository()
        : ApiClassroomRepository(remote!.api, context: context);
    final ParentRepository parentRepository = policy.isSynthetic
        ? const PreviewParentRepository()
        : const UnavailableParentRepository();
    final TeacherDashboardRepository teacherDashboardRepository =
        policy.isSynthetic
        ? const PreviewTeacherDashboardRepository()
        : const UnavailableTeacherDashboardRepository();
    final studyCoachRepository = policy.isSynthetic
        ? const UnavailableStudyCoachRepository()
        : const SupabaseStudyCoachRepository();
    final cacheBinder = SessionCacheBinder(context: context);
    final NotificationsRepository notificationsRepository = policy.isSynthetic
        ? PreviewNotificationsRepository()
        : ApiNotificationsRepository(remote!.api, cacheBinder);
    final V1BillingApi? billingApi = policy.isSynthetic
        ? null
        : V1BillingApi(
            remote!.transport,
            environment: billingEnvironmentName(policy.environment),
          );
    return AppDependencies(
      session: SessionInteractor(
        repository: sessionRepository,
        context: context,
        telemetry: telemetry,
        runtimePolicy: policy,
      ),
      classes: ClassListInteractor(
        repository: classroomRepository,
        telemetry: telemetry,
      ),
      parent: parentRepository,
      teacherDashboard: teacherDashboardRepository,
      studyCoach: StudyCoachInteractor(repository: studyCoachRepository),
      parentSubscription: StoreSubscriptionRepository(billingApi: billingApi),
      // Cross-feature wiring belongs here, not in either feature: the account
      // slice gets the session's deletion operations as plain functions.
      account: AccountInteractor(
        policy.isSynthetic
            ? const UnavailableAccountRepository()
            : SessionAccountRepository(
                loadImpact: sessionRepository.deletionImpact,
                submitRequest: sessionRepository.requestAccountDeletion,
                cancelRequest: sessionRepository.cancelAccountDeletion,
              ),
      ),
      academicApi: remote?.api,
      academic: remote == null
          ? PreviewAcademicRepository()
          : ApiAcademicRepository(remote.api, context: context),
      notifications: NotificationsInteractor(
        repository: notificationsRepository,
        telemetry: telemetry,
      ),
      cacheBinder: cacheBinder,
      // FILE-050 ships the typed client but does not activate remote bytes.
      // FILE-051 will replace this remote adapter only after scanning and
      // clean delivery pass their gate.
      fileUploads: policy.isSynthetic
          ? const PreviewFileUploadRepository()
          : const UnavailableFileUploadRepository(),
    );
  }

  /// Builds the API-backed session adapter (AUTH-030).
  ///
  /// Fails closed: a remote build with no configured API has nothing that can
  /// verify a token or resolve a role, and the client must never decide
  /// authority for itself in that situation.
  static _RemoteClients _remoteClients() {
    final config = BackendConfig.fromEnvironment;
    if (!config.hasApi) {
      throw StateError(
        'Remote builds require STUDAFY_API_URL: authority is server-derived '
        '(AUTH-030). Provide it with --dart-define.',
      );
    }
    final secureStore = StudafyBackend.secureStore ?? KeychainSecureStore();
    final transport = V1HttpTransport(
      baseUri: Uri.parse(config.apiUrl),
      accessToken: () async =>
          StudafyBackend.client.auth.currentSession?.accessToken,
      refreshSession: () async {
        try {
          final refreshed = await StudafyBackend.client.auth.refreshSession();
          return refreshed.session != null;
        } catch (_) {
          return false;
        }
      },
      onSessionLost: () {
        // The controller is the observable state holder; clearing it moves
        // every listening screen out of a signed-in layout at once.
        ActiveContextController.instance.signOut();
      },
    );
    return _RemoteClients(
      api: V1ApiClient(transport),
      transport: transport,
      session: ApiSessionRepository(
        transport: transport,
        secureStore: secureStore,
      ),
    );
  }
}

class _RemoteClients {
  const _RemoteClients({
    required this.api,
    required this.transport,
    required this.session,
  });
  final V1ApiClient api;
  final V1JsonTransport transport;
  final SessionRepository session;
}
