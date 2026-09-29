import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/study/domain/study.dart';
import '../features/study_assistant/domain/study_assistant_repository.dart';
import '../l10n/generated/app_l10n.dart';

/// Chooses class material for the study helper: a class, then its lessons
/// and the student's own notes for it. Composed here because it draws on the
/// classes, academic and study features, which may not import each other.
///
/// Only which ones are chosen leaves the device; the server reads the text
/// itself, and only what this student may read.
Future<List<ChatReference>?> pickStudyReferences(
  BuildContext context, {
  required ClassListInteractor classes,
  required AcademicRepository academic,
  required StudyRepository study,
  required List<ChatReference> current,
}) => Navigator.of(context).push<List<ChatReference>>(
  MaterialPageRoute<List<ChatReference>>(
    builder: (_) => _ReferencePicker(
      classes: classes,
      academic: academic,
      study: study,
      current: current,
    ),
  ),
);

/// The most the helper is sent with one question.
const maxStudyReferences = 5;

class _ReferencePicker extends StatefulWidget {
  const _ReferencePicker({
    required this.classes,
    required this.academic,
    required this.study,
    required this.current,
  });

  final ClassListInteractor classes;
  final AcademicRepository academic;
  final StudyRepository study;
  final List<ChatReference> current;

  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  late final Set<ChatReference> _chosen = {...widget.current};
  late final Future<List<ClassroomSummary>> _classes = _loadClasses();
  ClassroomSummary? _class;
  Future<List<ChatReference>>? _material;

  Future<List<ClassroomSummary>> _loadClasses() async =>
      (await widget.classes.loadClasses()).fold(
        onSuccess: (list) => list,
        onFailure: (failure) => throw failure,
      );

  Future<List<ChatReference>> _loadMaterial(String classroomId) async {
    final lessons = await widget.academic.load(
      AcademicFeed.content,
      classroomId: classroomId,
    );
    List<NotebookEntry> notes;
    try {
      notes = await widget.study.notebook(classroomId);
    } on Object {
      notes = const [];
    }
    return [
      for (final lesson in lessons)
        ChatReference(
          kind: ChatReferenceKind.lesson,
          id: lesson.id,
          title: lesson.title,
        ),
      for (final note in notes)
        ChatReference(
          kind: ChatReferenceKind.note,
          id: note.id,
          title: note.title,
        ),
    ];
  }

  void _toggle(ChatReference reference, bool? on) => setState(() {
    if (on == true) {
      if (_chosen.length < maxStudyReferences) _chosen.add(reference);
    } else {
      _chosen.remove(reference);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final classroom = _class;
    return Scaffold(
      appBar: AppBar(
        title: Text(classroom?.name ?? l10n.helperPickTitle),
        leading: classroom == null
            ? null
            : BackButton(onPressed: () => setState(() => _class = null)),
      ),
      body: classroom == null ? _classList(l10n) : _materialList(l10n),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _chosen.toList()),
            child: Text('${l10n.helperPickDone} (${_chosen.length})'),
          ),
        ),
      ),
    );
  }

  Widget _classList(AppL10n l10n) => FutureBuilder<List<ClassroomSummary>>(
    future: _classes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final classes = snapshot.data ?? const <ClassroomSummary>[];
      if (classes.isEmpty) {
        return Center(child: Text(l10n.helperNoClasses));
      }
      return ListView(
        children: [
          ListTile(title: Text(l10n.helperPickClass)),
          for (final item in classes)
            ListTile(
              leading: const Icon(Icons.class_outlined),
              title: Text(item.name),
              trailing: Icon(forwardChevron(context)),
              onTap: () => setState(() {
                _class = item;
                _material = _loadMaterial(item.id.value);
              }),
            ),
        ],
      );
    },
  );

  Widget _materialList(AppL10n l10n) => FutureBuilder<List<ChatReference>>(
    future: _material,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = snapshot.data ?? const <ChatReference>[];
      if (items.isEmpty) {
        return Center(child: Text(l10n.helperNothingInClass));
      }
      final lessons = [
        for (final item in items)
          if (item.kind == ChatReferenceKind.lesson) item,
      ];
      final notes = [
        for (final item in items)
          if (item.kind == ChatReferenceKind.note) item,
      ];
      Widget tile(ChatReference item) => CheckboxListTile(
        value: _chosen.contains(item),
        onChanged: _chosen.contains(item) || _chosen.length < maxStudyReferences
            ? (on) => _toggle(item, on)
            : null,
        title: Text(item.title),
      );
      return ListView(
        children: [
          ListTile(subtitle: Text(l10n.helperPickLimit)),
          if (lessons.isNotEmpty) ListTile(title: Text(l10n.helperLessons)),
          for (final item in lessons) tile(item),
          if (notes.isNotEmpty) ListTile(title: Text(l10n.helperMyNotes)),
          for (final item in notes) tile(item),
        ],
      );
    },
  );
}
