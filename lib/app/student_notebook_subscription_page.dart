import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/studafy_design.dart';
import '../features/notebook/domain/notebook_subscription_repository.dart';
import '../l10n/generated/app_l10n.dart';

/// No lesson widgets (or their requests) are mounted until the server confirms
/// access. Losing access, resuming, or returning to this tab rechecks authority.
class StudentNotebookSubscriptionPage extends StatefulWidget {
  const StudentNotebookSubscriptionPage({
    super.key,
    required this.subscription,
    required this.contentBuilder,
    this.visible = true,
  });
  final NotebookSubscriptionRepository? subscription;
  final WidgetBuilder contentBuilder;
  final bool visible;

  @override
  State<StudentNotebookSubscriptionPage> createState() => _NotebookState();
}

class _NotebookState extends State<StudentNotebookSubscriptionPage>
    with WidgetsBindingObserver {
  NotebookSubscription? _status;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  Timer? _expiry;
  int _generation = 0;
  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.subscription?.addEntitlementListener(_refresh);
    if (widget.visible) _refresh();
  }

  @override
  void didUpdateWidget(StudentNotebookSubscriptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscription != widget.subscription) {
      oldWidget.subscription?.removeEntitlementListener(_refresh);
      widget.subscription?.addEntitlementListener(_refresh);
    }
    if (widget.visible &&
        (!oldWidget.visible || oldWidget.subscription != widget.subscription)) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.visible) _refresh();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.subscription?.removeEntitlementListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _expiry?.cancel();
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final status =
          await widget.subscription?.notebookStatus() ??
          const NotebookSubscription();
      if (!mounted || generation != _generation) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      if (status.active && status.expiresAt != null) {
        final until = status.expiresAt!.difference(DateTime.now());
        _expiry = Timer(until.isNegative ? Duration.zero : until, _refresh);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _message = AppL10n.of(context).notebookActionFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _open(String value) async {
    if (!_validUrl(value)) return;
    try {
      if (await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Present a safe message below. */
    }
    if (mounted) {
      setState(() => _message = AppL10n.of(context).notebookOpenPageFailed);
    }
  }

  String get _manageUrl => defaultTargetPlatform == TargetPlatform.iOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final l10n = AppL10n.of(context);
    final status = _status;
    if (status != null &&
        status.active &&
        (status.expiresAt == null ||
            status.expiresAt!.isAfter(DateTime.now()))) {
      return Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: studafyCyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.notebookActive)),
                  TextButton(
                    onPressed: () => _open(_manageUrl),
                    child: Text(l10n.notebookManage),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: widget.contentBuilder(context)),
        ],
      );
    }
    final repository = widget.subscription;
    final canBuy =
        status?.canPurchase == true && _validUrl(_terms) && _validUrl(_privacy);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notebookTitle),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.notebookRefresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StudafyHero(
            eyebrow: l10n.notebookHeroEyebrow,
            title: l10n.notebookHeroTitle,
            subtitle: l10n.notebookHeroSubtitle,
            icon: Icons.auto_stories_rounded,
          ),
          const SizedBox(height: 24),
          FeatureCard(
            tint: studafyCyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notebookPlanName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (status?.storeAvailable == true && status!.monthly) ...[
                  // The store's formatted price already carries its own
                  // currency symbol for this storefront, so the currency code
                  // is not appended: that would read "JOD 1.77 JOD".
                  Text(
                    l10n.notebookPricePerMonth(status.price),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.oneMonthTrial
                        ? l10n.notebookTrialThenPrice(status.price)
                        : l10n.notebookNoTrial,
                  ),
                ] else ...[
                  // No store terms: say the store confirms the price rather
                  // than naming one. Tiers differ per storefront, so a USD
                  // figure would be wrong for most buyers (Apple 3.1.2).
                  Text(
                    l10n.notebookPriceUnconfirmed,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.notebookPriceUnconfirmedDetail),
                ],
                const SizedBox(height: 16),
                Text(l10n.notebookScope),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (status == null) Text(l10n.notebookStatusUnavailable),
          if (status != null && !status.selfPurchaseEnabled)
            Text(l10n.notebookSelfPurchaseDisabled),
          if (status?.selfPurchaseEnabled == true &&
              status?.approval != 'approved') ...[
            Text(l10n.notebookApprovalRequired),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy || status?.approval == 'requested' || repository == null
                  ? null
                  : () => _perform(
                      repository.requestNotebookApproval,
                      l10n.notebookApprovalRequestSent,
                    ),
              icon: const Icon(Icons.family_restroom_rounded),
              label: Text(
                status?.approval == 'requested'
                    ? l10n.notebookApprovalWaiting
                    : l10n.notebookApprovalAsk,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || !canBuy || repository == null
                ? null
                : () => _perform(
                    repository.purchaseNotebook,
                    l10n.notebookPurchaseStarted,
                  ),
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(
              status?.oneMonthTrial == true
                  ? l10n.notebookStartFreeMonth
                  : l10n.notebookSubscribeMonthly,
            ),
          ),
          if (!canBuy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.notebookCheckoutUnavailable),
            ),
          TextButton(
            onPressed: _busy || repository == null
                ? null
                : () => _perform(
                    repository.restorePurchases,
                    l10n.notebookRestoreRequested,
                  ),
            child: Text(l10n.notebookRestore),
          ),
          TextButton(
            onPressed: () => _open(_manageUrl),
            child: Text(l10n.notebookManageOrCancel),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!, semanticsLabel: _message),
            ),
          const SizedBox(height: 12),
          Text(
            l10n.notebookRenewalDisclosure,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: _validUrl(_terms) ? () => _open(_terms) : null,
                child: Text(l10n.notebookTermsOfUse),
              ),
              TextButton(
                onPressed: _validUrl(_privacy) ? () => _open(_privacy) : null,
                child: Text(l10n.notebookPrivacyPolicy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
