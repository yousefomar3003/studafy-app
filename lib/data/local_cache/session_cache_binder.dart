import 'dart:async';

import '../../core/studafy_domain.dart';
import 'cache_scope.dart';
import 'offline_cache_database.dart';
import 'offline_cache_store.dart';

/// Serializes cache opens and identity transitions. A sign-out/account switch
/// erases all of the departed user's school files before another scope opens.
class SessionCacheBinder {
  SessionCacheBinder({ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance {
    _scope = _scopeFor(_context);
    _tail = OfflineCacheDatabase.retireLegacyCaches();
    _context.addListener(_onContextChanged);
    unawaited(_tail.catchError((Object _) {}));
  }

  final ActiveContextController _context;
  CacheScope? _scope;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  Future<void> get settled => _tail;

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
    _tail = _tail.then((_) async {
      if (next == null || next.userId != previous.userId) {
        await OfflineCacheDatabase.wipeUser(previous.userId);
      } else {
        await (await OfflineCacheDatabase.open(previous)).close();
      }
    });
    // Keep the failed future on the chain: subsequent opens fail closed.
    // Attach an error listener because ChangeNotifier cannot await cleanup.
    unawaited(_tail.catchError((Object _) {}));
  }

  Future<OfflineCacheStore?> currentStore() {
    final scope = _scope;
    final operation = _tail.then((_) async {
      if (_disposed || scope == null || scope != _scope) return null;
      final db = await OfflineCacheDatabase.open(scope);
      if (_disposed || scope != _scope) return null;
      return OfflineCacheStore(db);
    });
    _tail = operation.then<void>((_) {});
    unawaited(_tail.catchError((Object _) {}));
    return operation;
  }

  void dispose() {
    _disposed = true;
    _context.removeListener(_onContextChanged);
  }
}
