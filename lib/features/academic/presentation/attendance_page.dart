import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

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

  /// The lesson, once its register has been saved at least once, and what
  /// the school's policy lets this teacher do to it.
  String? _sessionId;
  AttendanceEditRule _rule = AttendanceEditRule.open;
  bool _override = false;
  final _correctionReason = TextEditingController();
  final Map<String, AttendanceState> _marks = {};
  final Map<String, String> _reasons = {};

  /// The register as it was loaded, so unsaved changes can be shown.
  Map<String, AttendanceState> _savedMarks = const {};
  Map<String, String> _savedReasons = const {};

  bool get _dirty =>
      !_sameMap(_marks, _savedMarks) || !_sameMap(_reasons, _savedReasons);

  static bool _sameMap<V>(Map<String, V> a, Map<String, V> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
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

  @override
  void dispose() {
    _correctionReason.dispose();
    super.dispose();
  }

  /// Whether the marks can be touched at all right now.
  bool get _canEdit =>
      _rule != AttendanceEditRule.locked &&
      (_rule != AttendanceEditRule.lockedOverride || _override);

  /// A past lesson asks why a mark changed; an override always does.
  bool get _asksReason =>
      _rule == AttendanceEditRule.reasonRequired ||
      _rule == AttendanceEditRule.lockedOverride;

  /// Meetings that fall on the chosen day. Empty when the class does not
  /// meet that day at all, which is worth saying plainly rather than
  /// showing an empty register the teacher might fill in anyway.
  List<ClassSessionSlot> get _slotsForDay =>
      _schedule.where((slot) => slot.weekday == _date.weekday).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  /// Weekdays the class meets on.
  Set<int> get _meetingDays => {for (final slot in _schedule) slot.weekday};

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// The nearest day, stepping by [direction] from [from] (not including
  /// it), that the class meets. Null when the class has no schedule.
  DateTime? _stepMeeting(DateTime from, int direction) {
    if (_meetingDays.isEmpty) return null;
    var day = _day(from);
    for (var i = 0; i < 7; i++) {
      day = day.add(Duration(days: direction));
      if (_meetingDays.contains(day.weekday)) return day;
    }
    return null;
  }

  /// Opening on a day the class does not meet showed "no lesson" and a
  /// disabled Save, which read as the register not working. Opened without
  /// a date, it lands on today's lesson, or the most recent one.
  bool _placed = false;

  void _placeOnALesson() {
    if (_placed) return;
    _placed = true;
    if (widget.initialDate != null) return;
    if (_meetingDays.isEmpty || _meetingDays.contains(_date.weekday)) return;
    _date = _stepMeeting(_date, -1) ?? _date;
  }

  Future<void> _stepTo(int direction) async {
    final next = _stepMeeting(_date, direction);
    if (next == null) return;
    setState(() => _date = next);
    await _load();
  }

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
      _placeOnALesson();
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
        _sessionId = register.sessionId;
        _rule = register.editRule;
        _override = false;
        _correctionReason.clear();
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
        _savedMarks = Map.of(_marks);
        _savedReasons = Map.of(_reasons);
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
    final days = _meetingDays;
    // Only days the class meets can be chosen: any other day has no
    // register to take. The calendar must open on a choosable day.
    final initial = days.isEmpty || days.contains(_date.weekday)
        ? _date
        : (_stepMeeting(_date, -1) ?? _stepMeeting(_date, 1) ?? _date);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // A register is taken for a lesson that has happened or is happening;
      // a year either side covers catching up and the rare correction.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: days.isEmpty
          ? null
          : (day) => days.contains(day.weekday),
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
    final l10n = AppL10n.of(context);
    final saved = l10n.attendanceSavedCount(entries.length);
    final reason = _correctionReason.text.trim();
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    try {
      final sessionId = _sessionId;
      if (sessionId == null) {
        await widget.repository.recordAttendance(
          widget.classroomId,
          _at(slot.startsAt),
          _at(slot.endsAt),
          _version,
          entries,
          correctionReason: reason.isEmpty ? null : reason,
          override: _override,
        );
      } else {
        // A register that exists is corrected by its lesson, which keeps
        // working after the timetable changes or a student leaves.
        await widget.repository.correctAttendance(
          sessionId,
          _version,
          entries,
          reason: reason.isEmpty ? null : reason,
          override: _override,
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = saved;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(saved)));
      // The save moved the session on; reload so an immediate correction
      // carries the new version instead of a stale one.
      await _load();
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = courseworkMessage(l10n, refusal);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _loadFailedMessage;
      });
    }
  }

  Future<void> _showHistory() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _AttendanceHistorySheet(
        load: widget.repository.attendanceHistory(sessionId),
      ),
    );
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

  /// Every student on the register marked present, to adjust from.
  void _markAllPresent() {
    setState(() {
      for (final entry in _roster) {
        if (!entry.enrolled) continue;
        _marks[entry.studentId] = AttendanceState.present;
        _reasons.remove(entry.studentId);
      }
      _error = null;
    });
  }

  Future<void> _pickState(AttendanceRosterEntry entry) async {
    final chosen = await showModalBottomSheet<AttendanceState>(
      context: context,
      builder: (sheetContext) => _StatePickerSheet(
        name: entry.displayName,
        current: _marks[entry.studentId],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _marks[entry.studentId] = chosen;
      // A reason only means something for an absence that was explained;
      // clear it when the mark no longer carries one.
      if (chosen == AttendanceState.present) _reasons.remove(entry.studentId);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final slots = _slotsForDay;
    final counts = {
      for (final state in AttendanceState.values)
        state: _marks.values.where((mark) => mark == state).length,
    };
    final unmarked = _roster.where((e) => _marks[e.studentId] == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.attendanceTitle(widget.classroomName)),
        actions: [
          if (_sessionId != null)
            IconButton(
              tooltip: l10n.attendanceHistory,
              onPressed: _showHistory,
              icon: const Icon(Icons.history_rounded),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DayAndSlotPicker(
              date: _date,
              slots: slots,
              selected: _slot,
              onPickDate: _pickDate,
              onPrevious: _meetingDays.isEmpty || _loading
                  ? null
                  : () => _stepTo(-1),
              onNext: _meetingDays.isEmpty || _loading
                  ? null
                  : () => _stepTo(1),
              onPickSlot: (slot) {
                setState(() => _slot = slot);
                // Each meeting has its own register; re-read rather than
                // showing the previous session's marks against this one.
                _load();
              },
            ),
            if (!_loading && _slot != null)
              _PolicyBanner(
                rule: _rule,
                overriding: _override,
                reason: _correctionReason,
                asksReason: _asksReason && !_saving,
                onOverride: (value) => setState(() => _override = value),
              ),
            if (!_loading && _slot != null && _roster.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.attendanceCounts(
                        counts[AttendanceState.present]!,
                        counts[AttendanceState.absent]! +
                            counts[AttendanceState.excused]!,
                        counts[AttendanceState.late]!,
                        unmarked,
                      ),
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _canEdit && !_saving ? _markAllPresent : null,
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(l10n.attendanceMarkAllPresent),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: studafyDanger),
                ),
              ),
            if (_saved != null && !_dirty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: studafyNavy,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_saved!)),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : slots.isEmpty
                  ? Center(
                      child: StudafyEmptyState(
                        icon: Icons.event_busy_rounded,
                        title: l10n.attendanceNoSessionThatDay,
                      ),
                    )
                  : _roster.isEmpty
                  ? Center(
                      child: StudafyEmptyState(
                        icon: Icons.groups_outlined,
                        title: l10n.attendanceNoStudents,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        16,
                        24,
                      ),
                      itemCount: _roster.length,
                      itemBuilder: (context, i) {
                        final entry = _roster[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RosterRow(
                            entry: entry,
                            state: _marks[entry.studentId],
                            reason: _reasons[entry.studentId],
                            enabled: _canEdit && !_saving,
                            onPick: () => _pickState(entry),
                            onReason: (reason) => setState(() {
                              if (reason.isEmpty) {
                                _reasons.remove(entry.studentId);
                              } else {
                                _reasons[entry.studentId] = reason;
                              }
                            }),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: studafyCanvas,
            border: Border(top: BorderSide(color: studafyHairline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dirty && !_saving)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: studafyMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.attendanceUnsaved,
                        style: const TextStyle(color: studafyMuted),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _slot == null || _saving || _loading || !_canEdit
                      ? null
                      : _save,
                  child: Text(
                    _saving ? l10n.attendanceSaving : l10n.attendanceSave,
                  ),
                ),
              ),
            ],
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
    this.onPrevious,
    this.onNext,
  });

  final DateTime date;
  final List<ClassSessionSlot> slots;
  final ClassSessionSlot? selected;
  final VoidCallback onPickDate;
  final ValueChanged<ClassSessionSlot> onPickSlot;

  /// Step to the class's previous or next lesson day.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeatureCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: AppL10n.of(context).attendancePreviousLesson,
                onPressed: onPrevious,
                icon: Icon(backChevron(context)),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        // The weekday, not only the date: a teacher thinks
                        // "Monday's lesson", and it shows at a glance why a
                        // day has none.
                        Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(date),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: studafyInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (slots.length == 1)
                          Text(
                            '${slots.first.startsAt}–${slots.first.endsAt}',
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: AppL10n.of(context).attendanceNextLesson,
                onPressed: onNext,
                icon: Icon(forwardChevron(context)),
              ),
            ],
          ),
        ),
        if (slots.length > 1) ...[
          const SizedBox(height: 10),
          // Shown only when there is a choice to make: one meeting a day is
          // the common case and needs no picker.
          Text(
            AppL10n.of(context).attendanceWhichSession,
            style: const TextStyle(
              color: studafyInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
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
        ],
      ],
    ),
  );
}

