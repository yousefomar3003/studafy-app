import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
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

  static const _reasons = <String, String>{
    'no_longer_using': 'I no longer use Studafy',
    'changing_schools': 'I am changing schools',
    'privacy_concern': 'Privacy concerns',
    'duplicate_account': 'I have another account',
    'undisclosed': 'Prefer not to say',
  };

  bool get ready =>
      exported &&
      understood &&
      schoolRecords &&
      reason != null &&
      confirmation.text.trim() == 'DELETE' &&
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
      title: const Text('Delete account'),
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
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB42318)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This affects more than your profile',
                      style: TextStyle(
                        color: Color(0xFF7A271A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Access to your profile, classes, messages, and personal '
                      'files will end.',
                      style: TextStyle(color: Color(0xFF7A271A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('WHAT WILL BE DELETED'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              for (final entry in summary.deletedPersonalRecords.entries)
                _CountRow(label: _friendly(entry.key), count: entry.value),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('WHAT YOUR SCHOOL KEEPS'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Schools are required to keep these education records. They '
                  'stay with the school, not with your account, and deleting '
                  'your account does not remove them. Ask your school if you '
                  'need them corrected or erased.',
                  style: TextStyle(color: studafyMuted),
                ),
              ),
              for (final entry in summary.retainedSchoolRecords.entries)
                _CountRow(label: _friendly(entry.key), count: entry.value),
              if (summary.retainedTotal == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Your school holds no records for this account.'),
                ),
            ],
          ),
        ),
        if (summary.schools.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SettingsLabel('SCHOOL ACCESS THAT ENDS'),
          const SizedBox(height: 8),
          FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final school in summary.schools)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(school),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        const _SettingsLabel('TELL US WHY'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: reason,
          decoration: const InputDecoration(labelText: 'Reason for leaving'),
          items: [
            for (final entry in _reasons.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => setState(() => reason = value),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: exported,
                title: const Text('I saved what I need'),
                subtitle: const Text(
                  'Download a copy of personal data and files',
                ),
                onChanged: (v) => setState(() => exported = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: understood,
                title: Text(
                  'I understand this cannot be undone after '
                  '${summary.gracePeriodDays} days',
                ),
                subtitle: Text(
                  'You can cancel in this app during the '
                  '${summary.gracePeriodDays}-day period',
                ),
                onChanged: (v) => setState(() => understood = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: schoolRecords,
                title: const Text('I understand my school keeps some records'),
                subtitle: Text(
                  '${summary.retainedTotal} education records stay with your '
                  'school',
                ),
                onChanged: (v) => setState(() => schoolRecords = v ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Type DELETE to confirm deletion of ${widget.email}.',
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
          decoration: const InputDecoration(hintText: 'DELETE'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
          ),
          onPressed: ready ? _requestDeletion : null,
          child: Text(submitting ? 'Working…' : 'Schedule account deletion'),
        ),
        const SizedBox(height: 10),
        Text(
          'You will be asked to confirm it is you before this is scheduled.',
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
            const SnackBar(content: Text('Your account will be kept.')),
          );
        }
      },
      onFailure: (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  static String _friendly(String key) => switch (key) {
    'profile' => 'Your profile',
    'devices' => 'Signed-in devices',
    'consents' => 'Consent records',
    'notifications' => 'Notifications',
    'attendance' => 'Attendance records',
    'grades' => 'Grades',
    'submissions' => 'Submitted work',
    'wellbeing' => 'Wellbeing notes',
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
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
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
        'Deletion scheduled',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 10),
      Text(
        '$email will be deleted after '
        '${_formatDate(request.executeAfter)}. Until then you can stop it '
        'here — you do not need to contact support.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: studafyMuted),
      ),
      const SizedBox(height: 24),
      if (request.isCancellable)
        FilledButton(onPressed: onCancel, child: const Text('Keep my account')),
    ],
  );

  static String _formatDate(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
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
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
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
