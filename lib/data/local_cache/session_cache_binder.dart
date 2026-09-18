import 'dart:async';

import '../../core/studafy_domain.dart';
import 'cache_scope.dart';
import 'offline_cache_database.dart';
import 'offline_cache_store.dart';

/// Keeps the on-disk cache in step with who is signed in (MOB-070).
///
/// Registered once at the composition root against
/// [ActiveContextController.instance]. It never decides *what* to cache —
/// that is each feature repository's job — only *whose* cache is currently
/// open:
///  - switching school or role while still signed in re-keys: the old
///    scope's file is closed (not deleted, it is still a valid cache for
///    that membership) and the new scope's file is opened lazily;
///  - signing out wipes: the scope that was active is deleted outright, so
///    no cached record of a departed session survives on disk.
class SessionCacheBinder {
  SessionCacheBinder({ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance {
    _scope = _scopeFor(_context);
    _context.addListener(_onContextChanged);
  }

  final ActiveContextController _context;
  CacheScope? _scope;

  static CacheScope? _scopeFor(ActiveContextController context) {
    final profile = context.profile;
    final membership = context.membership;
    if (profile == null || membership == null) return null;
    return CacheScope(userId: profile.id, schoolId: membership.schoolId);
  }

  void _onContextChanged() {
    final next = _scopeFor(_context);
    final previous = _scope;
    if (next == previous) return;
    _scope = next;
    if (previous == null) return;
    if (next == null) {
      // Signed out: the departed scope's cache must not outlive the session.
      unawaited(OfflineCacheDatabase.wipe(previous));
    } else {
      // Switched membership/role/account while still signed in: the old
      // cache is still legitimate for its own scope, just not active now.
      unawaited(OfflineCacheDatabase.open(previous).then((db) => db.close()));
    }
  }

  /// Resolves the store for whoever is signed in right now. Feature
  /// repositories call this on every operation rather than caching the
  /// result, so a mid-session switch is picked up automatically instead of
  /// silently writing into an about-to-be-closed scope.
  Future<OfflineCacheStore?> currentStore() async {
    final scope = _scope;
    if (scope == null) return null;
    return OfflineCacheStore(await OfflineCacheDatabase.open(scope));
  }

  void dispose() => _context.removeListener(_onContextChanged);
}
