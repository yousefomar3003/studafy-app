import '../core/locale_controller.dart';
import '../core/studafy_domain.dart';
import '../features/account/domain/profile_repository.dart';

/// Seeds the interface language from the profile when a user signs in
/// (MOB-070, ADR-0028).
///
/// Composition-root wiring, like [SessionCacheBinder]: the locale controller
/// knows nothing about sessions, and the session slice knows nothing about
/// language.
///
/// It only ever *seeds*. A device that has been told which language to use
/// keeps its own choice — [LocaleController.adoptServerLocale] enforces that —
/// so switching language on one phone never flips another mid-session.
class LocaleSessionBinder {
  LocaleSessionBinder({
    required this.controller,
    required this.profiles,
    ActiveContextController? context,
  }) : _context = context ?? ActiveContextController.instance {
    _context.addListener(_onContextChanged);
  }

  final LocaleController controller;
  final ProfileRepository profiles;
  final ActiveContextController _context;

  /// Profiles already seeded, so re-entering a session does not re-read, and
  /// an account switch seeds the arriving user exactly once.
  final Set<String> _seeded = {};

  void _onContextChanged() {
    final profile = _context.profile;
    if (profile == null || !_seeded.add(profile.id)) return;
    // Deliberately not awaited: sign-in must not block on this, and a failure
    // leaves the device showing the language it already had.
    _seed();
  }

  Future<void> _seed() async {
    if (!controller.followsDevice) return;
    await controller.adoptServerLocale(await profiles.readLocale());
  }

  void dispose() => _context.removeListener(_onContextChanged);
}
