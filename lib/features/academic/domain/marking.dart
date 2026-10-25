import 'package:flutter/foundation.dart';

import 'online_assessment.dart';

/// Studafy AI Marking (ADR-0046): suggested marks for written work, made
/// against the teacher's own reference.
///
/// A suggestion is a draft for the teacher only. It can fill in the
/// teacher's marking fields, but nothing becomes a mark until the teacher
/// saves it through the marking they already do - that save stays the only
/// writer. Students can opt out; their work is then never sent.

/// How closely an answer must match the reference to earn its marks.
enum MarkingStrictness {
  lenient('lenient'),
  balanced('balanced'),
  strict('strict');

  const MarkingStrictness(this.wire);
  final String wire;

  static MarkingStrictness fromWire(String? value) => MarkingStrictness.values
      .firstWhere((x) => x.wire == value, orElse: () => balanced);
}

/// Something a complete answer must contain, and what it is worth.
@immutable
class MarkingKeyPoint {
  const MarkingKeyPoint({required this.text, this.marks});

  final String text;
  final double? marks;

  @override
  bool operator ==(Object other) =>
      other is MarkingKeyPoint && other.text == text && other.marks == marks;

  @override
  int get hashCode => Object.hash(text, marks);
}

/// The most key points one reference may have.
const maxMarkingKeyPoints = 20;

/// What the key points with marks add up to.
double keyPointMarks(Iterable<MarkingKeyPoint> points) =>
    points.fold(0, (sum, point) => sum + (point.marks ?? 0));

/// One question's reference, or - for a graded assignment's hand-in - the
/// reference for the whole piece of work.
@immutable
class MarkingReference {
  const MarkingReference({
    required this.position,
    required this.maximumScore,
    this.questionId,
    this.kind,
    this.prompt,
    this.options = const [],
    this.correctOptionIds,
    this.correctChoice,
    this.acceptedAnswers,
    this.preferredAnswer,
    this.markingGuidance,
    this.keyPoints = const [],
    this.acceptedMethods,
    this.partialCredit,
  });

  /// Null for a hand-in: one reference for the whole piece of work.
  final String? questionId;
  final int position;

  /// The question's kind; null for a hand-in.
  final QuestionKind? kind;
  final String? prompt;
  final double maximumScore;
  final List<QuestionOption> options;

  /// The keys that mark choice, true/false and short answers by themselves.
  final List<String>? correctOptionIds;
  final bool? correctChoice;
  final List<String>? acceptedAnswers;

  /// The model answer or worked solution.
  final String? preferredAnswer;
  final String? markingGuidance;
  final List<MarkingKeyPoint> keyPoints;

  /// Other answers or methods that earn credit.
  final String? acceptedMethods;

  /// How part marks are given.
  final String? partialCredit;

  bool get handIn => questionId == null;

  /// Written work a suggestion can be made for. Choice and true/false are
  /// marked by their key the moment they are submitted.
  bool get written =>
      handIn || kind == QuestionKind.shortAnswer || kind == QuestionKind.essay;
}

/// Every reference for one assessment, with how strictly they are read.
@immutable
class MarkingReferences {
  const MarkingReferences({
    required this.delivery,
    required this.strictness,
    required this.referenceVersion,
    required this.references,
  });

  /// 'online' for an online assessment; otherwise paper work, whose one
  /// reference is for the hand-in.
  final String delivery;
  final MarkingStrictness strictness;

  /// Moves on whenever a reference or the strictness changes.
  final int referenceVersion;
  final List<MarkingReference> references;

  MarkingReference? forQuestion(String? questionId) =>
      references.where((r) => r.questionId == questionId).firstOrNull;
}

/// A change to one reference. A null field is left as it is; an empty one
/// clears it.
@immutable
class MarkingReferenceUpdate {
  const MarkingReferenceUpdate({
    this.questionId,
    this.preferredAnswer,
    this.markingGuidance,
    this.keyPoints,
    this.acceptedMethods,
    this.partialCredit,
  });

  /// Null for a hand-in.
  final String? questionId;
  final String? preferredAnswer;
  final String? markingGuidance;
  final List<MarkingKeyPoint>? keyPoints;
  final String? acceptedMethods;
  final String? partialCredit;

