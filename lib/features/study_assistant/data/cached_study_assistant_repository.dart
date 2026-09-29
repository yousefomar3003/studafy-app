import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/contracts/response_cache.dart';
import '../domain/study_assistant_repository.dart';

/// Answers a question the student already asked, in the same chat context,
/// from this device instead of asking the AI again.
///
/// The same question with the same earlier turns and the same lessons or
/// notes gets the answer it got before: instantly, offline, and without using
/// a question from today's allowance. Questions with a photo always go to
/// the server. Answers are kept on the device only, like the chats
/// themselves, per account, for [maxAge], and erased at sign-out.
class CachedStudyAssistantRepository implements StudyAssistantRepository {
  CachedStudyAssistantRepository(
    this._inner,
    this._cache, {
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
  }) : _now = now ?? DateTime.now;

  final StudyAssistantRepository _inner;
  final ResponseCache _cache;
  final DateTime Function() _now;

  /// A lesson may be revised, so a kept answer about it does not live
  /// forever.
  final Duration maxAge;

  /// Today's remaining questions as the server last said; a kept answer
  /// costs none, so it leaves this unchanged.
  int? _remaining;

  static String _key(
    String question,
    List<ChatTurn> history,
    List<ChatReference> references,
  ) {
    String norm(String text) =>
        text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final material = jsonEncode({
      'q': norm(question),
      'h': [for (final turn in history) '${turn.role.name}:${norm(turn.text)}'],
      'r': [for (final r in references) '${r.kind.name}:${r.id}'],
    });
    return 'helper:${sha256.convert(utf8.encode(material))}';
  }

  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async {
    final keep = photoFileIds.isEmpty;
    final key = _key(question, history, references);
    if (keep) {
      try {
        final kept = await _cache.read(key);
        final at = DateTime.tryParse(kept?['at'] as String? ?? '');
        final answer = kept?['answer'];
        if (answer is String &&
            answer.isNotEmpty &&
            at != null &&
            _now().difference(at) < maxAge) {
          return StudyAnswer(
            answer: answer,
            remainingToday:
                _remaining ?? (kept!['remainingToday'] as int? ?? 0),
          );
        }
      } on Object {
        // An unreadable cache just means asking the server.
      }
    }
    final answer = await _inner.ask(
      question,
      history: history,
      references: references,
      photoFileIds: photoFileIds,
    );
    _remaining = answer.remainingToday;
    if (keep) {
      try {
        await _cache.write(key, {
          'answer': answer.answer,
          'remainingToday': answer.remainingToday,
          'at': _now().toUtc().toIso8601String(),
        });
      } on Object {
        // Not kept; the answer is still shown.
      }
    }
    return answer;
  }
}