/// What each mark is called and looks like. Colour always comes with an
/// icon and a word.
({String label, IconData icon, Color color}) _look(
  BuildContext context,
  AttendanceState? state,
) {
  final l10n = AppL10n.of(context);
  return switch (state) {
    AttendanceState.present => (
      label: l10n.attendancePresent,
      icon: Icons.check_circle_rounded,
      color: studafyNavy,
    ),
    AttendanceState.absent => (
      label: l10n.attendanceAbsent,
      icon: Icons.cancel_rounded,
      color: studafyDanger,
    ),
    AttendanceState.late => (
      label: l10n.attendanceTardy,
      icon: Icons.schedule_rounded,
      color: studafyCyan,
    ),
    AttendanceState.excused => (
      label: l10n.attendanceExcused,
      icon: Icons.verified_rounded,
      color: studafyMuted,
    ),
    null => (
      label: l10n.attendanceNotMarked,
      icon: Icons.radio_button_unchecked_rounded,
      color: studafyMuted,
    ),
  };
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.entry,
    required this.state,
    required this.reason,
    required this.onPick,
    required this.onReason,
    this.enabled = true,
  });

  final AttendanceRosterEntry entry;
  final bool enabled;
  final AttendanceState? state;
  final String? reason;
  final VoidCallback onPick;
  final ValueChanged<String> onReason;

  static Map<AttendanceState, String> _labels(BuildContext context) => {
    for (final state in AttendanceState.values)
      state: _look(context, state).label,
  };

  /// A reason explains a departure from simply being here, so it is offered
  /// for everything except "present".
  bool get _wantsReason => state != null && state != AttendanceState.present;

  @override
  Widget build(BuildContext context) {
    final look = _look(context, state);
    return FeatureCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: entry.displayName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!entry.enrolled)
                      Text(
                        AppL10n.of(context).paperGradesLeftClass,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The mark is a button: tapping it offers the choices.
              Semantics(
                button: true,
                label: AppL10n.of(context)
                    .attendanceStatusFor(entry.displayName, look.label),
                excludeSemantics: true,
                child: Material(
                  color: look.color.withValues(alpha: .1),
                  shape: StadiumBorder(
                    side: BorderSide(color: look.color.withValues(alpha: .3)),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: enabled ? onPick : null,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        8,
                        8,
                        8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(look.icon, size: 18, color: look.color),
                          const SizedBox(width: 6),
                          Text(
                            look.label,
                            style: TextStyle(
                              color: look.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: look.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_wantsReason) ...[
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('reason-${entry.studentId}'),
              initialValue: reason ?? '',
              enabled: enabled,
              decoration: InputDecoration(
                labelText: AppL10n.of(context).attendanceReasonLabel,
                isDense: true,
              ),
              maxLength: 500,
              onChanged: onReason,
            ),
          ],
        ],
      ),
    );
  }
}

