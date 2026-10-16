import 'package:flutter/foundation.dart';

import '../../../core/file_upload_repository.dart';
import '../../../core/material_selection.dart';
import 'study_notebook.dart';

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

  /// The plan above this one, or null for Max.
  StudyPlanTier? get next => switch (this) {
    StudyPlanTier.free => StudyPlanTier.plus,
    StudyPlanTier.plus => StudyPlanTier.max,
    StudyPlanTier.max => null,
  };
}

/// A plan's AI allowance in tokens (ADR-0037): one allowance for the helper
/// and every other AI study tool. Free renews every Monday, the paid plans
/// on the 1st of the month.
@immutable
class AiAllowance {
  const AiAllowance({
    required this.weekly,
    required this.total,
    required this.used,
    required this.remaining,
    required this.resetsAt,
  });

  final bool weekly;
  final int total;
  final int used;
  final int remaining;
  final DateTime resetsAt;

  double get usedFraction =>
      total <= 0 ? 1 : (used / total).clamp(0, 1).toDouble();

  /// A quarter or less left: the usage bar's "Running low".
  bool get low => remaining > 0 && used >= total * 0.75;

  bool get exhausted => remaining <= 0;
}

/// The caller's plan and its AI allowance.
@immutable
class StudyPlan {
  const StudyPlan({
    required this.tier,
    required this.allowance,
    this.available,
  });

  static final free = StudyPlan(
    tier: StudyPlanTier.free,
    allowance: AiAllowance(
      weekly: true,
      total: 40000,
      used: 0,
      remaining: 40000,
      resetsAt: DateTime(2100),
    ),
  );

  /// What the server can do right now, whatever the plan: 'ask',
  /// 'whiteboard', 'quiz', 'flashcards'. Null from a server that does not
  /// say, which is then trusted to have everything.
  final Set<String>? available;

  bool _on(String feature) => available?.contains(feature) ?? true;

  /// Any AI study tool is here for this account. When none is - a server
  /// with no AI provider, or an account the tools are not for - nothing
  /// about them is shown: not the helper, not the plans that sell them.
  bool get anyToolOn => available == null || available!.isNotEmpty;

  /// The question box has an AI provider behind it.
  bool get assistantOn => _on('ask');

  /// Notes from a photo of the whiteboard can be made on this server.
  bool get whiteboardOn => _on('whiteboard');

  /// Quizzes and flashcards are switched on for this server.
  bool get studySetsOn => _on('quiz') && _on('flashcards');

  /// Study notebooks are written by the AI on this server.
  bool get notebooksOn => _on('notes');

  /// Class material may be shared with the helper: the same switch that
  /// sends lessons to the AI for quizzes.
  bool get classMaterialOn => _on('quiz');

  /// Photos may be sent to the helper: Studafy Plus, and the switch.
  bool get helperPhotosOn => canSnapWhiteboard && _on('whiteboard');

  final StudyPlanTier tier;

  /// The AI tokens this plan has, how many are used, and when they renew.
  final AiAllowance allowance;

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
    this.fromLesson = false,
  });

  final String id;
  final String classroomId;
  final String title;
  final String body;

  /// Written by Studafy Plus from a whiteboard photo.
  final bool fromWhiteboard;

  /// Made from one of the class's lessons.
  final bool fromLesson;
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
    this.scope,
  });

  final StudySetKind kind;
  final List<QuizQuestion> questions;
  final List<Flashcard> cards;

  /// What it was made from, when the server said.
  final MaterialScopeInfo? scope;
}

/// Why a study action was refused, in terms the screen can act on.
enum StudyRefusal {
  /// The plan does not include it: offer the plans.
  planRequired,

  /// The AI tokens are used: they renew on the plan's reset date.
  allowanceUsed,

  /// The lesson's files are still being read: try again in a minute.
  materialProcessing,

  /// The whiteboard photo is still being checked.
  photoNotReady,

  /// No writing could be read in the photo.
  photoUnreadable,

  /// The lesson has no text to study from.
  lessonHasNoText,

  /// Switched off on this server.
  unavailable,

  /// The AI study tools are off for this account: no AI consent (the
  /// student declined the notice, or a parent has not agreed for a child
  /// account), or the account is not a student in a class (ADR-0043).
  aiConsent,

  /// Anything else - a network failure, a server fault.
  failed,
}

class StudyException implements Exception {
  const StudyException(this.refusal);
  final StudyRefusal refusal;

  @override
  String toString() => 'StudyException($refusal)';
}

/// A lesson a student can turn into notes.
@immutable
class LessonChoice {
  const LessonChoice({
    required this.id,
    required this.title,
    required this.text,
  });

  final String id;
  final String title;
  final String text;
}

/// One class's notebook in the list of all of them.
@immutable
class NotebookGroup {
  const NotebookGroup({
    required this.classroomId,
    required this.className,
    required this.classGone,
    required this.entries,
  });

  final String classroomId;
  final String className;

