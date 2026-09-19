part of 'teacher_dashboard.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.time,
    required this.title,
    required this.room,
    this.status,
    this.completed = false,
  });
  final String time, title, room;
  final String? status;
  final bool completed;
  @override
  Widget build(BuildContext c) => InfoCard(
    accent: status != null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              time,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            if (status != null) ...[
              const SizedBox(width: 9),
              Chip(
                label: Text(status!),
                visualDensity: VisualDensity.compact,
                backgroundColor: navy,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
              ),
            ],
          ],
        ),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: ink,
          ),
        ),
        // The room is whatever the school called it.
        UserContentText(room, style: const TextStyle(color: muted)),
        const SizedBox(height: 16),
        if (!completed)
          FilledButton(
            onPressed: () => showAttendance(c, title),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(AppL10n.of(c).dashTakeAttendance),
          )
        else ...[
          Wrap(
            spacing: 8,
            children: [
              Pill(AppL10n.of(c).dashAttendanceRecorded, true),
              Pill(AppL10n.of(c).dashNotebookMissing, false),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showNotebook(c, title),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(AppL10n.of(c).dashAddNotebook),
          ),
        ],
      ],
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.accent = false});
  final Widget child;
  final bool accent;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border(
        left: BorderSide(color: accent ? navy : Colors.transparent, width: 4),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B171441),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext c) => Text(
    text,
    style: const TextStyle(
      color: ink,
      fontWeight: FontWeight.w800,
      fontSize: 20,
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, this.good, {super.key});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFD8FAE9) : const Color(0xFFFFE4E6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: good ? const Color(0xFF16875B) : const Color(0xFFD33A47),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SmallRow extends StatelessWidget {
  const SmallRow(
    this.title,
    this.subtitle,
    this.trailing,
    this.color, {
    super.key,
  });
  final String title, subtitle, trailing;
  final Color color;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(width: 3, height: 38, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F9FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF087D99),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class StudentRow extends StatelessWidget {
  const StudentRow(this.initials, this.name, this.detail, {super.key});
  final String initials, name, detail;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: navy,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(detail, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        const Pill('New', true),
      ],
    ),
  );
}

class EmptyPage extends StatelessWidget {
  const EmptyPage(
    this.icon,
    this.title,
    this.subtitle, {
    super.key,
    required this.actions,
  });

  final TeacherDashboardActions actions;
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      TeacherHeader(title: title, actions: actions),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: cyan),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(c).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
