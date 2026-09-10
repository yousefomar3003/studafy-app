import 'package:flutter/foundation.dart';

import '../core/runtime_environment.dart';
import '../core/studafy_domain.dart';
import '../core/telemetry.dart';
import '../data/subscription_service.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/data/preview_classroom_repository.dart';
import '../features/classes/data/supabase_classroom_repository.dart';
import '../features/classes/domain/classroom_repository.dart';
import '../features/parent/data/preview_parent_repository.dart';
import '../features/parent/data/unavailable_parent_repository.dart';
import '../features/parent/domain/parent_repository.dart';
import '../features/parent/domain/parent_subscription_repository.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/data/demo_session_repository.dart';
import '../features/session/data/supabase_session_repository.dart';
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
  });

  final SessionInteractor session;
  final ClassListInteractor classes;
  final ParentRepository parent;
  final TeacherDashboardRepository teacherDashboard;
  final StudyCoachInteractor studyCoach;
  final ParentSubscriptionRepository parentSubscription;

  static AppDependencies forPolicy(RuntimePolicy policy) {
    final telemetry = const DebugLogTelemetry();
    final context = ActiveContextController.instance;
    final SessionRepository sessionRepository = policy.isSynthetic
        ? const DemoSessionRepository()
        : SupabaseSessionRepository();
    final ClassroomRepository classroomRepository = policy.isSynthetic
        ? const PreviewClassroomRepository()
        : SupabaseClassroomRepository();
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
      parentSubscription: StoreSubscriptionRepository(),
    );
  }
}
