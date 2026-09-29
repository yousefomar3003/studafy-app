import 'dart:convert';

import '../contracts/response_cache.dart';
import 'offline_cache_store.dart';
import 'session_cache_binder.dart';

/// [ResponseCache] in the account's own cache file (MOB-070): per user and
/// school, and erased with the rest of the account's cache at sign-out or
/// when another account takes over the device.
class OfflineResponseCache implements ResponseCache {
  OfflineResponseCache(this._binder, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SessionCacheBinder _binder;
  final DateTime Function() _now;

  static const _type = 'api_response';

  /// Larger answers are not kept: they would crowd out everything else and
  /// the reads that return them are paged.
  static const maxBodyChars = 2 * 1024 * 1024;

  Future<OfflineCacheStore?> _store() => _binder.currentStore();

  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      (await (await _store())?.entity(_type, key))?.payload;

  @override
  Future<void> write(String key, Map<String, dynamic> body) async {
    final store = await _store();
    if (store == null) return;
    if (jsonEncode(body).length > maxBodyChars) return;
    await store.putEntities(_type, [
      CachedEntity(
        entityId: key,
        payload: body,
        updatedAt: _now().toUtc().toIso8601String(),
      ),
    ]);
  }
}
