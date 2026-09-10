part of '../../../parent_features.dart';

class _AcademicTabs extends StatelessWidget {
  const _AcademicTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 4; i++)
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
                  const ['Classes', 'Grades', 'Attend.', 'Work'][i],
                  style: TextStyle(
                    color: selected == i ? _navy : _muted,
                    fontSize: 12,
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

class _ClassesTab extends StatelessWidget {
  const _ClassesTab({super.key, required this.studentId});
  final int studentId;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: ParentRepositoryScope.read(context)
            .classesForStudent(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final classes = snapshot.data!;
          if (classes.isEmpty) {
            return const _AcademicEmpty(
              icon: Icons.class_outlined,
              title: 'No connected classes',
              message: 'Classes appear here when a teacher adds this child to a classroom.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                'CURRENT CLASSES',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassCard(item: item),
                ),
              const SizedBox(height: 4),
              const Text(
                'Only classrooms created by teachers using Studafy are shown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          );
        },
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});
  final Map<String, Object?> item;
  @override
  Widget build(BuildContext context) {
    final color = Color(item['color'] as int);
    return _Card(
      child: Row(
        children: [
          Container(
            width: 5,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name']}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grade ${item['grade']} · Section ${item['section']}',
                  style: const TextStyle(color: _muted),
                ),
                Text(
                  '${item['room']} · ${item['start_time']}–${item['end_time']}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }
}

class _GradesTab extends StatelessWidget {
  const _GradesTab({super.key, required this.childIndex});
  final int childIndex;
  @override
  Widget build(BuildContext context) {
    final offset = childIndex * 2;
    final subjects = [
      ('Biology', 84 + offset, _navy),
      ('Mathematics', 81 + offset, _cyan),
      ('History', 84 - offset, Color(0xFF7737EE)),
      ('English', 80 + offset, Color(0xFFFF315F)),
      ('Chemistry', 85 - offset, Color(0xFFE47B00)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAD394)),
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Color(0xFFB98921)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate issued',
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Semester 1 and full year',
                      style: TextStyle(color: Color(0xFFA99973), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFB98921)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('Term 2 · 2025–26')),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Term average', style: TextStyle(color: _muted)),
              Text(
                '${83 + offset}%',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Pass mark 50% · Set by Al-Noor International',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final subject in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Row(
                children: [
                  Container(width: 3, height: 30, color: subject.$3),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subject.$1,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${subject.$2}%',
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({super.key, required this.childIndex});
  final int childIndex;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      Row(
        children: [
          _Stat(
            value: '${96 - childIndex}%',
            label: 'Present',
            color: const Color(0xFF159B68),
          ),
          const SizedBox(width: 8),
          _Stat(
            value: '${2 + childIndex}',
            label: 'Absences',
            color: const Color(0xFFFF4757),
          ),
          const SizedBox(width: 8),
          _Stat(
            value: '$childIndex',
            label: 'Late',
            color: const Color(0xFFB87500),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const _Card(child: _AttendanceCalendar()),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: _Card(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.chevron_left_rounded, color: _muted),
          Text(
            'March 2026',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
          ),
          Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Text(day, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 31,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final day = index + 1;
          final marker = day == 5 || day == 6
              ? const Color(0xFFFF4757)
              : day == 12
              ? const Color(0xFFF0A000)
              : day == 19
              ? const Color(0xFF1687C0)
              : null;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: day == 17 ? _navy : _muted,
                  fontWeight: day == 17 ? FontWeight.w900 : FontWeight.normal,
                ),
              ),
              if (marker != null)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: marker,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          );
        },
      ),
      const Divider(),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '● Absent',
            style: TextStyle(color: Color(0xFFFF4757), fontSize: 10),
          ),
          SizedBox(width: 12),
          Text(
            '● Late',
            style: TextStyle(color: Color(0xFFF0A000), fontSize: 10),
          ),
          SizedBox(width: 12),
          Text(
            '● Excused',
            style: TextStyle(color: Color(0xFF1687C0), fontSize: 10),
          ),
        ],
      ),
    ],
  );
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({super.key, required this.studentId});
  final int studentId;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: ParentRepositoryScope.read(context).workForStudent(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const _AcademicEmpty(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No assigned work',
              message: 'Assignments from connected classes will appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['class_name']}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${row['title']}',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due ${row['due_at']}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: row['submitted_at'] == null
                                    ? const Color(0xFFF0F1F7)
                                    : const Color(0xFFD7F8E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                row['submitted_at'] == null
                                    ? 'Not submitted'
                                    : 'Submitted',
                                style: TextStyle(
                                  color: row['submitted_at'] == null
                                      ? _muted
                                      : const Color(0xFF15885D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _AcademicEmpty extends StatelessWidget {
  const _AcademicEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _navy, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}
