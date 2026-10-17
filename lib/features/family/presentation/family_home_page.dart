import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/result.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/family.dart';
import 'child_progress_page.dart';
import 'family_challenge_page.dart';
import 'family_scope.dart';
import 'family_strings.dart';

/// Guardian home on authoritative `/v1` data (MOB-070 parent slice).
/// Replaces the legacy SQLite home in real builds: children come from the
/// guardian's own links, and only a verified link opens a child's records.

/// The server's request for a bot check, as opposed to a refusal.
const captchaRequiredCode = 'CAPTCHA_REQUIRED';

class FamilyHomePage extends StatefulWidget {
  const FamilyHomePage({
    super.key,
    this.onOpenChild,
    this.onCreateChildAccount,
    this.actions = const [],
    this.sections = const [],
    this.quickActions = const [],
    this.onChildrenChanged,
  });

  /// Shortcuts to the parent's other workflows, built by the shell.
  final List<FamilyQuickAction> quickActions;

  /// Every time the children are read, so the shell's other tabs (Learning,
  /// Announcements) filter by the same list.
  final ValueChanged<List<GuardianChild>>? onChildrenChanged;

  /// Creates an account for a child who has none, from the parent's own
  /// account. Supplied by the shell, which owns the device's accounts; null
  /// where this account may not create one, and "Link a child" then only
  /// finds a child by their Studafy ID.
  final Future<void> Function()? onCreateChildAccount;

  /// App bar actions supplied by the host shell, such as its account entry.
  final List<Widget> actions;

  /// Further sections under the children, supplied by the host shell - such
  /// as upcoming meetings, which belong to another feature.
  final List<Widget> sections;

  /// Called when a guardian opens a verified child, so the shell can make
  /// that child the active one for the other tabs.
  final void Function(GuardianChild child)? onOpenChild;

  @override
  State<FamilyHomePage> createState() => FamilyHomePageState();
}

class FamilyHomePageState extends State<FamilyHomePage> {
  List<GuardianChild> _children = const [];
  List<PurchaseApprovalRequest> _approvals = const [];
  bool _loading = true;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Once the page has been shown, a pull keeps it on screen and swaps in
  /// what comes back, rather than blanking to a spinner.
  bool _loaded = false;

