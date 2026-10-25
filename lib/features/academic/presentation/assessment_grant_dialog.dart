import 'package:flutter/material.dart';

import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// More time or more attempts for one student on an online assessment.
class GrantAccessDialog extends StatefulWidget {
  const GrantAccessDialog({
    super.key,
    required this.repository,
    required this.assessmentId,
    required this.students,
    this.closesAt,
  });

  final OnlineAssessmentRepository repository;
  final String assessmentId;
  final List<ClassStudent> students;
  final DateTime? closesAt;

  @override
  State<GrantAccessDialog> createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<GrantAccessDialog> {
  String? _student;
  DateTime? _until;
  int _extra = 0;
  bool _saving = false;
  String? _error;

  Future<void> _pick() async {
    final now = DateTime.now();
    final start = widget.closesAt != null && widget.closesAt!.isAfter(now)
        ? widget.closesAt!
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (!mounted) return;
    setState(
      () => _until = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    final student = _student;
    if (student == null || (_until == null && _extra == 0)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.grantAccess(
        widget.assessmentId,
        student,
        closesAt: _until,
        extraAttempts: _extra,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.markGrantFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final until = _until;
    return AlertDialog(
      title: Text(l10n.markGrantAccess),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _student,
            decoration: InputDecoration(labelText: l10n.markGrantStudent),
            items: [
              for (final s in widget.students)
                DropdownMenuItem(value: s.id, child: Text(s.displayName)),
            ],
            onChanged: _saving ? null : (id) => setState(() => _student = id),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.markGrantUntil),
            subtitle: Text(
              until == null
                  ? l10n.builderNotSet
                  : '${studafyShortDate(context, until)} '
                        '${studafyTimeOfDay(context, TimeOfDay.fromDateTime(until))}',
            ),
            onTap: _saving ? null : _pick,
          ),
          Row(
            children: [
              Expanded(child: Text(l10n.markGrantExtra)),
              IconButton(
                onPressed: _saving || _extra == 0
                    ? null
                    : () => setState(() => _extra--),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('$_extra'),
              IconButton(
                onPressed: _saving || _extra >= 20
                    ? null
                    : () => setState(() => _extra++),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(
          onPressed:
              _saving || _student == null || (_until == null && _extra == 0)
              ? null
              : _save,
          child: Text(l10n.markGrantGive),
        ),
      ],
    );
  }
}
