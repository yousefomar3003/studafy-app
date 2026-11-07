import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/school_links.dart';

/// The reason and optional words of a report, or null when cancelled.
typedef SchoolReport = ({SchoolReportReason reason, String details});

/// Asks why the teacher is reporting a school. The school is never told.
Future<SchoolReport?> askSchoolReport(BuildContext context) =>
    showDialog<SchoolReport>(
      context: context,
      builder: (_) => const _ReportSchoolDialog(),
    );

class _ReportSchoolDialog extends StatefulWidget {
  const _ReportSchoolDialog();

  @override
  State<_ReportSchoolDialog> createState() => _ReportSchoolDialogState();
}

class _ReportSchoolDialogState extends State<_ReportSchoolDialog> {
  SchoolReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(AppL10n l10n, SchoolReportReason reason) => switch (reason) {
    SchoolReportReason.notMySchool => l10n.schoolReportNotMySchool,
    SchoolReportReason.fakeSchool => l10n.schoolReportFake,
    SchoolReportReason.pressure => l10n.schoolReportPressure,
    SchoolReportReason.other => l10n.schoolReportOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.schoolReportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.schoolReportIntro),
            const SizedBox(height: 8),
            RadioGroup<SchoolReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in SchoolReportReason.values)
                    RadioListTile<SchoolReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      title: Text(_label(l10n, reason)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.schoolReportDetails),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.schoolLinkCancel),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () =>
                    Navigator.of(context)
                        .pop((reason: _reason!, details: _details.text)),
          child: Text(l10n.schoolReportSend),
        ),
      ],
    );
  }
}
