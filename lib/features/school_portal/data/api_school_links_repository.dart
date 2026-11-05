import 'dart:io';

import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/school_links.dart';

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on V1ApiException catch (error) {
    if (error.isUnauthenticated) throw Failure.unauthorized;
    if (error.code == 'FORBIDDEN') throw Failure.forbidden;
    if (error.code == 'NOT_FOUND') throw Failure.notFound;
    // LINKED_ELSEWHERE, SCHOOL_UNAVAILABLE, ALREADY_REPORTED, INVALID_STATE,
    // RATE_LIMITED: the code is what the screen explains.
    throw Failure(error.code, error.code);
  } on SocketException {
    throw Failure.network;
  } on HttpException {
    throw Failure.network;
  }
}

/// The teacher's side of the School Portal over `/v1/me/school-links`.
class ApiSchoolLinksRepository implements SchoolLinksRepository {
  ApiSchoolLinksRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<List<SchoolLink>> list() => _guard(() async {
    final response = await _client.listMySchoolLinks();
    return [for (final item in response.links) ?_link(item)];
  });

  @override
  Future<void> decide(
    String linkId, {
    required bool accept,
    bool replaceCurrent = false,
  }) => _guard(() async {
    await _client.decideMySchoolLink(
      V1DecideSchoolLinkRequestDto(
        decision: accept ? 'accept' : 'decline',
        replaceCurrent: accept && replaceCurrent ? true : null,
      ),
      linkId: linkId,
    );
  });

  @override
  Future<void> unlink(String linkId) => _guard(() async {
    await _client.unlinkMySchool(
      const V1SchoolPortalEmptyRequestDto(),
      linkId: linkId,
    );
  });

  @override
  Future<void> report(
    String linkId, {
    required SchoolReportReason reason,
    String? details,
  }) => _guard(() async {
    final text = details?.trim();
    await _client.reportMySchoolLink(
      V1ReportSchoolRequestDto(
        reason: reason.code,
        details: text == null || text.isEmpty ? null : text,
      ),
      linkId: linkId,
    );
  });
}

/// One link from the server, or null for a shape this version cannot read.
SchoolLink? _link(Map<String, dynamic> item) {
  final org = item['org'];
  final status = _status(item['status']);
  final requestedAt = _date(item['requestedAt']);
  if (org is! Map<String, dynamic> ||
      status == null ||
      requestedAt == null ||
      item['id'] is! String) {
    return null;
  }
  final by = item['requestedBy'];
  return SchoolLink(
    id: item['id'] as String,
    status: status,
    requestedAt: requestedAt,
    decidedAt: _date(item['decidedAt']),
    endedAt: _date(item['endedAt']),
    org: SchoolLinkOrg(
      id: org['id'] as String? ?? '',
      name: org['name'] as String? ?? '',
      city: org['city'] as String? ?? '',
      country: org['country'] as String? ?? '',
      kind: switch (org['kind']) {
        'public' => SchoolKind.public,
        'private' => SchoolKind.private,
        'international' => SchoolKind.international,
        _ => SchoolKind.other,
      },
      active: org['status'] == 'active',
    ),
    requestedBy: by is Map<String, dynamic>
        ? SchoolLinkRequester(
            name: by['name'] as String? ?? '',
            email: by['email'] as String?,
            jobTitle: by['jobTitle'] as String?,
          )
        : null,
  );
}

SchoolLinkStatus? _status(Object? value) => switch (value) {
  'pending' => SchoolLinkStatus.pending,
  'linked' => SchoolLinkStatus.linked,
  'declined' => SchoolLinkStatus.declined,
  'cancelled' => SchoolLinkStatus.cancelled,
  'expired' => SchoolLinkStatus.expired,
  'unlinked' => SchoolLinkStatus.unlinked,
  _ => null,
};

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
