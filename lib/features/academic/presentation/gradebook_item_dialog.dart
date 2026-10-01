import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';

/// What a paper gradebook item is: its name, the kind of work, what it is
/// out of, and - when the school weighs kinds of work - how much it counts.
@immutable
class GradebookItemDetails {
  const GradebookItemDetails({
    required this.title,
    required this.category,
    required this.maximumScore,
    this.weight,
    this.scheduledAt,
  });

  final String title;

  /// One of the built-in kinds below, or the school's own words.
  final String category;
  final double maximumScore;
  final double? weight;
  final DateTime? scheduledAt;
}

/// Built-in kinds of paper work. Anything else is the school's own category,
/// stored as typed.
const _builtInCategories = ['paper_exam', 'homework', 'quiz', 'participation'];

String gradebookCategoryLabel(AppL10n l10n, String category) =>
    switch (category) {
      'paper_exam' => l10n.paperItemCategoryExam,
      'homework' => l10n.paperItemCategoryHomework,
      'quiz' => l10n.paperItemCategoryQuiz,
      'participation' => l10n.paperItemCategoryParticipation,
      _ => category,
    };

/// Asks for a new paper gradebook item's details, or edits [initial].
Future<GradebookItemDetails?> showGradebookItemDialog(
  BuildContext context, {
  GradebookItemDetails? initial,
}) => showDialog<GradebookItemDetails>(
  context: context,
  builder: (_) => _GradebookItemDialog(initial: initial),
);

class _GradebookItemDialog extends StatefulWidget {
  const _GradebookItemDialog({this.initial});

  final GradebookItemDetails? initial;

  @override
  State<_GradebookItemDialog> createState() => _GradebookItemDialogState();
}

class _GradebookItemDialogState extends State<_GradebookItemDialog> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _maximum = TextEditingController(
    text: _number(widget.initial?.maximumScore ?? 100),
  );
  late final _weight = TextEditingController(
    text: widget.initial?.weight == null
        ? ''
        : _number(widget.initial!.weight!),
  );
  late String _category = _builtInCategories.contains(widget.initial?.category)
      ? widget.initial!.category
      : (widget.initial == null ? 'paper_exam' : 'other');
  late final _custom = TextEditingController(
    text: _builtInCategories.contains(widget.initial?.category)
        ? ''
        : widget.initial?.category,
  );
  late DateTime? _date = widget.initial?.scheduledAt;
  bool _invalid = false;

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  void dispose() {
    _title.dispose();
    _maximum.dispose();
    _weight.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _submit() {
    final maximum = double.tryParse(_maximum.text.trim().replaceAll(',', '.'));
    final weightText = _weight.text.trim().replaceAll(',', '.');
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    final category = _category == 'other' ? _custom.text.trim() : _category;
    if (_title.text.trim().isEmpty ||
        maximum == null ||
        maximum <= 0 ||
        category.isEmpty ||
        (weightText.isNotEmpty &&
            (weight == null || weight < 0 || weight > 100))) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(
      GradebookItemDetails(
        title: _title.text.trim(),
        category: category,
        maximumScore: maximum,
        weight: weight,
        scheduledAt: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.paperItemTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.paperItemName,
                hintText: l10n.paperItemNameHint,
              ),
            ),
            Text(l10n.paperItemCategory),
            Wrap(
              spacing: 6,
              children: [
                for (final category in [..._builtInCategories, 'other'])
                  ChoiceChip(
                    label: Text(
                      category == 'other'
                          ? l10n.paperItemCategoryOther
                          : gradebookCategoryLabel(l10n, category),
                    ),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            if (_category == 'other')
              TextField(
                controller: _custom,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.paperItemCategoryCustom,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maximum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.paperItemMaximum,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.paperItemWeight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: now.subtract(const Duration(days: 365)),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _date == null
                    ? l10n.paperItemDate
                    : MaterialLocalizations.of(context)
                          .formatMediumDate(_date!),
              ),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.paperItemInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.paperGradesCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.paperItemSave)),
      ],
    );
  }
}
