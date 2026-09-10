import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../data/backend.dart';
import '../../../data/supabase_repository.dart';
import '../../../studafy_database.dart';

/// Account deletion flow shared by every role (ARC-011: moved verbatim out
/// of teacher_features.dart to break the cross-feature import).
///
/// LEGACY-TYPED, exempt from the feature boundary rules until the account
/// slice migrates it behind an AccountRepository: it still selects the
/// preview/remote implementation by environment at the call site.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.email});
  final String email;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final confirmation = TextEditingController();
  String? reason;
  bool exported = false,
      transferred = false,
      understood = false,
      schoolRecords = false;
  bool get ready =>
      exported &&
      transferred &&
      understood &&
      schoolRecords &&
      reason != null &&
      confirmation.text.trim() == 'DELETE';

  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Delete account'),
    ),
    body: ListView(
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
                      'Access to your profile, classes, messages, and personal files will end. Official school records may be retained by your school.',
                      style: TextStyle(color: Color(0xFF7A271A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('BEFORE YOU CONTINUE'),
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
                value: transferred,
                title: const Text('My school access is accounted for'),
                subtitle: const Text(
                  'Any classes, linked children, or learning access may need action from the school',
                ),
                onChanged: (v) => setState(() => transferred = v ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('TELL US WHY'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: reason,
          decoration: const InputDecoration(labelText: 'Reason for leaving'),
          items: [
            'I no longer use Studafy',
            'I am changing schools',
            'Privacy concerns',
            'I have another account',
            'Prefer not to say',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => reason = v),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: understood,
                title: const Text('I understand this cannot be undone'),
                subtitle: const Text('After the 14-day cancellation window'),
                onChanged: (v) => setState(() => understood = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: schoolRecords,
                title: const Text('I understand some records may remain'),
                subtitle: const Text(
                  'Attendance, grades, safeguarding, and audit records may be retained under school policy',
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
          onPressed: ready ? _finalReview : null,
          child: const Text('Review deletion request'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Nothing is deleted on this screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: studafyMuted, fontSize: 12),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );

  Future<void> _finalReview() async {
    final requested = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.hourglass_bottom_rounded,
          color: Color(0xFFB42318),
          size: 34,
        ),
        title: const Text('Schedule account deletion?'),
        content: const Text(
          'Your account will be deactivated and queued for deletion after a 14-day recoverable grace period. Contact Studafy support during that period to cancel. Afterward, eligible personal data is removed; required school records may remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Schedule deletion'),
          ),
        ],
      ),
    );
    if (requested == true && mounted) {
      try {
        if (StudafyBackend.isRemote) {
          await SupabaseStudafyRepository().requestAccountDeletion(
            confirmation: 'DELETE',
          );
        } else {
          await StudafyDatabase.instance.requestAccountDeletion();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
          );
        }
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.event_available_outlined,
            color: studafyNavy,
            size: 36,
          ),
          title: const Text('Deletion request scheduled'),
          content: Text(
            '${widget.email} is now in a 14-day recoverable grace period. You can cancel through Studafy support before eligible personal data is removed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
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
