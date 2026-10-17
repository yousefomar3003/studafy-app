import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/unsaved_changes.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';

/// Writing a wellbeing note about one student.
///
/// The server decides who may write one - a teacher of that class - and who
/// may read it. What the teacher chooses here is only how widely it is
/// shared: staff only by default, or also with the student's parents, or
/// with the student as well. A concern also carries how serious it is.
///
/// Pops with a confirmation line once the note is saved.
class CreateWellbeingPage extends StatefulWidget {
  const CreateWellbeingPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
  });

  final AcademicRepository repository;
  final List<ClassOption> classes;
  final String? initialClassroomId;

  @override
  State<CreateWellbeingPage> createState() => _CreateWellbeingPageState();
}

enum _Kind { strength, note, concern }

enum _Visibility { staff, guardians, studentAndGuardians }

enum _Severity { low, moderate, high }

class _CreateWellbeingPageState extends State<CreateWellbeingPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _context = TextEditingController();
  final _followUp = TextEditingController();

  String? _classroomId;
  String? _studentId;
  List<ClassStudent> _students = const [];
  bool _loadingStudents = false;
  bool _studentsFailed = false;
  _Kind _kind = _Kind.note;
  _Visibility _visibility = _Visibility.staff;
  _Severity _severity = _Severity.low;
  bool _saving = false;
  String? _error;

  /// Typed and not yet saved: leaving asks first.
  bool get _unsaved =>
      !_saving &&
      [_title, _context, _followUp].any((c) => c.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClassroomId;
    _classroomId = widget.classes.any((c) => c.id == initial)
        ? initial
        : (widget.classes.length == 1 ? widget.classes.single.id : null);
    if (_classroomId != null) _loadStudents();
  }

  @override
  void dispose() {
    _title.dispose();
    _context.dispose();
    _followUp.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final classroomId = _classroomId;
    if (classroomId == null) return;
    setState(() {
      _loadingStudents = true;
      _studentsFailed = false;
      _students = const [];
      _studentId = null;
    });
    try {
      final students = await widget.repository.classStudents(classroomId);
      if (!mounted || classroomId != _classroomId) return;
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _studentsFailed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final l10n = AppL10n.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    try {
      await widget.repository.createWellbeing(
        WellbeingDraft(
          classroomId: _classroomId!,
          studentId: _studentId!,
          kind: _kind.name,
          title: _title.text.trim(),
          context: text(_context),
          followUp: text(_followUp),
          visibility: switch (_visibility) {
            _Visibility.staff => 'class_staff',
            _Visibility.guardians => 'guardian_shared',
            _Visibility.studentAndGuardians => 'student_guardian_shared',
          },
          // Seriousness is a property of a concern; a strength or a note
          // is recorded as low.
          severity: _kind == _Kind.concern ? _severity.name : 'low',
        ),
      );
      if (!mounted) return;
      navigator.pop(l10n.wellbeingSaved);
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
        _error = l10n.wellbeingSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Follows typing without rebuilding the page.
    listenable: Listenable.merge([_title, _context, _followUp]),
    builder: (_, page) => UnsavedChangesScope(unsaved: _unsaved, child: page!),
    child: _page(context),
  );

  Widget _page(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wellbeingNewTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
          children: [
            Text(
              l10n.wellbeingIntro,
              style: const TextStyle(color: studafyMuted, height: 1.4),
            ),
            SectionHeader(l10n.wellbeingWhoAbout),
            DropdownButtonFormField<String>(
              initialValue: _classroomId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.wellbeingClass,
                prefixIcon: const Icon(Icons.class_outlined),
              ),
              items: [
                for (final option in widget.classes)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              validator: (value) =>
                  value == null ? l10n.wellbeingPickClass : null,
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _classroomId = value);
                      _loadStudents();
                    },
            ),
            const SizedBox(height: 12),
            if (_loadingStudents)
              const LinearProgressIndicator()
            else if (_studentsFailed)
              TextButton.icon(
                onPressed: _loadStudents,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.wellbeingStudentsFailed),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey(_classroomId),
                initialValue: _studentId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.wellbeingStudent,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  helperText: _classroomId != null && _students.isEmpty
                      ? l10n.wellbeingNoStudents
                      : null,
                ),
                items: [
                  for (final student in _students)
                    DropdownMenuItem(
                      value: student.id,
                      child: Text(
                        student.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (value) =>
                    value == null ? l10n.wellbeingPickStudent : null,
                onChanged: _saving || _students.isEmpty
                    ? null
                    : (value) => setState(() => _studentId = value),
              ),
            SectionHeader(l10n.wellbeingKind),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in _Kind.values)
                  ChoiceChip(
                    avatar: Icon(switch (kind) {
                      _Kind.strength => Icons.emoji_events_outlined,
                      _Kind.note => Icons.sticky_note_2_outlined,
                      _Kind.concern => Icons.report_problem_outlined,
                    }, size: 18),
                    label: Text(switch (kind) {
                      _Kind.strength => l10n.wellbeingKindStrength,
                      _Kind.note => l10n.wellbeingKindNote,
                      _Kind.concern => l10n.wellbeingKindConcern,
                    }),
                    selected: _kind == kind,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            if (_kind == _Kind.concern) ...[
              const SizedBox(height: 14),
              Text(
                l10n.wellbeingSeverity,
                style: const TextStyle(
                  color: studafyInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<_Severity>(
                segments: [
                  ButtonSegment(
                    value: _Severity.low,
                    label: Text(l10n.wellbeingSeverityLow),
                  ),
                  ButtonSegment(
                    value: _Severity.moderate,
                    label: Text(l10n.wellbeingSeverityModerate),
                  ),
                  ButtonSegment(
                    value: _Severity.high,
                    label: Text(l10n.wellbeingSeverityHigh),
                  ),
                ],
                selected: {_severity},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _severity = value.single),
              ),
            ],
            SectionHeader(l10n.wellbeingDetails),
            TextFormField(
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.wellbeingTitle),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.wellbeingTitleRequired
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _context,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.wellbeingContext,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _followUp,
              enabled: !_saving,
              minLines: 2,
              maxLines: 6,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.wellbeingFollowUp,
                alignLabelWithHint: true,
              ),
            ),
            SectionHeader(l10n.wellbeingWhoSees),
            RadioGroup<_Visibility>(
              groupValue: _visibility,
              onChanged: (value) {
                if (_saving || value == null) return;
                setState(() => _visibility = value);
              },
              child: FeatureCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final option in _Visibility.values)
                      RadioListTile<_Visibility>(
                        value: option,
                        title: Text(switch (option) {
                          _Visibility.staff => l10n.wellbeingSeeStaff,
                          _Visibility.guardians => l10n.wellbeingSeeGuardians,
                          _Visibility.studentAndGuardians =>
                            l10n.wellbeingSeeStudent,
                        }),
                        subtitle: Text(switch (option) {
                          _Visibility.staff => l10n.wellbeingSeeStaffDetail,
                          _Visibility.guardians =>
                            l10n.wellbeingSeeGuardiansDetail,
                          _Visibility.studentAndGuardians =>
                            l10n.wellbeingSeeStudentDetail,
                        }),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: studafyDanger)),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? l10n.wellbeingSaving : l10n.wellbeingSave),
            ),
          ],
        ),
      ),
    );
  }
}
