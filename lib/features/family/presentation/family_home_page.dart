import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/runtime_environment.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../domain/family.dart';
import 'family_challenge_page.dart';
import 'child_progress_page.dart';
import 'family_scope.dart';
import 'family_strings.dart';

/// Guardian home on authoritative `/v1` data (MOB-070 parent slice).
/// Replaces the legacy SQLite home in real builds: children come from the
/// guardian's own links, and only a verified link opens a child's records.
class FamilyHomePage extends StatefulWidget {
  const FamilyHomePage({super.key, this.onOpenChild, this.actions = const []});

  /// App bar actions supplied by the host shell, such as its account entry.
  final List<Widget> actions;

  /// Called when a guardian opens a verified child, so the shell can make
  /// that child the active one for the other tabs.
  final void Function(GuardianChild child)? onOpenChild;

  @override
  State<FamilyHomePage> createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends State<FamilyHomePage> {
  List<GuardianChild> _children = const [];
  List<PurchaseApprovalRequest> _approvals = const [];
  bool _loading = true;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final interactor = FamilyScope.of(context);
    final children = await interactor.children();
    final approvals = await interactor.pendingApprovals();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _approvals = approvals;
      children.fold(
        onSuccess: (list) {
          _children = list;
          _failure = null;
        },
        onFailure: (failure) => _failure = failure,
      );
    });
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

  Future<void> _linkChild() async {
    final linked = await showModalBottomSheet<GuardianChild>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _LinkChildSheet(),
      ),
    );
    if (linked == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          familyText(context, 'link.sent', {'name': linked.studentName}),
        ),
      ),
    );
    await _load();
  }

  Future<void> _decide(PurchaseApprovalRequest request, bool approve) async {
    final result = await FamilyScope.of(context)
        .decide(request.id, approve: approve);
    if (!mounted) return;
    final message = result.fold(
      onSuccess: (_) => familyText(context, 'approvals.done'),
      onFailure: (failure) => familyFailureText(context, failure),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  void _open(GuardianChild child) {
    widget.onOpenChild?.call(child);
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ChildProgressPage(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => familyText(context, key);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: studafyCanvas,
        title: Text(t('title')),
        actions: widget.actions,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: t('error.title'),
              message: familyFailureText(context, _failure!),
              actionLabel: t('retry'),
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 96),
                children: [
                  if (_approvals.isNotEmpty) ...[
                    _SectionTitle(t('approvals.title')),
                    for (final request in _approvals)
                      _ApprovalCard(
                        request: request,
                        onApprove: () => _decide(request, true),
                        onDecline: () => _decide(request, false),
                      ),
                    const SizedBox(height: 16),
                  ],
                  StudafyHero(
                    eyebrow:
                        Localizations.localeOf(context).languageCode == 'ar'
                        ? 'معًا، كل يوم'
                        : 'TOGETHER, EVERY DAY',
                    title: t('children'),
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'ar'
                        ? 'عالمهم ينمو. كن جزءًا منه.'
                        : 'Their world is growing. Be part of it.',
                    icon: Icons.favorite_rounded,
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 600 ? 3 : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 14) / columns;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final child in _children)
                            SizedBox(
                              width: width,
                              child: _ChildCard(
                                child: child,
                                onOpen: child.isVerified
                                    ? () => _open(child)
                                    : null,
                              ),
                            ),
                          SizedBox(
                            width: width,
                            child: Semantics(
                              button: true,
                              label: t('link'),
                              child: Material(
                                color: const Color(0xFFECEBFF),
                                borderRadius: BorderRadius.circular(26),
                                child: InkWell(
                                  onTap: _linkChild,
                                  borderRadius: BorderRadius.circular(26),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 30,
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: .7,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            size: 34,
                                            color: studafyNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          t('link'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: studafyNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          Localizations.localeOf(context)
                                                      .languageCode ==
                                                  'ar'
                                              ? 'ابدأ بمعرّف طفلك'
                                              : 'Start with their ID',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: studafyMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_children.isEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      t('empty.message'),
                      style: const TextStyle(color: studafyMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          color: studafyInk,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, this.onOpen});

  final GuardianChild child;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final verified = child.isVerified;
    final colors = [
      const Color(0xFFDFF5EB),
      const Color(0xFFFFEBD6),
      const Color(0xFFE7E4FF),
      const Color(0xFFDDEFFD),
    ];
    final tint =
        colors[child.studentId.codeUnits.fold(0, (a, b) => a + b) %
            colors.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    child.studentName.isEmpty
                        ? '?'
                        : child.studentName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: studafyInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                child.studentName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: studafyInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                child.schoolName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: studafyMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    verified
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: verified ? const Color(0xFF087B61) : studafyMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      familyText(context, 'status.${child.status.name}'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: verified
                            ? const Color(0xFF087B61)
                            : studafyMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      tint: const Color(0xFFF2B01E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            familyText(context, 'approvals.detail', {
              'name': request.studentName,
            }),
            style: const TextStyle(color: studafyInk),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDecline,
                child: Text(familyText(context, 'approvals.decline')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onApprove,
                child: Text(familyText(context, 'approvals.approve')),
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
    String? captchaToken;
    if (const bool.fromEnvironment('TURNSTILE_ENABLED') &&
        !StudafyRuntime.policy.isSynthetic &&
        _code.text.trim().isNotEmpty) {
      final base = Uri.tryParse(
        const String.fromEnvironment('STUDAFY_API_URL'),
      );
      if (base == null || !base.hasAuthority) {
        setState(() {
          _busy = false;
          _message = familyText(context, 'error.title');
        });
        return;
      }
      captchaToken = await Navigator.of(context).push<String>(
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
      if (!mounted) return;
      if (captchaToken == null) {
        setState(() => _busy = false);
        return;
      }
    }
    if (!mounted) return;
    final result = await FamilyScope.of(context)
        .locate(_code.text, captchaToken: captchaToken);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold(
        onSuccess: (student) {
          _found = student;
          if (student == null) {
            _message = familyText(context, 'link.notFound');
          }
        },
        onFailure: (failure) => _message = familyFailureText(context, failure),
      );
    });
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
        _message = familyFailureText(context, failure);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => familyText(context, key);
    final found = _found;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('link.title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: t('link.hint'),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _find(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _find,
                  child: Text(t('link.find')),
                ),
              ],
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!),
              ),
            if (found != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  onPressed: _busy ? null : _request,
                  child: Text(
                    familyText(context, 'link.confirm', {
                      'name': found.displayName,
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
