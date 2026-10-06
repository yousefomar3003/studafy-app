import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/family.dart';
import 'family_scope.dart';
import 'family_strings.dart';

class StudentFamilyPage extends StatefulWidget {
  const StudentFamilyPage({super.key});
  @override
  State<StudentFamilyPage> createState() => _StudentFamilyPageState();
}

class _StudentFamilyPageState extends State<StudentFamilyPage> {
  StudentFamily? _family;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FamilyScope.of(context).studentFamily();
    if (!mounted) return;
    setState(
      () => result.fold(
        onSuccess: (value) {
          _family = value;
          _error = null;
        },
        onFailure: (failure) => _error = familyFailureText(context, failure),
      ),
    );
  }

  Future<void> _decide(StudentGuardianRequest request, String decision) async {
    if (_busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              decision == 'approve'
                  ? AppL10n.of(context).studentFamilyIsThisYourParent
                  : AppL10n.of(context).studentFamilyConfirmYourChoice,
            ),
            content: Text(
              decision == 'approve'
                  ? AppL10n.of(context)
                        .studentFamilyOnlyApproveGuardiannameIfYou(
                          request.guardianName,
                        )
                  : AppL10n.of(context).studentFamilyThisPersonWillNotHave,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppL10n.of(context).academicCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppL10n.of(context).studentFamilyConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    final result = await FamilyScope.of(context)
        .decideGuardian(request.id, decision);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) => _load(),
      onFailure: (failure) =>
          ScaffoldMessenger.of(context)
              .showMessage(familyFailureText(context, failure)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppL10n.of(context).studentFamilyMyFamily)),
    body: StudafyRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StudafyHero(
            eyebrow: AppL10n.of(context).studentFamilyYourConnections,
            title: AppL10n.of(context).studentFamilyYourFamilyYourChoice,
            subtitle: AppL10n.of(context).studentFamilyShareYourStudafyIdWith,
            icon: Icons.favorite_outline_rounded,
          ),
          const SizedBox(height: 24),
          if (_error != null)
            StudafyStatusCard(
              icon: Icons.wifi_off_rounded,
              title: AppL10n.of(context).studentFamilyCouldNotLoadRequests,
              message: _error!,
              actionLabel: AppL10n.of(context).securityTryAgain,
              onAction: _load,
            )
          else if (_family == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            // A student has one Studafy ID, however many teachers' classes
            // they are in, so it is shown once.
            for (final identity in _family!.identities.take(1))
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppL10n.of(context).studentFamilyMyStudafyId,
                      style: const TextStyle(
                        color: studafyMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            identity.studafyId,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: AppL10n.of(context).studentFamilyCopyId,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: identity.studafyId),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showMessage(
                                AppL10n.of(context).studentFamilyIdCopied,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_family!.identities.isEmpty)
              Text(AppL10n.of(context).studentFamilyJoinAClassToActivate),
            const SizedBox(height: 24),
            Text(
              AppL10n.of(context).studentFamilyParentRequests,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_family!.requests.isEmpty)
              StudafyStatusCard(
                icon: Icons.mark_email_read_outlined,
                title: AppL10n.of(context).studentFamilyAllCaughtUp,
                message: AppL10n.of(context)
                    .studentFamilyNewParentRequestsWillAppear,
              ),
            for (final request in _family!.requests)
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE8E5FF),
                          foregroundColor: studafyNavy,
                          child: Text(
                            request.guardianName.characters.firstOrNull ?? '?',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request.guardianName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '${AppL10n.of(context).studentFamilyAccountId}: ${request.guardianId}',
                      style: const TextStyle(fontSize: 12, color: studafyMuted),
                    ),
                    const SizedBox(height: 12),
                    if (request.status == GuardianLinkStatus.pending)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'approve'),
                            child: Text(
                              AppL10n.of(context).studentFamilyThisIsMyParent,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'decline'),
                            child: Text(
                              AppL10n.of(context).studentFamilyDecline,
                            ),
                          ),
                        ],
                      )
                    else if (request.status == GuardianLinkStatus.verified)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppL10n.of(context).studentFamilyConnected,
                              style: const TextStyle(color: studafyCyan),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'revoke'),
                            child: Text(
                              AppL10n.of(context).studentFamilyRemoveAccess,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        request.status == GuardianLinkStatus.declined
                            ? AppL10n.of(context).studentFamilyDeclined
                            : AppL10n.of(context).studentFamilyAccessRemoved,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
