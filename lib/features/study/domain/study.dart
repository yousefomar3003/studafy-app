import 'package:flutter/foundation.dart';

import '../../../core/file_upload_repository.dart';

/// A student's plan (2026-09-27).
///
/// Lessons and the Notebook are free for everyone. The two paid plans add AI:
/// Studafy Plus turns a whiteboard photo into notes; Studafy Max adds
/// quizzes and flashcards made from lessons.
enum StudyPlanTier {
  free(null),
  plus('studafy_plus'),
  max('studafy_max');

  const StudyPlanTier(this.featureKey);

  /// The store product family this plan is sold as. Null for free.
  final String? featureKey;

  static StudyPlanTier parse(String value) => switch (value) {
    'max' => StudyPlanTier.max,
    'plus' => StudyPlanTier.plus,
    _ => StudyPlanTier.free,
  };

  bool includes(StudyPlanTier other) => index >= other.index;
}

/// The caller's plan and how much of this month's AI allowance is used.
@immutable
class StudyPlan {
  const StudyPlan({
    required this.tier,
    required this.allowanceUsed,
    required this.resetsAt,
    required this.askToday,
    required this.askPerDay,
  });

  static final free = StudyPlan(
    tier: StudyPlanTier.free,
    allowanceUsed: 0,
    resetsAt: DateTime(2100),
    askToday: 0,
    askPerDay: 10,
  );

  final StudyPlanTier tier;

  /// 0 to 1: how much of the month's AI allowance is spent.
  final double allowanceUsed;
  final DateTime resetsAt;
  final int askToday;
  final int askPerDay;

  bool get canSnapWhiteboard => tier.includes(StudyPlanTier.plus);
  bool get canMakeStudySets => tier.includes(StudyPlanTier.max);
}

@immutable
class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.body,
    required this.fromWhiteboard,
    required this.createdAt,
    this.photo,
  });

  final String id;
  final String classroomId;
  final String title;
  final String body;

  /// Written by Studafy Plus from a whiteboard photo.
  final bool fromWhiteboard;
  final DateTime createdAt;
  final StoredAttachment? photo;
}

@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
}

@immutable
class Flashcard {
  const Flashcard({required this.front, required this.back});

  final String front;
  final String back;
}

enum StudySetKind { quiz, flashcards }

@immutable
class StudySet {
  const StudySet({
    required this.kind,
    this.questions = const [],
    this.cards = const [],
  });

  final StudySetKind kind;
  final List<QuizQuestion> questions;
  final List<Flashcard> cards;
}

/// Why a study action was refused, in terms the screen can act on.
enum StudyRefusal {
  /// The plan does not include it: offer the plans.
  planRequired,

  /// This month's AI allowance is spent: it renews on the 1st.
  allowanceUsed,

  /// Today's free questions are used.
  dailyLimit,

  /// The whiteboard photo is still being checked.
  photoNotReady,

  /// No writing could be read in the photo.
  photoUnreadable,

  /// The lesson has no text to study from.
  lessonHasNoText,

  /// Switched off on this server.
  unavailable,

  /// Anything else - a network failure, a server fault.
  failed,
}

class StudyException implements Exception {
  const StudyException(this.refusal);
  final StudyRefusal refusal;

  @override
  String toString() => 'StudyException($refusal)';
}

abstract interface class StudyRepository {
  Future<StudyPlan> plan();
  Future<List<NotebookEntry>> notebook(String classroomId);
  Future<NotebookEntry> addNote(
    String classroomId, {
    required String title,
    required String body,
  });

  /// Studafy Plus: notes from an uploaded, scanned whiteboard photo.
  Future<NotebookEntry> whiteboardNote(String classroomId, String photoFileId);
  Future<void> deleteNote(String entryId);

  /// Studafy Max: a quiz or flashcards from a lesson.
  Future<StudySet> studySet(String resourceId, StudySetKind kind);
}

/// A plan as the store offers it, for the Plans screen.
@immutable
class StudyPlanOffer {
  const StudyPlanOffer({
    required this.tier,
    this.active = false,
    this.price = '',
    this.monthly = false,
    this.oneMonthTrial = false,
    this.storeAvailable = false,
    this.selfPurchaseEnabled = false,
    this.approval = 'none',
  });

  final StudyPlanTier tier;
  final bool active;

  /// The store's own formatted price, currency symbol included.
  final String price;
  final bool monthly;
  final bool oneMonthTrial;
  final bool storeAvailable;
  final bool selfPurchaseEnabled;

  /// 'none', 'requested' or 'approved': a guardian approves a student's
  /// purchase before the store sheet can open.
  final String approval;

  bool get canPurchase =>
      !active &&
      storeAvailable &&
      monthly &&
      price.isNotEmpty &&
      selfPurchaseEnabled &&
      approval == 'approved';
}

/// Buying a plan through the App Store or Google Play (PAY-071).
abstract interface class StudyPlanSubscriptionRepository {
  Future<StudyPlanOffer> offer(StudyPlanTier tier);
  Future<void> requestApproval(StudyPlanTier tier);
  Future<void> purchase(StudyPlanTier tier);
  Future<void> restorePurchases();
  void addEntitlementListener(VoidCallback listener);
  void removeEntitlementListener(VoidCallback listener);
}
