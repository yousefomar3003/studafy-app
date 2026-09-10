import 'package:flutter/foundation.dart';

import '../core/runtime_environment.dart';
import '../core/studafy_domain.dart';
import '../core/telemetry.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/data/preview_classroom_repository.dart';
import '../features/classes/data/supabase_classroom_repository.dart';
import '../features/classes/domain/classroom_repository.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/data/demo_session_repository.dart';
import '../features/session/data/supabase_session_repository.dart';
import '../features/session/domain/session_repository.dart';

/// Composition root (ARC-011). Builds the interactors once, choosing
/// adapters by runtime policy: synthetic builds get the demo/preview pair;
/// remote builds get the Supabase pair. No widget ever constructs a
/// repository or sees an adapter type.
@immutable
class AppDependencies {
  const AppDependencies({required this.session, required this.classes});

  final SessionInteractor session;
  final ClassListInteractor classes;

  static AppDependencies forPolicy(RuntimePolicy policy) {
    final telemetry = const DebugLogTelemetry();
    final context = ActiveContextController.instance;
    final SessionRepository sessionRepository = policy.isSynthetic
        ? const DemoSessionRepository()
        : SupabaseSessionRepository();
    final ClassroomRepository classroomRepository = policy.isSynthetic
        ? const PreviewClassroomRepository()
        : SupabaseClassroomRepository();
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
    );
  }
}
