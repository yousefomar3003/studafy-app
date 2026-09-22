import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Taking the register for one meeting of one class.
///
/// Attendance belongs to a session, not to a date: a class commonly meets
/// more than once a week, so the teacher chooses the day and then which of
/// that day's meetings they are marking. Picking only a date would silently
/// merge two different lessons into one register.
class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
    this.initialDate,
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  /// Which day the register opens on. Defaults to today; injectable so a
  /// test can land on a weekday the class actually meets.
  final DateTime? initialDate;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  List<ClassSessionSlot> _schedule = const [];
  ClassSessionSlot? _slot;
  List<AttendanceRosterEntry> _roster = const [];

  /// Version of the session being edited; echoed back on save so a
  /// second teacher's register is refused rather than overwritten.
  int _version = 0;
  final Map<String, AttendanceState> _marks = {};
  final Map<String, String> _reasons = {};
  late final String _loadFailedMessage;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations are an inherited widget, so the copy this screen holds
    // for its async paths is resolved here rather than in initState.
    _loadFailedMessage = AppL10n.of(context).attendanceLoadFailed;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Meetings that fall on the chosen day. Empty when the class does not
  /// meet that day at all, which is worth saying plainly rather than
  /// showing an empty register the teacher might fill in anyway.
  List<ClassSessionSlot> get _slotsForDay =>
      _schedule.where((slot) => slot.weekday == _date.weekday).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _saved = null;
    });
    try {
      if (_schedule.isEmpty) {
        _schedule = await widget.repository.classroomSchedule(
          widget.classroomId,
        );
      }
      final slots = _slotsForDay;
      _slot = slots.contains(_slot)
          ? _slot
          : (slots.isEmpty ? null : slots.first);
      final slot = _slot;
      final register = await widget.repository.attendanceRoster(
        widget.classroomId,
        _date,
        startsAt: slot == null ? null : _at(slot.startsAt),
      );
      final roster = register.entries;
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _version = register.version;
        _marks
          ..clear()
          ..addEntries(
            roster
                .where((entry) => entry.state != null)
                .map((entry) => MapEntry(entry.studentId, entry.state!)),
          );
        _reasons
          ..clear()
          ..addEntries(
            roster
                .where((entry) => (entry.reason ?? '').isNotEmpty)
                .map((entry) => MapEntry(entry.studentId, entry.reason!)),
          );
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _loadFailedMessage;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A register is taken for a lesson that has happened or is happening;
      // a year either side covers catching up and the rare correction.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _save() async {
    final slot = _slot;
    if (slot == null || _saving) return;
    // Only students actually marked are sent. An unmarked student is not the
    // same as an absent one, and guessing on the teacher's behalf would put
    // an unearned absence on a child's record.
    final entries = [
      for (final entry in _roster)
        if (_marks[entry.studentId] != null)
          AttendanceDraft(
            studentId: entry.studentId,
            state: _marks[entry.studentId]!.name,
            reason: _reasons[entry.studentId],
          ),
    ];
    if (entries.isEmpty) {
      setState(() => _error = AppL10n.of(context).attendanceMarkOne);
      return;
    }
    final saved = AppL10n.of(context).attendanceSavedCount(entries.length);
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    try {
      await widget.repository.recordAttendance(
        widget.classroomId,
        _at(slot.startsAt),
        _at(slot.endsAt),
        _version,
        entries,
      );
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = saved;
      });
      // The save moved the session on; reload so an immediate correction
      // carries the new version instead of a stale one.
      await _load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _loadFailedMessage;
      });
    }
  }

  /// Combines the chosen day with a slot's wall-clock time.
  DateTime _at(String time) {
    final parts = time.split(':');
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slotsForDay;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppL10n.of(context).attendanceTitle(widget.classroomName)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DayAndSlotPicker(
              date: _date,
              slots: slots,
              selected: _slot,
              onPickDate: _pickDate,
              onPickSlot: (slot) {
                setState(() => _slot = slot);
                // Each meeting has its own register; re-read rather than
                // showing the previous session's marks against this one.
                _load();
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_saved != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_saved!),
              ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : slots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppL10n.of(context).attendanceNoSessionThatDay,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _roster.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(AppL10n.of(context).attendanceNoStudents),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _roster.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final entry = _roster[i];
                        return _RosterRow(
                          entry: entry,
                          state: _marks[entry.studentId],
                          reason: _reasons[entry.studentId],
                          onState: (state) => setState(() {
                            _marks[entry.studentId] = state;
                            // A reason only means something for an absence
                            // that was explained; clear it when the mark no
                            // longer carries one.
                            if (state == AttendanceState.present) {
                              _reasons.remove(entry.studentId);
                            }
                          }),
                          onReason: (reason) => setState(() {
                            if (reason.isEmpty) {
                              _reasons.remove(entry.studentId);
                            } else {
                              _reasons[entry.studentId] = reason;
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _slot == null || _saving || _loading ? null : _save,
            child: Text(
              _saving
                  ? AppL10n.of(context).attendanceSaving
                  : AppL10n.of(context).attendanceSave,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayAndSlotPicker extends StatelessWidget {
  const _DayAndSlotPicker({
    required this.date,
    required this.slots,
    required this.selected,
    required this.onPickDate,
    required this.onPickSlot,
  });

  final DateTime date;
  final List<ClassSessionSlot> slots;
  final ClassSessionSlot? selected;
  final VoidCallback onPickDate;
  final ValueChanged<ClassSessionSlot> onPickSlot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
          ),
        ),
        if (slots.length > 1) ...[
          const SizedBox(height: 8),
          // Shown only when there is a choice to make: one meeting a day is
          // the common case and needs no picker.
          Text(
            AppL10n.of(context).attendanceWhichSession,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final slot in slots)
                ChoiceChip(
                  label: Text('${slot.startsAt}–${slot.endsAt}'),
                  selected: slot == selected,
                  onSelected: (_) => onPickSlot(slot),
                ),
            ],
          ),
        ] else if (slots.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${slots.first.startsAt}–${slots.first.endsAt}'),
          ),
      ],
    ),
  );
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.entry,
    required this.state,
    required this.reason,
    required this.onState,
    required this.onReason,
  });

  final AttendanceRosterEntry entry;
  final AttendanceState? state;
  final String? reason;
  final ValueChanged<AttendanceState> onState;
  final ValueChanged<String> onReason;

  static Map<AttendanceState, String> _labels(BuildContext context) {
    final l10n = AppL10n.of(context);
    return {
      AttendanceState.present: l10n.attendancePresent,
      AttendanceState.absent: l10n.attendanceAbsent,
      AttendanceState.late: l10n.attendanceTardy,
      AttendanceState.excused: l10n.attendanceExcused,
    };
  }

  /// A reason explains a departure from simply being here, so it is offered
  /// for everything except "present".
  bool get _wantsReason => state != null && state != AttendanceState.present;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.displayName, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final option in AttendanceState.values)
              ChoiceChip(
                label: Text(_labels(context)[option]!),
                selected: state == option,
                onSelected: (_) => onState(option),
              ),
          ],
        ),
        if (_wantsReason) ...[
          const SizedBox(height: 6),
          TextFormField(
            initialValue: reason ?? '',
            decoration: InputDecoration(
              labelText: AppL10n.of(context).attendanceReasonLabel,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            maxLength: 500,
            onChanged: onReason,
          ),
        ],
      ],
    ),
  );
}