  bool get isEmpty =>
      preferredAnswer == null &&
      markingGuidance == null &&
      keyPoints == null &&
      acceptedMethods == null &&
      partialCredit == null;
}

/// What saving references did. Nothing is re-marked by itself:
/// [staleSuggestions] says how many suggestions were made against an older
/// reference, for the teacher to ask again if they want.
@immutable
class MarkingReferencesSaved {
  const MarkingReferencesSaved({
    required this.references,
    required this.changed,
    required this.staleSuggestions,
  });

  final MarkingReferences references;
  final bool changed;
  final int staleSuggestions;
}

enum MarkingSuggestionStatus {
  /// Waiting for the AI.
  pending,
  ready,

  /// The AI could not make one: the teacher marks it by hand.
  failed,

  /// Not sent: the student opted out, or the work could not be read.
  skipped;

  static MarkingSuggestionStatus fromWire(String? value) => switch (value) {
    'pending' => pending,
    'ready' => ready,
    'skipped' => skipped,
    _ => failed,
  };
}

/// Why a suggestion needs the teacher's own reading.
enum MarkingReviewReason {
  ambiguous,
  unreadable,
  noReference,
  conflict,
  empty;

  static MarkingReviewReason? fromWire(String? value) => switch (value) {
    'ambiguous' => ambiguous,
    'unreadable' => unreadable,
    'no_reference' => noReference,
    'conflict' => conflict,
    'empty' => empty,
    _ => null,
  };
}

/// A suggested mark for one written answer, or for one student's hand-in.
@immutable
class MarkingSuggestion {
  const MarkingSuggestion({
    required this.id,
    required this.studentId,
    required this.status,
    required this.maximumScore,
    required this.referenceVersion,
    required this.strictness,
    this.attemptId,
    this.questionId,
    this.submissionAttemptId,
    this.suggestedScore,
    this.met = const [],
    this.missed = const [],
    this.rationale,
    this.feedback,
    this.conflict,
    this.reviewReason,
    this.reason,
    this.stale = false,
  });

  final String id;
  final String studentId;

  /// Set for an online assessment's answer.
  final String? attemptId;
  final String? questionId;

  /// Set for a hand-in.
  final String? submissionAttemptId;
  final MarkingSuggestionStatus status;
  final double maximumScore;
  final double? suggestedScore;

  /// The requirements the answer met, and those it missed.
  final List<String> met;
  final List<String> missed;
  final String? rationale;

  /// For the student, for the teacher to edit before it is used.
  final String? feedback;

  /// Where the reference disagrees with the question.
  final String? conflict;
  final MarkingReviewReason? reviewReason;

  /// Why it was skipped or failed: 'opted_out', 'unreadable', ...
  final String? reason;
  final int referenceVersion;
  final MarkingStrictness strictness;

  /// Made against an older reference than the current one.
  final bool stale;

  bool get optedOut => reason == 'opted_out';

  /// Ready, with a mark the teacher can take into their own fields.
  bool get usable =>
      status == MarkingSuggestionStatus.ready && suggestedScore != null;
}

/// An assessment's suggestions and the strictness they are read with now.
@immutable
class MarkingSuggestions {
  const MarkingSuggestions({
    required this.strictness,
    required this.referenceVersion,
    required this.items,
  });

  static const none = MarkingSuggestions(
    strictness: MarkingStrictness.balanced,
    referenceVersion: 1,
    items: [],
  );

  final MarkingStrictness strictness;
  final int referenceVersion;
  final List<MarkingSuggestion> items;

  int count(MarkingSuggestionStatus status) =>
      items.where((s) => s.status == status).length;

  int get stale => items
      .where((s) => s.stale && s.status == MarkingSuggestionStatus.ready)
      .length;

  /// The latest for one answer of an online attempt.
  MarkingSuggestion? forAnswer(String attemptId, String questionId) => items
      .where((s) => s.attemptId == attemptId && s.questionId == questionId)
      .firstOrNull;

  /// The latest for one student's hand-in.
  MarkingSuggestion? forHandIn(String studentId) => items
      .where((s) => s.studentId == studentId && s.questionId == null)
      .firstOrNull;
}

