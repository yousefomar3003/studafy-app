import 'dart:io';

import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import 'student_shared.dart';

class StudentNotebookPeriods extends StatelessWidget {
  const StudentNotebookPeriods({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x10241D73), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Text(
                  const ['Day', 'Week', 'Month'][i],
                  style: TextStyle(
                    color: selected == i ? studentNavy : studentMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class StudentNotebookSubject extends StatelessWidget {
  const StudentNotebookSubject({
    super.key,
    required this.subject,
    required this.notes,
    required this.expanded,
    required this.onToggle,
    required this.onAttachment,
    required this.onStudyAction,
  });
  final String subject;
  final List<Map<String, Object?>> notes;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Map<String, Object?>> onAttachment;
  final void Function(String, Map<String, Object?>) onStudyAction;
  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(subject);
    final attachmentTotal = notes.fold<int>(
      0,
      (sum, note) => sum + ((note['attachment_count'] as int?) ?? 0),
    );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13241D73),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 82,
                  color: color,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Colors.white),
                      SizedBox(height: 18),
                      CircleAvatar(radius: 4, backgroundColor: Colors.white),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            color: studentNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${notes.length} lesson${notes.length == 1 ? '' : 's'} · $attachmentTotal attachment${attachmentTotal == 1 ? '' : 's'} · last ${_relativeDay('${notes.first['day']}')}',
                          style: const TextStyle(
                            color: Color(0xFFA89B78),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFFA89B78),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          if (expanded)
            for (final note in notes)
              _NotebookLesson(
                note: note,
                color: color,
                onAttachment: onAttachment,
                onStudyAction: onStudyAction,
              ),
        ],
      ),
    );
  }
}

class _NotebookLesson extends StatelessWidget {
  const _NotebookLesson({
    required this.note,
    required this.color,
    required this.onAttachment,
    required this.onStudyAction,
  });
  final Map<String, Object?> note;
  final Color color;
  final ValueChanged<Map<String, Object?>> onAttachment;
  final void Function(String, Map<String, Object?>) onStudyAction;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: StudafyDatabase.instance.attachments('notebook', note['id'] as int),
    builder: (context, snapshot) {
      final attachments = snapshot.data ?? [];
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF1),
          border: Border(top: BorderSide(color: Color(0xFFEDE4CB))),
        ),
        padding: const EdgeInsets.fromLTRB(46, 16, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${note['day']} · PERIOD ${note['session_number']}',
                    style: const TextStyle(
                      color: Color(0xFFA89B78),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${attachments.length} files',
                  style: const TextStyle(
                    color: Color(0xFFA89B78),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${note['lesson']}',
              style: const TextStyle(
                color: studentNavy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ('${note['homework'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                'Homework: ${note['homework']}',
                style: const TextStyle(color: Color(0xFF625D50), height: 1.4),
              ),
            ],
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 13),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _AttachmentTile(
                    item: attachments[index],
                    onTap: () => onAttachment(attachments[index]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final action in [
                  'Summarise',
                  'Quiz me',
                  'Flashcards',
                  'Ask',
                ])
                  ActionChip(
                    avatar: Icon(
                      action == 'Ask'
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.auto_awesome_rounded,
                      size: 14,
                      color: studentNavy,
                    ),
                    label: Text(action, style: const TextStyle(fontSize: 10)),
                    onPressed: () => onStudyAction(action, note),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Filed by your teacher · ${_relativeDay('${note['day']}')}',
              style: const TextStyle(color: Color(0xFFA89B78), fontSize: 10),
            ),
          ],
        ),
      );
    },
  );
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.item, required this.onTap});
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final kind = '${item['kind']}',
        name = '${item['name']}',
        uri = '${item['uri']}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE4DDCB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kind == 'image' && File(uri).existsSync())
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(uri),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Icon(
                studentAttachmentIcon(kind, name),
                color: studentNavy,
                size: 27,
              ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF81775E), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentNotebookEmpty extends StatelessWidget {
  const StudentNotebookEmpty({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 25),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFF0EFFF),
          child: Icon(
            Icons.library_books_outlined,
            color: studentNavy,
            size: 31,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'No filed lessons here yet',
          style: TextStyle(
            color: studentInk,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Teacher lesson notes and their photos, documents, PDFs, links, and other files will appear automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: studentMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You will be notified when a teacher publishes new lesson material.',
              ),
            ),
          ),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Notify me when filed'),
        ),
      ],
    ),
  );
}

Color _subjectColor(String subject) {
  const colors = [
    Color(0xFF241D73),
    Color(0xFF20C6E8),
    Color(0xFFE47B00),
    Color(0xFF7737EE),
    Color(0xFFFF315F),
  ];
  return colors[subject.hashCode.abs() % colors.length];
}

String _relativeDay(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final now = DateTime.now();
  final difference = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (difference == 0) return 'today';
  if (difference == 1) return 'yesterday';
  return '${date.day}/${date.month}/${date.year}';
}
