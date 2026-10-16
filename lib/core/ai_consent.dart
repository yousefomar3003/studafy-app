import 'dart:async';

import 'package:flutter/foundation.dart';

/// The AI notice version the app shows and asks people to agree to
/// (ADR-0043). The published policy row for it carries the SHA-256 of the
/// exact in-app notice (`aiConsentNoticeBody`) in each language, and the
/// server records a consent only against the current published one, so
/// changing the text means a new version here and in a migration.
///
/// TODO(legal): counsel to confirm the notice text (EN and AR) before AI is
/// switched on for real students, and who consents for a 13-17 year old who
/// signs in themselves (today: the student; only managed child accounts get
/// a parent's consent). See ADR-0043.
const aiConsentVersion = '2026-10-15';

/// Whether an account may use the AI study tools, as the server decides it.
enum AiAccess {
  /// A student in a class with a current AI consent.
  ok,

  /// A parent or teacher account: the tools are for students.
  notStudent,

  /// A student account that is in no class yet.
  noClass,

  /// A student who has not agreed to the current AI notice.
  consentRequired,

  /// A managed child account: the parent agrees, from their own account.
  guardianConsentRequired;

  static AiAccess parse(String value) => switch (value) {
    'ok' => AiAccess.ok,
    'no_class' => AiAccess.noClass,
    'consent_required' => AiAccess.consentRequired,
    'guardian_consent_required' => AiAccess.guardianConsentRequired,
    _ => AiAccess.notStudent,
  };

  /// A student in a class: the tools are theirs once consent is given.
  bool get isStudentInClass =>
      this == AiAccess.ok ||
      this == AiAccess.consentRequired ||
      this == AiAccess.guardianConsentRequired;
}

/// An account's AI access and its current consent.
@immutable
class AiConsentState {
  const AiConsentState({
    required this.access,
    this.version,
    this.givenAt,
    this.givenByGuardian = false,
  });

  final AiAccess access;

  /// The notice a consent must be for now.
  final String? version;

  /// When the current consent was given; null without one.
  final DateTime? givenAt;

  /// The parent who manages the account gave it.
  final bool givenByGuardian;

  bool get on => access == AiAccess.ok;
}

/// The AI consent, for the signed-in account or a child account it manages.
abstract interface class AiConsentRepository {
  /// [childId] names a managed child account; null is the caller's own.
  Future<AiConsentState> state({String? childId});

  /// Agrees to the current notice, shown in [locale] ('en' or 'ar').
  Future<AiConsentState> give({required String locale, String? childId});

  /// Withdraws: the AI study tools stop until consent is given again.
  Future<AiConsentState> withdraw({String? childId});
}

/// The server refused an AI request for want of a consent: the caller's
/// own ([guardian] false) or their parent's.
class AiConsentRequiredException implements Exception {
  const AiConsentRequiredException({required this.guardian});

  final bool guardian;

  @override
  String toString() => 'AiConsentRequiredException(guardian: $guardian)';
}

/// Shows the AI notice before a student's first AI use, wherever that use
/// starts (ADR-0043, DPIA D2).
///
/// Every AI request goes to the server, which refuses it with
/// AI_CONSENT_REQUIRED before anything is sent to the AI provider. The data
/// layer then asks this gate: the app shows the notice, records the consent
/// if the student agrees, and the request is sent again. So the notice is
/// shown before the first use whichever tool it is, with no tool needing to
/// know about it.
class AiConsentGate {
  AiConsentGate._();

  /// The one gate the app uses.
  static final AiConsentGate instance = AiConsentGate._();

  /// Shows the notice and records the consent; true when the student agreed.
  Future<bool> Function()? _ask;

  /// Explains that a parent turns the tools on for a managed account.
  Future<void> Function()? _explainGuardian;

  /// Reads and writes the consent; null in a build with no server.
  AiConsentRepository? repository;

  Future<bool>? _asking;

  /// Wires the gate to the app's UI. Replaces any earlier wiring.
  void attach({
    required AiConsentRepository? repository,
    required Future<bool> Function() ask,
    required Future<void> Function() explainGuardian,
  }) {
    this.repository = repository;
    _ask = ask;
    _explainGuardian = explainGuardian;
  }

  /// Back to nothing wired, for tests.
  @visibleForTesting
  void reset() {
    repository = null;
    _ask = null;
    _explainGuardian = null;
    _asking = null;
  }

  /// Asks for consent once, however many requests are waiting for it.
  Future<bool> requestConsent() {
    final ask = _ask;
    if (ask == null) return Future.value(false);
    return _asking ??= ask().whenComplete(() => _asking = null);
  }

  Future<void> explainGuardian() async => _explainGuardian?.call();

  /// Runs [request]; when the server wants the student's consent first,
  /// asks for it and runs [request] once more if it was given. Anything
  /// else - including a parent's consent being needed - is rethrown, after
  /// the explanation is shown.
  Future<T> run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on AiConsentRequiredException catch (refusal) {
      if (refusal.guardian) {
        unawaited(explainGuardian());
        rethrow;
      }
      if (!await requestConsent()) rethrow;
      return await request();
    }
  }
}