/// What asking for suggestions queued.
@immutable
class MarkingRun {
  const MarkingRun({
    required this.queued,
    required this.optedOut,
    required this.replaced,
  });

  final int queued;

  /// Students who opted out: their work is marked by hand.
  final int optedOut;

  /// Earlier suggestions this one replaces.
  final int replaced;
}

/// The teacher's Studafy AI Marking plan and this month's allowance.
@immutable
class MarkingPlan {
  const MarkingPlan({
    required this.active,
    required this.teacher,
    required this.available,
    required this.used,
    required this.total,
    required this.resetsAt,
  });

  final bool active;
  final bool teacher;

  /// The server can make suggestions at all. When it cannot, nothing
  /// offers them, though references can still be written.
  final bool available;
  final int used;
  final int total;
  final DateTime resetsAt;
}

/// Why the server refused a marking request.
enum MarkingProblem {
  /// Suggestions are switched off on the server.
  unavailable,

  /// The teacher has no Studafy AI Marking plan.
  planRequired,

  /// Not one of the class's teachers, or no such work.
  notAllowed,

  /// Paper work with nothing handed in to read.
  nothingToRead,

  /// A key point, or the key points' marks, was refused.
  invalid,
}

class MarkingRefusal implements Exception {
  const MarkingRefusal(this.problem);

  final MarkingProblem problem;

  @override
  String toString() => 'MarkingRefusal($problem)';
}

/// References and suggestions, for the class's teachers.
abstract interface class MarkingRepository {
  Future<MarkingPlan> plan();
  Future<MarkingReferences> references(String assessmentId);

  /// Saves the strictness and any changed references. Editing a reference
  /// never re-marks anything by itself.
  Future<MarkingReferencesSaved> saveReferences(
    String assessmentId, {
    MarkingStrictness? strictness,
    List<MarkingReferenceUpdate> updates = const [],
  });

  Future<MarkingSuggestions> suggestions(String assessmentId);

  /// Asks for suggestions for work with no mark yet, or - [all] - for every
  /// written answer or hand-in, replacing earlier ones. [studentIds]
  /// narrows it to some students.
  Future<MarkingRun> requestSuggestions(
    String assessmentId, {
    bool all = false,
    List<String>? studentIds,
  });

  Future<void> dismiss(String suggestionId);
}

/// A student's own choice: their work is never sent for a suggestion.
abstract interface class MarkingPreferenceRepository {
  Future<bool> optedOut();
  Future<bool> setOptedOut(bool optedOut);
}

/// The store's offer for Studafy AI Marking. The price is the store's own,
/// never one written into the app.
@immutable
class MarkingPlanOffer {
  const MarkingPlanOffer({
    this.storeAvailable = false,
    this.price = '',
    this.currencyCode = '',
    this.periodLabel = '',
    this.hasTrial = false,
    this.trialLengthLabel = '',
  });

  final bool storeAvailable;
  final String price;
  final String currencyCode;
  final String periodLabel;
  final bool hasTrial;
  final String trialLengthLabel;

  /// Never offer checkout before the store has supplied complete terms.
  bool get canPurchase =>
      storeAvailable &&
      price.trim().isNotEmpty &&
      currencyCode.trim().isNotEmpty &&
      periodLabel.trim().isNotEmpty;
}

/// Buying Studafy AI Marking: the teacher's own monthly subscription,
/// through the store on the phone.
abstract interface class MarkingPlanStore {
  /// False on the web and desktop, where the plan is described, not sold.
  bool get sellsMarkingPlan;

  Future<MarkingPlanOffer> markingOffer();
  Future<void> purchaseMarkingPlan();
  Future<void> restorePurchases();

  /// Called once a purchase or restore has been verified by the server.
  void addEntitlementListener(void Function() listener);
  void removeEntitlementListener(void Function() listener);
}

/// The marking slice, as the app composes it.
@immutable
class MarkingServices {
  const MarkingServices({
    required this.repository,
    this.plans,
    this.preference,
  });

  final MarkingRepository repository;

  /// Null in builds that cannot sell the plan.
  final MarkingPlanStore? plans;

  /// A student's opt-out; null in builds with no server.
  final MarkingPreferenceRepository? preference;
}
