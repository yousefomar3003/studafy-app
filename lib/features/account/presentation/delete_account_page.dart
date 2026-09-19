import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../../core/account_lifecycle.dart';
import '../application/account_interactor.dart';

/// In-app account deletion (AUTH-030, Apple 5.1.1(v), Google Play).
///
/// Two things make this a real deletion flow rather than a form:
///
/// - The impact summary is the server's, not copy. It states, with counts,
///   what is removed and what the school retains. A student cannot delete
///   records the school owns; saying so precisely is the difference between a
///   lawful retention boundary and what a reviewer reads as a broken flow.
/// - Cancellation happens here, in the app. The previous copy told users to
///   contact support, which does not satisfy either store.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.email,
    required this.account,
  });

  final String email;
  final AccountInteractor account;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final confirmation = TextEditingController();

  bool loading = true;
  String? loadError;
  DeletionImpact? impact;
  DeletionRequest? scheduled;

  String? reason;
  bool exported = false;
  bool understood = false;
  bool schoolRecords = false;
  bool submitting = false;

  /// Reason codes are the server's vocabulary and never change with language;
  /// only the label the user reads does.
  static const _reasonCodes = <String>[
    'no_longer_using',
    'changing_schools',
    'privacy_concern',
    'duplicate_account',
    'undisclosed',
  ];

  static String _reasonLabel(AppL10n l10n, String code) => switch (code) {
    'no_longer_using' => l10n.deleteReasonNoLongerUsing,
    'changing_schools' => l10n.deleteReasonChangingSchools,
    'privacy_concern' => l10n.deleteReasonPrivacy,
    'duplicate_account' => l10n.deleteReasonDuplicate,
    _ => l10n.deleteReasonUndisclosed,
  };

  /// Typed literally by the user and compared character for character, so it
  /// is deliberately not translated.
  static const _confirmationWord = 'DELETE';

  bool get ready =>
      exported &&
      understood &&
      schoolRecords &&
      reason != null &&
      confirmation.text.trim() == _confirmationWord &&
      !submitting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    final result = await widget.account.loadImpact();
    if (!mounted) return;
    result.fold(
      onSuccess: (value) => setState(() {
        impact = value;
        loading = false;
      }),
      onFailure: (failure) => setState(() {
        loadError = failure.message;
        loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(AppL10n.of(context).deleteTitle),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? _ErrorState(message: loadError!, onRetry: _load)
        : scheduled != null
        ? _ScheduledState(
            email: widget.email,
            request: scheduled!,
            onCancel: _cancelDeletion,
          )
        : _form(),
  );

  Widget _form() {
    final summary = impact!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB42318)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppL10n.of(context).deleteWarningTitle,
                      style: const TextStyle(
                        color: Color(0xFF7A271A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppL10n.of(context).deleteWarningBody,
                      style: const TextStyle(color: Color(0xFF7A271A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SettingsLabel(AppL10n.of(context).deleteWhatGoesHeading),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              for (final entry in summary.deletedPersonalRecords.entries)
                _CountRow(
                  label: _friendly(AppL10n.of(context), entry.key),
                  count: entry.value,
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SettingsLabel(AppL10n.of(context).deleteSchoolKeepsHeading),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 10),
                child: Text(
                  AppL10n.of(context).deleteSchoolKeepsBody,
                  style: const TextStyle(color: studafyMuted),
                ),
              ),
              for (final entry in summary.retainedSchoolRecords.entries)
                _CountRow(
                  label: _friendly(AppL10n.of(context), entry.key),
                  count: entry.value,
                ),
              if (summary.retainedTotal == 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: Text(AppL10n.of(context).deleteNoSchoolRecords),
                ),
            ],
          ),
        ),
        if (summary.schools.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SettingsLabel(AppL10n.of(context).deleteSchoolAccessHeading),
          const SizedBox(height: 8),
          FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final school in summary.schools)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    // The school's own name, shown as the school wrote it.
                    child: UserContentText(school),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        _SettingsLabel(AppL10n.of(context).deleteWhyHeading),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: reason,
          decoration: InputDecoration(
            labelText: AppL10n.of(context).deleteReasonLabel,
          ),
          items: [
            for (final code in _reasonCodes)
              DropdownMenuItem(
                value: code,
                child: Text(_reasonLabel(AppL10n.of(context), code)),
              ),
          ],
          onChanged: (value) => setState(() => reason = value),
        ),
        const SizedBox(height: 22),
        _SettingsLabel(AppL10n.of(context).deleteAcknowledgementsHeading),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: exported,
                title: Text(AppL10n.of(context).deleteSavedWhatINeed),
                subtitle: Text(AppL10n.of(context).deleteSavedWhatINeedDetail),
                onChanged: (v) => setState(() => exported = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: understood,
                title: Text(
                  AppL10n.of(context)
                      .deleteUnderstandFinal(summary.gracePeriodDays),
                ),
                subtitle: Text(
                  AppL10n.of(context)
                      .deleteCancelWindow(summary.gracePeriodDays),
                ),
                onChanged: (v) => setState(() => understood = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: schoolRecords,
                title: Text(AppL10n.of(context).deleteUnderstandSchoolKeeps),
                subtitle: Text(
                  AppL10n.of(context)
                      .deleteRetainedCount(summary.retainedTotal),
                ),
                onChanged: (v) => setState(() => schoolRecords = v ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          AppL10n.of(context)
              .deleteTypeToConfirm(_confirmationWord, widget.email),
          style: const TextStyle(
            color: studafyInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: confirmation,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: _confirmationWord),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
          ),
          onPressed: ready ? _requestDeletion : null,
          child: Text(
            submitting
                ? AppL10n.of(context).deleteWorking
                : AppL10n.of(context).deleteSchedule,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppL10n.of(context).deleteConfirmIdentityNote,
          textAlign: TextAlign.center,
          style: const TextStyle(color: studafyMuted, fontSize: 12),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Future<void> _requestDeletion() async {
    setState(() => submitting = true);
    final result = await widget.account.requestDeletion(reasonCode: reason!);
    if (!mounted) return;
    setState(() => submitting = false);
    result.fold(
      onSuccess: (request) => setState(() => scheduled = request),
      onFailure: (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _cancelDeletion() async {
    final result = await widget.account.cancelDeletion();
    if (!mounted) return;
    result.fold(
      onSuccess: (cancelled) {
        if (cancelled) {
          setState(() => scheduled = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.of(context).deleteKeptSnack)),
          );
        }
      },
      onFailure: (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  /// Record kinds come from the server as stable codes; this is the label the
  /// reader sees. An unknown code falls back to the code itself rather than
  /// hiding a record category that exists.
  static String _friendly(AppL10n l10n, String key) => switch (key) {
    'profile' => l10n.recordProfile,
    'devices' => l10n.recordDevices,
    'consents' => l10n.recordConsents,
    'notifications' => l10n.recordNotifications,
    'attendance' => l10n.recordAttendance,
    'grades' => l10n.recordGrades,
    'submissions' => l10n.recordSubmissions,
    'wellbeing' => l10n.recordWellbeing,
    _ => key,
  };
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(
          studafyNumber(context, count),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _ScheduledState extends StatelessWidget {
  const _ScheduledState({
    required this.email,
    required this.request,
    required this.onCancel,
  });

  final String email;
  final DeletionRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.event_available_outlined, color: studafyNavy, size: 40),
      const SizedBox(height: 14),
      Text(
        AppL10n.of(context).deleteScheduledTitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 10),
      Text(
        AppL10n.of(context).deleteScheduledBody(
          email,
          studafyDate(context, request.executeAfter),
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: studafyMuted),
      ),
      const SizedBox(height: 24),
      if (request.isCancellable)
        FilledButton(
          onPressed: onCancel,
          child: Text(AppL10n.of(context).deleteKeepMyAccount),
        ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppL10n.of(context).deleteTryAgain),
          ),
        ],
      ),
    ),
  );
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: studafyMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  );
}
