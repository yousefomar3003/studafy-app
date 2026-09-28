import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/result.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/class_list_interactor.dart';
import '../domain/classroom.dart';

/// Asks for a new class - name, grade, section, room and weekly timetable -
/// and creates it. True when it was created; a failure is shown as a message.
Future<bool> showCreateClassDialog(
  BuildContext context,
  ClassListInteractor classes,
) async {
  final name = TextEditingController();
  final room = TextEditingController();
  int grade = 10;
  String section = 'A';
  int weeklySessions = 1;
  String? createFailure;
  final sessions = <ClassSessionDraft>[
    ClassSessionDraft(weekday: 1, startTime: '08:00', endTime: '08:50'),
  ];
  final dayNames = studafyWeekdayNames(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: Text(AppL10n.of(dialogContext).classesCreateTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: AppL10n.of(dialogContext).classesNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: room,
                decoration: InputDecoration(
                  labelText: AppL10n.of(dialogContext).classesRoomLabel,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: grade,
                      decoration: InputDecoration(
                        labelText: AppL10n.of(dialogContext).classesGradeLabel,
                      ),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            AppL10n.of(dialogContext).classesGradeOption(i + 1),
                          ),
                        ),
                      ),
                      onChanged: (v) => setDialog(() => grade = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: section,
                      decoration: InputDecoration(
                        labelText: AppL10n.of(dialogContext)
                            .classesSectionLabel,
                      ),
                      items: ['A', 'B', 'C', 'D']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setDialog(() => section = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: weeklySessions,
                decoration: InputDecoration(
                  labelText: AppL10n.of(dialogContext).classesWeeklyLabel,
                  prefixIcon: const Icon(Icons.event_repeat_rounded),
                ),
                items: List.generate(
                  14,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(
                      AppL10n.of(dialogContext).classesWeeklyOption(i + 1),
                    ),
                  ),
                ),
                onChanged: (value) => setDialog(() {
                  weeklySessions = value ?? 1;
                  while (sessions.length < weeklySessions) {
                    sessions.add(
                      ClassSessionDraft(
                        weekday: sessions.last.weekday,
                        startTime: sessions.last.startTime,
                        endTime: sessions.last.endTime,
                      ),
                    );
                  }
                  while (sessions.length > weeklySessions) {
                    sessions.removeLast();
                  }
                }),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppL10n.of(dialogContext).classesChooseTimes,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < sessions.length; i++)
                Container(
                  margin: const EdgeInsetsDirectional.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: [
                      studafyCyan,
                      const Color(0xFF7737EE),
                      const Color(0xFFFF6B6B),
                      const Color(0xFF20B981),
                      const Color(0xFFFFB84D),
                    ][i % 5].withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppL10n.of(dialogContext).classesSessionNumber(i + 1),
                        style: const TextStyle(
                          color: studafyInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: sessions[i].weekday,
                        decoration: InputDecoration(
                          labelText: AppL10n.of(dialogContext).classesDayLabel,
                        ),
                        items: List.generate(
                          7,
                          (day) => DropdownMenuItem(
                            value: day + 1,
                            child: Text(dayNames[day]),
                          ),
                        ),
                        onChanged: (value) => setDialog(
                          () => sessions[i] = ClassSessionDraft(
                            weekday: value ?? 1,
                            startTime: sessions[i].startTime,
                            endTime: sessions[i].endTime,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _parseTimeOfday(
                                    sessions[i].startTime,
                                  ),
                                );
                                if (t != null) {
                                  setDialog(
                                    () => sessions[i] = ClassSessionDraft(
                                      weekday: sessions[i].weekday,
                                      startTime: _formatTimeOfDay(t),
                                      endTime: sessions[i].endTime,
                                    ),
                                  );
                                }
                              },
                              child: Text(sessions[i].startTime),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(AppL10n.of(dialogContext).classesTo),
                          ),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _parseTimeOfday(
                                    sessions[i].endTime,
                                  ),
                                );
                                if (t != null) {
                                  setDialog(
                                    () => sessions[i] = ClassSessionDraft(
                                      weekday: sessions[i].weekday,
                                      startTime: sessions[i].startTime,
                                      endTime: _formatTimeOfDay(t),
                                    ),
                                  );
                                }
                              },
                              child: Text(sessions[i].endTime),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppL10n.of(dialogContext).classesCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || sessions.isEmpty) return;
              final draft = NewClassDraft(
                name: name.text.trim(),
                grade: grade,
                section: section,
                room: room.text.trim().isEmpty ? 'TBD' : room.text.trim(),
                firstSessionStart: sessions.first.startTime,
                firstSessionEnd: sessions.first.endTime,
                weeklySessions: weeklySessions,
                sessions: List.unmodifiable(sessions),
              );
              final result = await classes.createClass(draft);
              if (!dialogContext.mounted) return;
              switch (result) {
                case Success():
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                case FailureResult(:final failure):
                  createFailure = failure.message;
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, false);
                  }
              }
            },
            child: Text(AppL10n.of(dialogContext).classesCreateAction),
          ),
        ],
      ),
    ),
  );
  if (saved != true && createFailure != null && context.mounted) {
    ScaffoldMessenger.of(context).showMessage(createFailure!);
  }
  return saved == true;
}

TimeOfDay _parseTimeOfday(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
  );
}

String _formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
