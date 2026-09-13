import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'student_progress_page.dart';
import 'student_shared.dart';

class StudentTodayClasses extends StatelessWidget {
  const StudentTodayClasses({super.key, required this.classes});
  final List<Map<String, Object?>> classes;

  int _minutes(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _state(Map<String, Object?> item, int index) {
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final start = _minutes('${item['session_start_time']}');
    final end = _minutes('${item['session_end_time']}');
    if (current >= start && current < end) return 'NOW';
    if (current < start) {
      final firstFuture = classes.indexWhere(
        (row) => _minutes('${row['session_start_time']}') > current,
      );
      return firstFuture == index ? 'NEXT' : 'LATER';
    }
    return 'COMPLETED';
  }

  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Today's Classes",
                style: TextStyle(
                  color: studentNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${classes.length} classes',
              style: const TextStyle(color: studentMuted, fontSize: 11),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, color: studentMuted),
          ],
        ),
        const SizedBox(height: 12),
        if (classes.isEmpty)
          const Text(
            'No teacher-created classes are scheduled.',
            style: TextStyle(color: studentMuted),
          )
        else
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = classes[index],
                    color = Color(item['color'] as int);
                return Container(
                  width: 178,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: .22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _state(item, index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${item['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: studentNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item['session_start_time']}–${item['session_end_time']} · ${item['room']}',
                        style: const TextStyle(
                          color: studentMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class StudentDueSoon extends StatelessWidget {
  const StudentDueSoon({super.key, required this.work});
  final List<Map<String, Object?>> work;
  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due Soon',
          style: TextStyle(
            color: studentNavy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (work.isEmpty)
          const Text(
            'You are all caught up.',
            style: TextStyle(color: studentMuted),
          )
        else
          for (final item in work.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 39,
                    decoration: BoxDecoration(
                      color: Color(
                        (item['class_name'].hashCode & 0x00FFFFFF) | 0xFF000000,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: studentNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item['class_name']} · Due ${studentShortDate('${item['due_at']}')}',
                          style: const TextStyle(
                            color: studentMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: item['submitted_at'] == null
                        ? 'Not started'
                        : 'Submitted',
                    positive: item['submitted_at'] != null,
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class StudentNewGrades extends StatelessWidget {
  const StudentNewGrades({super.key, required this.grades});
  final List<Map<String, Object?>> grades;
  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'New Grades',
                style: TextStyle(
                  color: studentNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const StudentProgressPage(),
                ),
              ),
              child: const Text('View grades'),
            ),
          ],
        ),
        if (grades.isEmpty)
          const Text(
            'No newly published grades.',
            style: TextStyle(color: studentMuted),
          )
        else
          for (final item in grades.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['class_name']}',
                          style: const TextStyle(
                            color: studentNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: studentMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _StatusPill(label: 'New', positive: true),
                  const SizedBox(width: 9),
                  Text(
                    '${studentScore(item['score'])}/${item['max_score']}',
                    style: const TextStyle(
                      color: studentNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class StudentAnnouncementSpotlight extends StatelessWidget {
  const StudentAnnouncementSpotlight({super.key, required this.notices});
  final List<Map<String, Object?>> notices;

  void _open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .65,
      maxChildSize: .9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'School announcements',
                    style: TextStyle(
                      color: studentInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final item = notices[index];
                final important = item['mandatory'] == 1;
                return Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: important ? const Color(0xFFFFF6F2) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: important
                          ? const Color(0xFFFFCBBE)
                          : const Color(0xFFE8EAF3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['class_name']}',
                              style: const TextStyle(
                                color: studentInk,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (important)
                            const _StatusPill(
                              label: 'Important',
                              warning: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item['message']}',
                        style: const TextStyle(color: studentInk, height: 1.4),
                      ),
                      if (item['meeting_url'] != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Google Meet · ${item['meeting_at']}',
                          style: const TextStyle(
                            color: studentMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse('${item['meeting_url']}');
                            if (uri != null) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.video_call_rounded),
                          label: const Text('Open in Google Meet'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        studentShortDate('${item['created_at']}'),
                        style: const TextStyle(
                          color: studentMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final highlighted = notices.firstWhere(
      (item) => item['mandatory'] == 1,
      orElse: () => notices.first,
    );
    final important = highlighted['mandatory'] == 1;
    return Material(
      color: important ? const Color(0xFFFFF3EE) : const Color(0xFFEAFBFD),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Badge(
                label: Text('${notices.length}'),
                backgroundColor: important
                    ? const Color(0xFFFF5D5D)
                    : studentCyan,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    important
                        ? Icons.campaign_rounded
                        : Icons.notifications_active_rounded,
                    color: important ? const Color(0xFFE04B3F) : studentNavy,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'School announcements',
                            style: TextStyle(
                              color: studentInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (important)
                          const _StatusPill(label: 'Important', warning: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${highlighted['message']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: studentInk, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to view all ${notices.length}',
                      style: const TextStyle(
                        color: studentNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right_rounded, color: studentNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentDayPlan extends StatelessWidget {
  const StudentDayPlan({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBFD), Color(0xFFF0EDFF)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan your study time',
                style: TextStyle(
                  color: studentNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'You have 2 unfinished tasks. A focused 35-minute session can clear the nearest deadline.',
                style: TextStyle(
                  color: Color(0xFF646B84),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: studentMuted),
      ],
    ),
  );
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B241D73),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.positive = false,
    this.warning = false,
  });
  final String label;
  final bool positive, warning;
  @override
  Widget build(BuildContext context) {
    final background = warning
        ? const Color(0xFFFFE1E1)
        : positive
        ? const Color(0xFFD6F8E8)
        : const Color(0xFFF0F1F7);
    final foreground = warning
        ? const Color(0xFFC62828)
        : positive
        ? const Color(0xFF15885D)
        : studentMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