/// The attendance choices for one student, as a short list.
class _StatePickerSheet extends StatelessWidget {
  const _StatePickerSheet({required this.name, required this.current});

  final String name;
  final AttendanceState? current;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
            child: Text(
              name,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final state in AttendanceState.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(
                builder: (context) {
                  final look = _look(context, state);
                  final chosen = state == current;
                  return Material(
                    color: chosen
                        ? look.color.withValues(alpha: .1)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: chosen ? look.color : studafyHairline,
                        width: chosen ? 1.6 : 1,
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(look.icon, color: look.color),
                      title: Text(
                        look.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: chosen
                          ? Icon(Icons.check_rounded, color: look.color)
                          : null,
                      selected: chosen,
                      onTap: () => Navigator.pop(context, state),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

/// What the school's attendance policy says about this register, and the
/// reason and override it asks for.
class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({
    required this.rule,
    required this.overriding,
    required this.reason,
    required this.asksReason,
    required this.onOverride,
  });

  final AttendanceEditRule rule;
  final bool overriding;
  final TextEditingController reason;
  final bool asksReason;
  final ValueChanged<bool> onOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final message = switch (rule) {
      AttendanceEditRule.open => null,
      AttendanceEditRule.reasonRequired => l10n.attendanceRuleReasonRequired,
      AttendanceEditRule.locked => l10n.attendanceRuleLocked,
      AttendanceEditRule.lockedOverride => l10n.attendanceRuleLockedOverride,
    };
    if (message == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  rule == AttendanceEditRule.reasonRequired
                      ? Icons.info_outline
                      : Icons.lock_outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            if (rule == AttendanceEditRule.lockedOverride)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.attendanceOverride),
                value: overriding,
                onChanged: onOverride,
              ),
            if (asksReason &&
                (rule == AttendanceEditRule.reasonRequired || overriding))
              TextField(
                controller: reason,
                maxLength: 500,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.attendanceCorrectionReason,
                  border: const OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every change to a mark on this register: who, when, from what, to what.
class _AttendanceHistorySheet extends StatelessWidget {
  const _AttendanceHistorySheet({required this.load});

  final Future<List<AttendanceChange>> load;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final labels = _RosterRow._labels(context);
    return SafeArea(
      child: FutureBuilder<List<AttendanceChange>>(
        future: load,
        builder: (context, snapshot) {
          final items = snapshot.data;
          if (items == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.attendanceHistory,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l10n.attendanceHistoryEmpty),
                ),
              for (final change in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.attendanceHistoryLine(
                      change.studentName,
                      labels[change.previous]!,
                      labels[change.next]!,
                    ),
                  ),
                  subtitle: Text(
                    [
                      MaterialLocalizations.of(context)
                          .formatShortDate(change.at),
                      ?change.actorName,
                      ?change.reason,
                      if (change.override) l10n.attendanceHistoryOverride,
                    ].join(' · '),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
