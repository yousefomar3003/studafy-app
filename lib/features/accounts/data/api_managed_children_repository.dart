import '../../../core/account_lifecycle.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/device_account.dart';

class ApiManagedChildrenRepository implements ManagedChildrenRepository {
  ApiManagedChildrenRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<List<ManagedChild>> list() => _guard(() async {
    final page = await _client.listManagedChildren();
    return [for (final item in page.items) _child(item)];
  });

  @override
  Future<ManagedChild> create({
    required String displayName,
    required String locale,
  }) => _guard(() async {
    final created = await _client.createManagedChild(
      V1CreateManagedChildRequestDto(
        displayName: displayName,
        policyVersion: termsPolicyVersion,
        locale: locale == 'ar' ? 'ar' : 'en',
      ),
    );
    return _child(created);
  });

  @override
  Future<String> signInToken(String childId) => _guard(() async {
    final session = await _client.createManagedChildSession(
      const V1ManagedChildSessionRequestDto(),
      childId: childId,
    );
    return session.tokenHash;
  });

  static ManagedChild _child(V1ManagedChildDto dto) => ManagedChild(
    childId: dto.childId,
    displayName: dto.displayName,
    createdAt: DateTime.parse(dto.createdAt).toLocal(),
  );

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on V1ApiException catch (error) {
      throw ManagedChildException(switch (error) {
        V1ApiException(code: 'MANAGED_CHILD_LIMIT') =>
          ManagedChildRefusal.limitReached,
        // No service key on this server: the routes are not mounted.
        V1ApiException(status: 404 || 501 || 503) =>
          ManagedChildRefusal.unavailable,
        _ => ManagedChildRefusal.failed,
      });
    }
  }
}
