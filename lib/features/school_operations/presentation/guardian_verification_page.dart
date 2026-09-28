import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/school_operations_repository.dart';

class GuardianVerificationPage extends StatefulWidget {
  const GuardianVerificationPage({super.key, required this.repository});
  final SchoolOperationsRepository repository;
  @override
  State<GuardianVerificationPage> createState() =>
      _GuardianVerificationPageState();
}

class _GuardianVerificationPageState extends State<GuardianVerificationPage> {
  final _linkId = TextEditingController();
  int _expiresInDays = 365;
  bool _busy = false;

  @override
  void dispose() {
    _linkId.dispose();
    super.dispose();
  }

  Future<void> _act(bool verify) async {
    if (_linkId.text.trim().isEmpty || _busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              verify
                  ? AppL10n.of(context)
                        .guardianVerifyConfirmGuardianVerification
                  : AppL10n.of(context).guardianVerifyRevokeGuardianAccess,
            ),
            content: Text(
              verify
                  ? AppL10n.of(context).guardianVerifyVerifyOnlyAfterCheckingThe
                  : AppL10n.of(context)
                        .guardianVerifyThisRemovesAccessGrantedBy,
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
    try {
      final status = verify
          ? await widget.repository.verifyGuardianLink(
              linkId: _linkId.text,
              expiresInDays: _expiresInDays,
            )
          : await widget.repository.revokeGuardianLink(_linkId.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showMessage(
          '${AppL10n.of(context).guardianVerifyLinkStatus}: $status',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showMessage(Failure.fromError(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(AppL10n.of(context).guardianVerifyGuardianVerification),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppL10n.of(context).guardianVerifyEnterTheLinkIdSupplied,
                style: const TextStyle(color: studafyMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkId,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).guardianVerifyGuardianLinkId,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _expiresInDays,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context)
                      .guardianVerifyVerificationPeriod,
                ),
                items: [30, 90, 180, 365]
                    .map(
                      (days) => DropdownMenuItem(
                        value: days,
                        child: Text(
                          '$days ${AppL10n.of(context).guardianVerifyDays}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _expiresInDays = value!),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : () => _act(true),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(AppL10n.of(context).guardianVerifyVerifyLink),
              ),
              TextButton(
                onPressed: _busy ? null : () => _act(false),
                child: Text(
                  AppL10n.of(context).guardianVerifyRevokeLink,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
