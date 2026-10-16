import '../../../core/ai_consent.dart';
import '../../../core/idempotency.dart';
import '../../../data/contracts/v1_client.generated.dart';

/// The AI consent through the API (ADR-0043). The server decides who may
/// give it - a managed child's parent, never the child - and records it
/// only against the current published notice.
class ApiAiConsentRepository implements AiConsentRepository {
  const ApiAiConsentRepository(this._client);

  final V1ApiClient _client;

  static AiConsentState _state(V1AiConsentStateDto dto) => AiConsentState(
    access: AiAccess.parse(dto.access),
    version: dto.version,
    givenAt: dto.consent == null
        ? null
        : DateTime.parse(dto.consent!.givenAt).toLocal(),
    givenByGuardian: dto.consent?.givenAs == 'guardian',
    toolsEnabled: dto.toolsEnabled ?? true,
  );

  @override
  Future<AiConsentState> state({String? childId}) async => _state(
    childId == null
        ? await _client.getStudyToolsConsent()
        : await _client.getManagedChildStudyToolsConsent(childId: childId),
  );

  @override
  Future<AiConsentState> give({required String locale, String? childId}) =>
      _update(
        V1UpdateAiConsentRequestDto(
          given: true,
          version: aiConsentVersion,
          locale: locale == 'ar' ? 'ar' : 'en',
        ),
        childId,
      );

  @override
  Future<AiConsentState> withdraw({String? childId}) =>
      _update(const V1UpdateAiConsentRequestDto(given: false), childId);

  Future<AiConsentState> _update(
    V1UpdateAiConsentRequestDto request,
    String? childId,
  ) async {
    final key = newIdempotencyKey('ai-consent');
    return _state(
      childId == null
          ? await _client.updateStudyToolsConsent(request, idempotencyKey: key)
          : await _client.updateManagedChildStudyToolsConsent(
              request,
              childId: childId,
              idempotencyKey: key,
            ),
    );
  }
}
