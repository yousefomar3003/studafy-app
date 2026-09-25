import 'package:flutter/foundation.dart';

import '../core/device_settings.dart';
import '../core/locale_controller.dart';
import '../core/runtime_environment.dart';
import '../core/studafy_domain.dart';
import '../core/telemetry.dart';
import '../data/settings/preferences_device_settings.dart';
import 'locale_session_binder.dart';
import '../data/backend.dart';
import '../data/billing/v1_billing_api.dart';
import '../data/contracts/v1_http_transport.dart';
import '../data/contracts/v1_client.generated.dart';
import '../data/local_cache/session_cache_binder.dart';
import '../core/secure_storage.dart';
import '../data/secure/keychain_secure_store.dart';
import '../data/subscription_service.dart';
import '../features/notebook/domain/notebook_subscription_repository.dart';
import '../features/account/application/account_interactor.dart';
import '../features/account/data/api_data_export_repository.dart';
import '../features/account/data/api_profile_repository.dart';
import '../features/account/data/session_account_repository.dart';
import '../features/academic/data/api_academic_repository.dart';
import '../features/academic/data/preview_academic_repository.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/data/preview_classroom_repository.dart';
import '../features/classes/data/api_classroom_repository.dart';
import '../features/classes/domain/classroom_repository.dart';
import '../features/family/application/family_interactor.dart';
import '../features/family/data/api_family_repository.dart';
import '../features/family/data/preview_family_repository.dart';
import '../features/messaging/application/messaging_interactor.dart';
import '../features/messaging/data/api_messaging_repository.dart';
import '../features/messaging/data/preview_messaging_repository.dart';
import '../features/notifications/application/notifications_interactor.dart';
import '../features/onboarding/application/teacher_workspace_interactor.dart';
import '../features/study_assistant/application/study_assistant_interactor.dart';
import '../features/study_assistant/data/api_study_assistant_repository.dart';
import '../features/family_insights/application/family_insights_interactor.dart';
import '../features/family_insights/data/api_family_insights_repository.dart';
import '../features/onboarding/data/api_teacher_workspace_repository.dart';
import '../features/notifications/data/api_notifications_repository.dart';
import '../features/notifications/data/preview_notifications_repository.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/files/data/api_file_upload_repository.dart';
import '../features/files/data/preview_file_upload_repository.dart';
import '../features/files/data/signed_upload_transport.dart';
import '../features/files/data/unavailable_file_upload_repository.dart';
import '../core/file_upload_repository.dart';
import '../features/parent/data/preview_parent_repository.dart';
import '../features/parent/data/unavailable_parent_repository.dart';
import '../features/parent/domain/parent_repository.dart';
import '../features/parent/domain/parent_subscription_repository.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/data/demo_session_repository.dart';
import '../features/session/data/api_session_repository.dart';
import '../features/session/domain/session_repository.dart';
import '../features/school_operations/data/api_school_operations_repository.dart';
import '../features/school_operations/data/preview_school_operations_repository.dart';
import '../features/school_operations/domain/school_operations_repository.dart';
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
    this.teacherWorkspace,
    this.studyAssistant,
    this.familyInsights,
    required this.parent,
    required this.teacherDashboard,
    required this.parentSubscription,
    this.notebookSubscription,
    required this.account,
    required this.academicApi,
    required this.academic,
    required this.schoolOperations,
    required this.notifications,
    required this.cacheBinder,
    required this.fileUploads,
    required this.messaging,
    required this.family,
    required this.locale,
    required this.localeSession,
  });

  final SessionInteractor session;
  final ClassListInteractor classes;

  /// Null in synthetic and preview builds, which have no tenant to create.
  final TeacherWorkspaceInteractor? teacherWorkspace;

  /// Null when the build has no backend, and also when the server has no
  /// AI provider configured - the tab is then absent rather than broken.
  final StudyAssistantInteractor? studyAssistant;

  /// Family+. Null without a backend; the paid tab is then absent.
  final FamilyInsightsInteractor? familyInsights;
  final ParentRepository parent;
  final TeacherDashboardRepository teacherDashboard;
  final ParentSubscriptionRepository parentSubscription;
  final NotebookSubscriptionRepository? notebookSubscription;
  final AccountInteractor account;
  final V1ApiClient? academicApi;
  final AcademicRepository academic;
  final SchoolOperationsRepository? schoolOperations;
  final NotificationsInteractor notifications;

  /// Keeps the on-disk cache re-keyed and wiped as the session changes
  /// (MOB-070). Held here, not discarded after construction, so it stays
  /// alive and listening for the app's whole lifetime.
  final SessionCacheBinder cacheBinder;
  final FileUploadRepository fileUploads;

  /// Conversations with report and block controls (MOB-070, SAFE-043).
  final MessagingInteractor messaging;

  /// Guardian home: linked children, link requests, progress and purchase
  /// approvals (MOB-070 parent slice, DL-048/DL-050).
  final FamilyInteractor family;

  /// The interface language (MOB-070, ADR-0028). Held here, like
  /// [cacheBinder], because it must stay alive for the app's whole lifetime:
  /// the root listens to it to rebuild on a language change.
  final LocaleController locale;

  /// Seeds the language from the profile on sign-in. Held so it keeps
  /// listening; null in synthetic builds, which have no profile.
  final LocaleSessionBinder? localeSession;

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
    final cacheBinder = SessionCacheBinder(context: context);
    // A synthetic build has no profile to publish to, so it keeps the choice
    // on the device only. Device settings are read in both, so a developer's
    // language choice survives a restart the same way a user's does.
    final DeviceSettingsStore deviceSettings =
        const PreferencesDeviceSettings();
    final profiles = remote == null ? null : ApiProfileRepository(remote.api);
    final localeController = LocaleController(
      settings: deviceSettings,
      publishToServer: profiles?.updateLocale,
    );
    // Signing in on a new device adopts the language from the profile, but
    // never overrides a choice already made on this one.
    final localeSessionBinder = profiles == null
        ? null
        : LocaleSessionBinder(
            controller: localeController,
            profiles: profiles,
            context: context,
          );
    final NotificationsRepository notificationsRepository = policy.isSynthetic
        ? PreviewNotificationsRepository()
        : ApiNotificationsRepository(remote!.api, cacheBinder);
    final V1BillingApi? billingApi = policy.isSynthetic
        ? null
        : V1BillingApi(
            remote!.transport,
            environment: billingEnvironmentName(policy.environment),
          );
    final messagingAdapter = policy.isSynthetic
        ? PreviewMessagingRepository()
        : null;
    final apiMessaging = remote == null
        ? null
        : ApiMessagingRepository(remote.api);
    final previewFamily = policy.isSynthetic ? PreviewFamilyRepository() : null;
    final apiFamily = remote == null
        ? null
        : ApiFamilyRepository(remote.api, billing: billingApi);
    final subscriptions = StoreSubscriptionRepository(
      billingApi: billingApi,
      pendingStore: remote?.secureStore,
    );
    return AppDependencies(
      family: FamilyInteractor(
        family: previewFamily ?? apiFamily!,
        approvals: previewFamily ?? apiFamily!,
        confirmRecentAuth: () => sessionRepository.confirmRecentAuth(
          ReauthPurpose.billingPurchaseApproval,
        ),
        telemetry: telemetry,
      ),
      messaging: MessagingInteractor(
        messaging: messagingAdapter ?? apiMessaging!,
        safety: messagingAdapter ?? apiMessaging!,
        telemetry: telemetry,
      ),
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
      // Only a real backend can hand out a first membership; a synthetic
      // build has no tenant to create and no server to refuse a second one.
      teacherWorkspace: remote == null
          ? null
          : TeacherWorkspaceInteractor(
              repository: ApiTeacherWorkspaceRepository(remote.api),
              telemetry: telemetry,
            ),
      studyAssistant: remote == null
          ? null
          : StudyAssistantInteractor(
              repository: ApiStudyAssistantRepository(remote.api),
              telemetry: telemetry,
            ),
      familyInsights: remote == null
          ? null
          : FamilyInsightsInteractor(
              repository: ApiFamilyInsightsRepository(remote.api),
              telemetry: telemetry,
            ),
      parent: parentRepository,
      teacherDashboard: teacherDashboardRepository,
      parentSubscription: subscriptions,
      notebookSubscription: subscriptions,
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
        exports: remote == null
            ? null
            : ApiDataExportRepository(
                remote.api,
                confirmRecentAuth: () => sessionRepository.confirmRecentAuth(
                  ReauthPurpose.accountDataExport,
                ),
              ),
      ),
      academicApi: remote?.api,
      academic: remote == null
          ? PreviewAcademicRepository()
          : ApiAcademicRepository(remote.api, context: context),
      schoolOperations: remote == null
          ? PreviewSchoolOperationsRepository()
          : ApiSchoolOperationsRepository(remote.api, context: context),
      notifications: NotificationsInteractor(
        repository: notificationsRepository,
        telemetry: telemetry,
      ),
      cacheBinder: cacheBinder,
      locale: localeController,
      localeSession: localeSessionBinder,
      // FILE-051's scanning and delivery gate has passed, so a remote build
      // now sends real bytes through the real pipeline. A build with no API
      // client still has nowhere to send them, and says so rather than
      // pretending an upload succeeded.
      fileUploads: policy.isSynthetic
          ? const PreviewFileUploadRepository()
          : (remote == null || !policy.allowsRemoteFileUploads
                ? const UnavailableFileUploadRepository()
                : ApiFileUploadRepository(
                    remote.api,
                    IoSignedUploadTransport(),
                  )),
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
      secureStore: secureStore,
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
    required this.secureStore,
    required this.session,
  });
  final V1ApiClient api;
  final V1JsonTransport transport;
  final SecureStore secureStore;
  final SessionRepository session;
}
