import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/inline_photo.dart';
import '../../../data/contracts/response_cache.dart';
import '../domain/study_assistant_repository.dart';

/// Answers a question the student already asked, in the same chat context,
/// from this device instead of asking the AI again.
///
/// The same question with the same earlier turns and the same lessons or
/// notes gets the answer it got before: instantly, offline, and without using
/// any of the AI allowance. Questions with a photo always go to the server.
/// Answers are kept on the device only, like the chats themselves, per
/// account, for [maxAge] - a day when they came from class material, which
/// a teacher may change - and erased at sign-out.
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
    List<InlinePhoto> inlinePhotos = const [],
    String? requestId,
    String? language,
    bool skipUnavailable = false,
  }) async {
    // Going on without unreadable files is a different answer from the
    // one with them, so it is neither read from nor kept in the cache.
    final keep =
        photoFileIds.isEmpty && inlinePhotos.isEmpty && !skipUnavailable;
    final maxAgeHere = references.isEmpty
        ? maxAge
        : const Duration(days: 1) < maxAge
        ? const Duration(days: 1)
        : maxAge;
    final key = _key(question, history, references);
    if (keep) {
      try {
        final kept = await _cache.read(key);
        final at = DateTime.tryParse(kept?['at'] as String? ?? '');
        final answer = kept?['answer'];
        if (answer is String &&
            answer.isNotEmpty &&
            at != null &&
            _now().difference(at) < maxAgeHere) {
          return StudyAnswer(
            answer: answer,
            citations: [
              for (final item
                  in kept!['citations'] as List<dynamic>? ?? const [])
                ?AnswerCitation.fromJson(item),
            ],
            unreadable: [
              for (final item
                  in kept['unreadable'] as List<dynamic>? ?? const [])
                ?UnreadableSource.fromJson(item),
            ],
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
      inlinePhotos: inlinePhotos,
      requestId: requestId,
      language: language,
      skipUnavailable: skipUnavailable,
    );
    // Something could not be read yet: next time it may be, so the answer
    // is not kept.
    if (keep && answer.unreadable.isEmpty) {
      try {
        await _cache.write(key, {
          'answer': answer.answer,
          'citations': [for (final c in answer.citations) c.toJson()],
          'at': _now().toUtc().toIso8601String(),
        });
      } on Object {
        // Not kept; the answer is still shown.
      }
    }
    return answer;
  }
}
