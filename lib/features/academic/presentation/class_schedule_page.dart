import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Editing when a class meets.
///
/// This is not cosmetic: the register is taken against a scheduled meeting,
/// and recordAttendance refuses a session whose start does not match a slot
/// here. A class created with the wrong timetable therefore cannot have its
/// attendance taken at all until this is corrected, which is why it has to be
/// editable after creation rather than only during it.
class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
    required this.expectedVersion,
    this.initialSlots = const [],
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  /// The classroom's current version; replacing a schedule is refused if it
  /// has moved on, rather than overwriting a colleague's edit.
  final int expectedVersion;
  final List<ClassSessionSlot> initialSlots;

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  late final List<ClassSessionSlot> _slots = List.of(widget.initialSlots);
  bool _saving = false;
  String? _error;
  String? _notice;

  String _weekdayName(AppL10n l10n, int weekday) => switch (weekday) {
    DateTime.monday => l10n.weekdayMon,
    DateTime.tuesday => l10n.weekdayTue,
    DateTime.wednesday => l10n.weekdayWed,
    DateTime.thursday => l10n.weekdayThu,
    DateTime.friday => l10n.weekdayFri,
    DateTime.saturday => l10n.weekdaySat,
    _ => l10n.weekdaySun,
  };

  static String _hhmm(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Future<void> _addSlot() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
    );
    if (end == null || !mounted) return;
    if (_hhmm(end).compareTo(_hhmm(start)) <= 0) {
      setState(() => _error = AppL10n.of(context).scheduleEndBeforeStart);
      return;
    }
    setState(() {
      _error = null;
      _slots.add(
        ClassSessionSlot(
          weekday: DateTime.monday,
          startsAt: _hhmm(start),
          endsAt: _hhmm(end),
        ),
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    final saved = l10n.scheduleSaved;
    final failed = l10n.scheduleSaveFailed;
    try {
      await widget.repository.replaceSchedule(
        widget.classroomId,
        widget.expectedVersion,
        _slots,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _notice = saved;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleTitle(widget.classroomName))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.scheduleHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_slots.isEmpty)
              Text(l10n.scheduleEmpty)
            else
              for (var i = 0; i < _slots.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _slots[i].weekday,
                            decoration: InputDecoration(
                              labelText: l10n.scheduleWeekday,
                              isDense: true,
                            ),
                            items: [
                              for (var day = 1; day <= 7; day++)
                                DropdownMenuItem(
                                  value: day,
                                  child: Text(_weekdayName(l10n, day)),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                    _slots[i] = ClassSessionSlot(
                                      weekday: value ?? _slots[i].weekday,
                                      startsAt: _slots[i].startsAt,
                                      endsAt: _slots[i].endsAt,
                                    );
                                  }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${_slots[i].startsAt}–${_slots[i].endsAt}'),
                        IconButton(
                          tooltip: l10n.scheduleRemove,
                          onPressed: _saving
                              ? null
                              : () => setState(() => _slots.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addSlot,
              icon: const Icon(Icons.add),
              label: Text(l10n.scheduleAddSlot),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? l10n.scheduleSaving : l10n.scheduleSave),
            ),
          ],
        ),
      ),
    );
  }
}