  /// The class was deleted; the notes are still the student's.
  final bool classGone;
  final List<NotebookEntry> entries;
}

abstract interface class StudyRepository implements StudyNotebookRepository {
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

  /// Every notebook the student has, by class, deleted classes included.
  Future<List<NotebookGroup>> myNotebooks();

  /// Studafy Plus: study notes made from a lesson, filed in its class.
  Future<NotebookEntry> lessonNotes(String resourceId);

  /// Studafy Max: a quiz or flashcards from exactly [selection]. Throws
  /// [MaterialUnavailableException] naming chosen files that cannot be read
  /// now, unless [skipUnavailable].
  Future<StudySet> selectionStudySet(
    StudySetKind kind,
    MaterialSelection selection, {
    bool skipUnavailable = false,
  });

  /// Studafy Plus: study notes from exactly [selection], filed in
  /// [classroomId]'s notebook, ending with what they were made from.
  Future<NotebookEntry> summarise(
    String classroomId,
    MaterialSelection selection, {
    bool skipUnavailable = false,
    String? language,
  });
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

/// Where a subscription is billed.
enum SubscriptionStore {
  appStore,
  playStore;

  static SubscriptionStore? parse(String? value) => switch (value) {
    'app_store' => SubscriptionStore.appStore,
    'play_store' => SubscriptionStore.playStore,
    _ => null,
  };

  /// Google Play lets a subscriber pause; the App Store does not.
  bool get canPause => this == SubscriptionStore.playStore;
}

/// What happens at the end of the current period, as the store reports it.
enum RenewalStatus {
  renewing,

  /// Auto-renew is off: access lasts until [StudyPlanSubscription.endsAt].
  cancelled,

  /// Paused in Google Play: no access and no charge until it resumes.
  paused,

  /// The store could not take the payment and is retrying.
  paymentIssue,

  /// The store has not said.
  unknown;

  static RenewalStatus parse(String? value) => switch (value) {
    'renewing' => RenewalStatus.renewing,
    'cancelled' => RenewalStatus.cancelled,
    'paused' => RenewalStatus.paused,
    'payment_issue' => RenewalStatus.paymentIssue,
    _ => RenewalStatus.unknown,
  };
}

/// A student's paid plan as the store bills it, for the Plans screen. It
/// describes; the server's [StudyPlan] decides access.
@immutable
class StudyPlanSubscription {
  const StudyPlanSubscription({
    required this.tier,
    required this.renewal,
    this.endsAt,
    this.store,
    this.storeProductId,
    this.paidByMe = true,
  });

  final StudyPlanTier tier;
  final RenewalStatus renewal;

  /// When the paid-for period (or a payment grace period) ends.
  final DateTime? endsAt;
  final SubscriptionStore? store;
  final String? storeProductId;

  /// False when a parent pays: only they can change or cancel it.
  final bool paidByMe;
}

/// The store's own page for changing, pausing or cancelling a subscription.
/// Stores do not let an app cancel on the subscriber's behalf, so the app
/// sends them here. Google Play opens straight on the plan when it knows
/// the product and the app's package.
Uri manageSubscriptionUri(
  SubscriptionStore store, {
  String? storeProductId,
  String? androidPackage,
}) => switch (store) {
  SubscriptionStore.appStore => Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  ),
  SubscriptionStore.playStore =>
    storeProductId != null && androidPackage != null
        ? Uri.https('play.google.com', '/store/account/subscriptions', {
            'sku': storeProductId,
            'package': androidPackage,
          })
        : Uri.parse('https://play.google.com/store/account/subscriptions'),
};

/// Why a purchase was stopped before the store sheet, to prevent a second
/// subscription and a second charge.
enum PurchaseBlock {
  /// This plan, or one that includes it, is already active.
  alreadySubscribed,

  /// A parent pays for the current plan; only they can change it.
  paidByParent,

  /// The current plan is billed by the other store; change it there.
  otherStore,

  /// Google Play can only upgrade a subscription bought with the Google
  /// account on this phone.
  upgradeNeedsOriginalAccount,
}

class PurchaseBlockedException implements Exception {
  const PurchaseBlockedException(this.reason);
  final PurchaseBlock reason;

  @override
  String toString() => 'PurchaseBlockedException($reason)';
}

/// Buying a plan through the App Store or Google Play (PAY-071).
abstract interface class StudyPlanSubscriptionRepository {
  /// The store this device buys through, or null where there is none (web,
  /// desktop): plans are then described but bought in the mobile app.
  SubscriptionStore? get purchaseStore;

  /// The student's current paid subscription, or null.
  Future<StudyPlanSubscription?> subscription();

  Future<StudyPlanOffer> offer(StudyPlanTier tier);
  Future<void> requestApproval(StudyPlanTier tier);
  Future<void> purchase(StudyPlanTier tier);
  Future<void> restorePurchases();
  void addEntitlementListener(VoidCallback listener);
  void removeEntitlementListener(VoidCallback listener);
}