  Future<void> _load() async {
    if (!_loaded) setState(() => _loading = true);
    final interactor = FamilyScope.of(context);
    // Both at once: neither waits on the other.
    final approvalsRead = interactor.pendingApprovals();
    final children = await interactor.children();
    final approvals = await approvalsRead;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loaded = true;
      _approvals = approvals;
      children.fold(
        onSuccess: (list) {
          _children = list;
          _failure = null;
        },
        onFailure: (failure) => _failure = failure,
      );
    });
    widget.onChildrenChanged?.call(_children);
    _keepSelectionValid();
  }

  /// The other tabs follow the selected child. Select the first verified
  /// child when none is selected, and drop a selection whose link is no
  /// longer verified, so no tab keeps showing a child the guardian lost.
  void _keepSelectionValid() {
    final verified = [
      for (final child in _children)
        if (child.isVerified) child,
    ];
    final selected = ActiveContextController.instance.selectedStudent?.id;
    if (verified.any((child) => child.studentId == selected)) return;
    if (verified.isEmpty) {
      if (selected != null) {
        ActiveContextController.instance.selectStudent(null);
      }
      return;
    }
    widget.onOpenChild?.call(verified.first);
  }

  /// A child either has an account to link to, or the parent makes one.
  Future<void> linkChild() => _linkChild();

  Future<void> _linkChild() async {
    final create = widget.onCreateChildAccount;
    if (create != null) {
      final choice = await showModalBottomSheet<_LinkChoice>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _LinkChoiceSheet(),
      );
      if (choice == null || !mounted) return;
      if (choice == _LinkChoice.create) {
        await create();
        if (mounted) await _load();
        return;
      }
    }
    final linked = await showModalBottomSheet<GuardianChild>(
      context: context,
      isScrollControlled: true,
      // Typing grows the sheet; it stops below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _LinkChildSheet(),
      ),
    );
    if (linked == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showMessage(AppL10n.of(context).famLinkSent(linked.studentName));
    await _load();
  }

  Future<void> _decide(PurchaseApprovalRequest request, bool approve) async {
    final result = await FamilyScope.of(context)
        .decide(request.id, approve: approve);
    if (!mounted) return;
    final message = result.fold(
      onSuccess: (_) => AppL10n.of(context).famApprovalsDone,
      onFailure: (failure) => familyFailureText(context, failure),
    );
    ScaffoldMessenger.of(context).showMessage(message);
    await _load();
  }

  void _open(GuardianChild child) {
    widget.onOpenChild?.call(child);
    Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(builder: (_) => ChildProgressPage(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = (ActiveContextController.instance.profile?.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final today = studafyFullDate(context, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        // The brand heads the home screen, as for every role.
        title: const StudafyLogo(size: 26),
        titleSpacing: 20,
        actions: widget.actions,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? Center(
              child: StudafyEmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.famErrorTitle,
                message: familyFailureText(context, _failure!),
                actionLabel: l10n.famRetry,
                onAction: _load,
              ),
            )
          : StudafyRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                children: [
                  StudafyHero(
                    eyebrow: today,
                    title: name.isEmpty
                        ? l10n.todayHello
                        : l10n.todayHelloName(name),
                    subtitle: l10n.parentTodaySubtitle,
                    icon: Icons.favorite_rounded,
                  ),
                  if (_approvals.isNotEmpty) ...[
                    SectionHeader(l10n.famApprovalsTitle),
                    for (final request in _approvals)
                      _ApprovalCard(
                        request: request,
                        onApprove: () => _decide(request, true),
                        onDecline: () => _decide(request, false),
                      ),
                  ],
                  SectionHeader(
                    l10n.parentChildrenSection,
                    // Compact and labelled: linking is one action among
                    // several, not the whole page.
                    action: _children.isEmpty
                        ? null
                        : TextButton.icon(
                            onPressed: _linkChild,
                            icon: const Icon(
                              Icons.person_add_rounded,
                              size: 19,
                            ),
                            label: Text(l10n.parentQuickLink),
                          ),
                  ),
                  if (_children.isEmpty)
                    FeatureCard(
                      child: Column(
                        children: [
                          const IconBadge(
                            icon: Icons.family_restroom_rounded,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.parentNoChildrenTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: studafyInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.parentNoChildrenBody,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: studafyMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _linkChild,
                            icon: const Icon(Icons.person_add_rounded),
                            label: Text(l10n.parentQuickLink),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final child in _children)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ChildRow(
                          child: child,
                          onOpen: child.isVerified ? () => _open(child) : null,
                        ),
                      ),
                  if (widget.quickActions.isNotEmpty) ...[
                    SectionHeader(l10n.todayQuickActions),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 560 ? 4 : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 10) /
                            columns;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final action in widget.quickActions)
                              SizedBox(
                                width: width,
                                child: _QuickActionTile(action: action),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  ...widget.sections,
                ],
              ),
            ),
    );
  }
}

/// A shortcut on the parent's Today, wired by the shell. [linksChild] marks
/// the one that opens "Link a child" on this page itself.
@immutable
class FamilyQuickAction {
  const FamilyQuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.linksChild = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool linksChild;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final FamilyQuickAction action;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<FamilyHomePageState>();
    final onTap = action.linksChild ? state?.linkChild : action.onTap;
    return FeatureCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
      child: Row(
        children: [
          IconBadge(icon: action.icon, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: studafyInk,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One linked child: who, which school, and whether the link is approved.
class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child, this.onOpen});

  final GuardianChild child;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final verified = child.isVerified;
    return FeatureCard(
      onTap: onOpen,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
      child: Row(
        children: [
          InitialsAvatar(name: child.studentName, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserContentText(
                  child.studentName,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (child.schoolName.isNotEmpty)
                  UserContentText(
                    child.schoolName,
                    style: const TextStyle(color: studafyMuted, fontSize: 13),
                  ),
                const SizedBox(height: 6),
                StatusPill(
                  label: familyText(context, 'status.${child.status.name}'),
                  icon: verified
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: verified ? studafyTeal : studafyMuted,
                ),
              ],
            ),
          ),
          if (onOpen != null)
            Icon(forwardChevron(context), color: studafyMuted),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
  });

  final PurchaseApprovalRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: FeatureCard(
      tint: studafyTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppL10n.of(context)
                .famApprovalsDetail(request.studentName, request.featureKey),
            style: const TextStyle(color: studafyInk),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDecline,
                child: Text(AppL10n.of(context).famApprovalsDecline),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onApprove,
                child: Text(AppL10n.of(context).famApprovalsApprove),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LinkChildSheet extends StatefulWidget {
  const _LinkChildSheet();

  @override
  State<_LinkChildSheet> createState() => _LinkChildSheetState();
}

class _LinkChildSheetState extends State<_LinkChildSheet> {
  final _code = TextEditingController();
  LocatedStudent? _found;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _message = null;
      _found = null;
    });
    // Ask first, and prove a person is asking only when the server says so.
    // This used to decide from a build flag, and a flag that disagreed with
    // the server opened a challenge page the server did not serve - which is
    // how a parent linking a child ended up looking at a raw error.
    var result = await FamilyScope.of(context).locate(_code.text);
    if (!mounted) return;
    if (result case FailureResult(
      failure: Failure(code: captchaRequiredCode),
    )) {
      final captchaToken = await _challenge();
      if (!mounted) return;
      if (captchaToken == null) {
        setState(() => _busy = false);
        return;
      }
      result = await FamilyScope.of(context)
          .locate(_code.text, captchaToken: captchaToken);
      if (!mounted) return;
      // Refused even with a fresh check: the check itself did not hold.
      if (result case FailureResult(
        failure: Failure(code: Failure.forbiddenCode),
      )) {
        setState(() {
          _busy = false;
          _message = AppL10n.of(context).famLinkCheckFailed;
        });
        return;
      }
    }
    setState(() {
      _busy = false;
      result.fold(
        onSuccess: (student) {
          _found = student;
          if (student == null) {
            _message = AppL10n.of(context).famLinkNotFound;
          }
        },
        onFailure: (failure) => _message = familyFailureText(context, failure),
      );
    });
  }

  /// Opens the server's own bot-check page and returns the token it issues,
  /// or null when the parent backs out or no API address is configured.
  Future<String?> _challenge() async {
    final base = Uri.tryParse(const String.fromEnvironment('STUDAFY_API_URL'));
    if (base == null || !base.hasAuthority) {
      setState(() => _message = AppL10n.of(context).famErrorTitle);
      return null;
    }
    return await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute(
        builder: (_) => FamilyChallengePage(
          url: base.replace(
            path: '/auth/bot-check',
            queryParameters: {
              'lang': Localizations.localeOf(context).languageCode,
            },
          ),
        ),
      ),
    );
  }

  Future<void> _request() async {
    final student = _found;
    if (student == null) return;
    setState(() => _busy = true);
    final result = await FamilyScope.of(context).requestLink(student.studentId);
    if (!mounted) return;
    result.fold(
      onSuccess: (child) => Navigator.pop(context, child),
      onFailure: (failure) => setState(() {
        _busy = false;
        // The server refuses a second request for the same child.
        _message = failure.code == Failure.validationCode
            ? AppL10n.of(context).famLinkAlready
            : familyFailureText(context, failure);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppL10n.of(context).famLinkTitle,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).famLinkIdHelp,
              style: const TextStyle(color: studafyMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              autofocus: true,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: AppL10n.of(context).famLinkHint,
                prefixIcon: const Icon(Icons.qr_code_rounded),
              ),
              onSubmitted: (_) => _find(),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    style: const TextStyle(color: studafyDanger, height: 1.4),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            if (found == null)
              FilledButton.icon(
                onPressed: _busy ? null : _find,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _busy
                      ? AppL10n.of(context).parentLinkSearching
                      : AppL10n.of(context).famLinkFind,
                ),
              )
            else ...[
              FeatureCard(
                child: Row(
                  children: [
                    InitialsAvatar(name: found.displayName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: UserContentText(
                        found.displayName,
                        style: const TextStyle(
                          color: studafyInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _request,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  AppL10n.of(context).famLinkConfirm(found.displayName),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _LinkChoice { find, create }

/// "Link a child": find a child who has an account, or create one for a
/// child who has none (no email or phone). A created account is the
/// parent's to manage, so the child has nothing to approve.
class _LinkChoiceSheet extends StatelessWidget {
  const _LinkChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    Widget option(
      _LinkChoice choice,
      IconData icon,
      String title,
      String body,
    ) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: studafyCyan, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(body),
        ),
        onTap: () => Navigator.pop(context, choice),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.famLinkTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            option(
              _LinkChoice.find,
              Icons.person_search_rounded,
              l10n.famLinkHasAccount,
              l10n.famLinkHasAccountBody,
            ),
            option(
              _LinkChoice.create,
              Icons.person_add_alt_1_rounded,
              l10n.famLinkCreateAccount,
              l10n.famLinkCreateAccountBody,
            ),
          ],
        ),
      ),
    );
  }
}
