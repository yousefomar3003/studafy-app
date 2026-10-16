import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_consent.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/study/data/api_ai_consent_repository.dart';
import 'package:studafy/features/study/data/api_study_repository.dart';
import 'package:studafy/features/study/domain/study.dart';

/// The AI notice before a student's first AI use, wherever it starts
/// (ADR-0043): the server refuses with AI_CONSENT_REQUIRED before anything
/// reaches the AI provider, the app shows the notice, and the request is
/// made again once the student agrees.
void main() {
  tearDown(AiConsentGate.instance.reset);

  group('the gate', () {
    test('a request that needs no consent runs once, untouched', () async {
      var asked = 0;
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async {
          asked++;
          return true;
        },
        explainGuardian: () async {},
      );
      expect(await AiConsentGate.instance.run(() async => 7), 7);
      expect(asked, 0);
    });

    test('agreed: the request is made once more', () async {
      var calls = 0;
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async => true,
        explainGuardian: () async {},
      );
      final result = await AiConsentGate.instance.run(() async {
        calls++;
        if (calls == 1) {
          throw const AiConsentRequiredException(guardian: false);
        }
        return 'answer';
      });
      expect(result, 'answer');
      expect(calls, 2);
    });

    test('declined: nothing is sent again, and the refusal stands', () async {
      var calls = 0;
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async => false,
        explainGuardian: () async {},
      );
      await expectLater(
        AiConsentGate.instance.run(() async {
          calls++;
          throw const AiConsentRequiredException(guardian: false);
        }),
        throwsA(isA<AiConsentRequiredException>()),
      );
      expect(calls, 1);
    });

    test('a child account is told a parent decides, and never asked', () async {
      var asked = 0;
      var explained = 0;
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async {
          asked++;
          return true;
        },
        explainGuardian: () async => explained++,
      );
      await expectLater(
        AiConsentGate.instance.run<void>(
          () async => throw const AiConsentRequiredException(guardian: true),
        ),
        throwsA(isA<AiConsentRequiredException>()),
      );
      expect(asked, 0);
      expect(explained, 1);
    });

    test('two requests waiting for consent show the notice once', () async {
      var asked = 0;
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async {
          asked++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return true;
        },
        explainGuardian: () async {},
      );
      final first = AiConsentGate.instance.requestConsent();
      final second = AiConsentGate.instance.requestConsent();
      expect(await Future.wait([first, second]), [true, true]);
      expect(asked, 1);
    });

    test('with nothing wired, no consent is assumed', () async {
      expect(await AiConsentGate.instance.requestConsent(), isFalse);
    });
  });

  group('a study tool asked before consent', () {
    test('shows the notice, then is made once the student agrees', () async {
      final transport = _Transport()..refuseNext = 'AI_CONSENT_REQUIRED';
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async => true,
        explainGuardian: () async {},
      );
      final entry = await ApiStudyRepository(V1ApiClient(transport))
          .lessonNotes('00000000-0000-4000-8000-0000000000aa');
      expect(entry.title, 'Cells');
      expect(transport.posts, 2);
    });

    test('declined, it is refused as AI consent and not retried', () async {
      final transport = _Transport()..refuseNext = 'AI_CONSENT_REQUIRED';
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async => false,
        explainGuardian: () async {},
      );
      await expectLater(
        ApiStudyRepository(V1ApiClient(transport))
            .lessonNotes('00000000-0000-4000-8000-0000000000aa'),
        throwsA(
          isA<StudyException>().having(
            (e) => e.refusal,
            'refusal',
            StudyRefusal.aiConsent,
          ),
        ),
      );
      expect(transport.posts, 1);
    });

    test('a parent or teacher account is refused, never asked', () async {
      var asked = 0;
      final transport = _Transport()..refuseNext = 'AI_STUDENTS_ONLY';
      AiConsentGate.instance.attach(
        repository: null,
        ask: () async {
          asked++;
          return true;
        },
        explainGuardian: () async {},
      );
      await expectLater(
        ApiStudyRepository(V1ApiClient(transport))
            .lessonNotes('00000000-0000-4000-8000-0000000000aa'),
        throwsA(isA<StudyException>()),
      );
      expect(asked, 0);
    });
  });

  group('the consent through the API', () {
    test('agreeing names the notice version and the language shown', () async {
      final transport = _Transport();
      final state = await ApiAiConsentRepository(V1ApiClient(transport))
          .give(locale: 'ar');
      expect(transport.lastPath, '/v1/me/study-tools-consent');
      expect(transport.lastBody, {
        'given': true,
        'version': aiConsentVersion,
        'locale': 'ar',
      });
      expect(transport.lastKey, isNotNull);
      expect(state.on, isTrue);
    });

    test('a parent agrees, or withdraws, for a child account by id', () async {
      final transport = _Transport();
      final repository = ApiAiConsentRepository(V1ApiClient(transport));
      await repository.give(locale: 'en', childId: 'child-1');
      expect(
        transport.lastPath,
        '/v1/me/managed-children/child-1/study-tools-consent',
      );
      await repository.withdraw(childId: 'child-1');
      expect(transport.lastBody, {'given': false});
    });

    test('the server says who may use the tools', () async {
      final transport = _Transport()..access = 'guardian_consent_required';
      final state = await ApiAiConsentRepository(V1ApiClient(transport))
          .state();
      expect(state.access, AiAccess.guardianConsentRequired);
      expect(state.access.isStudentInClass, isTrue);
      expect(AiAccess.parse('not_student').isStudentInClass, isFalse);
      expect(AiAccess.parse('no_class').isStudentInClass, isFalse);
    });
  });
}

class _Transport implements V1JsonTransport {
  String? refuseNext;
  String access = 'consent_required';
  int posts = 0;
  String? lastPath;
  Map<String, Object?>? lastBody;
  String? lastKey;

  Map<String, dynamic> _state(bool given) => {
    'access': given ? 'ok' : access,
    'version': aiConsentVersion,
    'consent': given
        ? {
            'version': aiConsentVersion,
            'locale': 'ar',
            'givenAt': '2026-10-15T10:00:00Z',
            'givenAs': 'self',
          }
        : null,
  };

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    return _state(false);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    posts++;
    lastPath = path;
    lastBody = body;
    lastKey = idempotencyKey;
    final refusal = refuseNext;
    if (refusal != null) {
      refuseNext = null;
      throw V1ApiException(status: 403, code: refusal, message: refusal);
    }
    if (path.contains('study-tools-consent')) {
      return _state(body['given'] == true);
    }
    return {
      'id': '00000000-0000-4000-8000-0000000000e1',
      'classroomId': '00000000-0000-4000-8000-0000000000c1',
      'title': 'Cells',
      'body': '# Cells',
      'source': 'lesson',
      'createdAt': '2026-10-15T10:00:00Z',
      'photo': null,
    };
  }
}
