import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_policy.dart';
import 'package:studafy/core/file_upload_repository.dart';

/// The client copy of the FILE-050 purpose policies. The server re-checks all
/// of it; these tests exist so the copy cannot silently drift looser than the
/// migration, and so filename handling stays boring.
void main() {
  group('purpose policies', () {
    test('every purpose has a policy', () {
      for (final purpose in FilePurpose.values) {
        expect(AttachmentPolicy.of(purpose).purpose, purpose);
      }
    });

    test('matches the migration caps', () {
      expect(AttachmentPolicy.assignmentSubmission.maximumSizeBytes, 10485760);
      expect(AttachmentPolicy.lessonResource.maximumSizeBytes, 26214400);
      expect(AttachmentPolicy.profileImage.maximumSizeBytes, 5242880);
    });

    test('office formats are not offered anywhere', () {
      // No structural parser and no malware engine covers a zip container,
      // so the pipeline would quarantine it forever.
      const office = [
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/zip',
      ];
      for (final purpose in FilePurpose.values) {
        final policy = AttachmentPolicy.of(purpose);
        for (final type in office) {
          expect(
            policy.allowedMediaTypes,
            isNot(contains(type)),
            reason: '${purpose.wireValue} must not offer $type',
          );
        }
      }
    });

    test(
      'refuses the wrong media type, the empty file and the oversized one',
      () {
        const policy = AttachmentPolicy.assignmentSubmission;
        expect(
          policy.refuse(mediaType: 'application/pdf', sizeBytes: 1024),
          isNull,
        );
        expect(
          policy.refuse(mediaType: 'text/html', sizeBytes: 1024),
          AttachmentRefusal.mediaType,
        );
        expect(
          policy.refuse(mediaType: 'application/pdf', sizeBytes: 0),
          AttachmentRefusal.empty,
        );
        expect(
          policy.refuse(mediaType: 'application/pdf', sizeBytes: 10485761),
          AttachmentRefusal.tooLarge,
        );
      },
    );

    test('media type matching ignores case and padding', () {
      expect(
        AttachmentPolicy.assignmentSubmission.refuse(
          mediaType: '  APPLICATION/PDF ',
          sizeBytes: 10,
        ),
        isNull,
      );
    });

    test('picker extensions never drift from the media types', () {
      for (final purpose in FilePurpose.values) {
        final policy = AttachmentPolicy.of(purpose);
        expect(
          policy.pickerExtensions.length,
          policy.allowedMediaTypes.length,
          reason: '${purpose.wireValue} has a type with no extension mapping',
        );
      }
    });
  });

  group('filename sanitisation', () {
    test('drops path syntax rather than escaping it', () {
      expect(sanitiseAttachmentName('../../etc/passwd'), 'passwd');
      expect(sanitiseAttachmentName(r'..\..\windows\system32'), 'system32');
      expect(sanitiseAttachmentName('/absolute/path/report.pdf'), 'report.pdf');
    });

    test('neutralises script and control characters', () {
      // The path split runs first, so the closing tag's slash truncates this
      // to its last segment before the character filter ever sees it.
      expect(
        sanitiseAttachmentName('<script>alert(1)</script>.png'),
        'script_.png',
      );
      // The leading '<' becomes an underscore and is then trimmed, because a
      // name starting with '_' or '.' is not one anybody typed.
      expect(
        sanitiseAttachmentName('<img onerror=x>.png'),
        'img onerror_x_.png',
      );
      expect(sanitiseAttachmentName('re\u0000port\u001f.pdf'), 'report.pdf');
    });

    test('keeps Arabic names intact', () {
      expect(
        sanitiseAttachmentName('واجب الرياضيات.pdf'),
        'واجب الرياضيات.pdf',
      );
    });

    test('never returns a hidden or empty name', () {
      expect(sanitiseAttachmentName('...'), 'attachment');
      expect(sanitiseAttachmentName('   '), 'attachment');
      expect(sanitiseAttachmentName('.env'), 'env');
      expect(sanitiseAttachmentName('/'), 'attachment');
    });

    test('long names keep their extension', () {
      final name = '${'a' * 400}.pdf';
      final result = sanitiseAttachmentName(name);
      expect(result.length, 120);
      expect(result.endsWith('.pdf'), isTrue);
    });
  });
}
