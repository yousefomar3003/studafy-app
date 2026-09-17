import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/files/data/api_file_upload_repository.dart';
import 'package:studafy/features/files/data/preview_file_upload_repository.dart';
import 'package:studafy/features/files/data/signed_upload_transport.dart';
import 'package:studafy/features/files/domain/file_upload_repository.dart';

void main() {
  const school = 'bbbbbbbb-0000-4000-8000-000000000001';
  const upload = 'cccccccc-0000-4000-8000-000000000001';
  const file = 'dddddddd-0000-4000-8000-000000000001';
  final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]);
  final command = FileUploadCommand(
    attemptId: 'attempt-1',
    schoolId: school,
    purpose: FilePurpose.profileImage,
    displayName: 'avatar.png',
    mediaType: 'image/png',
    bytes: bytes,
  );

  test(
    'API adapter reuses the intent key after response/upload failure',
    () async {
      final transport = _FakeJsonTransport(uploadId: upload, fileId: file);
      final signed = _FakeSignedUploadTransport(failOnce: true);
      final repository = ApiFileUploadRepository(
        V1ApiClient(transport),
        signed,
      );

      await expectLater(repository.upload(command), throwsA(isA<StateError>()));
      final result = await repository.upload(command);

      expect(result.id, file);
      expect(result.scanState, 'quarantined');
      expect(transport.intentKeys, [
        'file-intent-attempt-1',
        'file-intent-attempt-1',
      ]);
      expect(transport.completeKeys, ['file-complete-attempt-1']);
      expect(
        signed.urls.every((value) => value.path == '/opaque-capability'),
        isTrue,
      );
    },
  );

  test('synthetic preview is isolated and reports quarantine', () async {
    final result = await const PreviewFileUploadRepository().upload(command);
    expect(result.id, startsWith('preview-file-'));
    expect(result.scanState, 'quarantined');
  });
}

class _FakeSignedUploadTransport implements SignedUploadTransport {
  _FakeSignedUploadTransport({required this.failOnce});

  bool failOnce;
  final urls = <Uri>[];

  @override
  Future<void> put({
    required Uri signedUrl,
    required Map<String, String> requiredHeaders,
    required Uint8List bytes,
  }) async {
    urls.add(signedUrl);
    expect(requiredHeaders['x-upsert'], 'false');
    if (failOnce) {
      failOnce = false;
      throw StateError('simulated response loss');
    }
  }
}

class _FakeJsonTransport implements V1JsonTransport {
  _FakeJsonTransport({required this.uploadId, required this.fileId});

  final String uploadId;
  final String fileId;
  final intentKeys = <String?>[];
  final completeKeys = <String?>[];

  @override
  Future<Map<String, dynamic>> get(String path) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    if (path == '/v1/uploads') {
      intentKeys.add(idempotencyKey);
      return {
        'session': _session('initiated', null),
        'uploadUrl': 'https://storage.invalid/opaque-capability',
        'method': 'PUT',
        'requiredHeaders': {
          'content-type': 'image/png',
          'cache-control': 'max-age=3600',
          'x-upsert': 'false',
        },
        'expiresAt': '2026-09-17T12:00:00Z',
      };
    }
    if (path == '/v1/uploads/$uploadId/complete') {
      completeKeys.add(idempotencyKey);
      return {
        'session': _session('completed', fileId),
        'file': {
          'id': fileId,
          'purpose': 'profile_image',
          'displayName': 'avatar.png',
          'sizeBytes': 4,
          'declaredMediaType': 'image/png',
          'detectedMediaType': 'image/png',
          'scanState': 'quarantined',
          'createdAt': '2026-09-17T10:00:00Z',
          'scannedAt': null,
          'failureCode': null,
        },
      };
    }
    throw StateError('unexpected route $path');
  }

  Map<String, Object?> _session(String state, String? resolvedFile) => {
    'id': uploadId,
    'purpose': 'profile_image',
    'displayName': 'avatar.png',
    'declaredMediaType': 'image/png',
    'expectedSizeBytes': 4,
    'state': state,
    'expiresAt': '2026-09-17T12:00:00Z',
    'createdAt': '2026-09-17T10:00:00Z',
    'completedAt': state == 'completed' ? '2026-09-17T10:01:00Z' : null,
    'fileId': resolvedFile,
    'failureCode': null,
  };
}
