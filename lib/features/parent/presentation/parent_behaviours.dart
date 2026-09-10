part of '../../../parent_features.dart';

class ParentBehavioursPage extends StatefulWidget {
  const ParentBehavioursPage({super.key});
  @override
  State<ParentBehavioursPage> createState() => _ParentBehavioursPageState();
}

class _ParentBehavioursPageState extends State<ParentBehavioursPage> {
  List<Map<String, Object?>> children = [];
  int selectedChild = 0;
  String filter = 'all';
  final Set<String> acknowledged = {};

  Map<String, Object?>? get child =>
      children.isEmpty ? null : children[selectedChild];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ParentRepositoryScope.read(context).linkedChildren();
    if (!mounted) return;
    setState(() {
      children = rows;
      selectedChild = selectedChild.clamp(
        0,
        rows.isEmpty ? 0 : rows.length - 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _AcademicsHeader(
          title: 'Behaviours',
          children: children,
          selected: selectedChild,
          onSelected: (value) => setState(() {
            selectedChild = value;
            filter = 'all';
          }),
        ),
        if (child == null)
          const Expanded(
            child: Center(
              child: Text('Add a child from Home to view behaviour updates.'),
            ),
          )
        else
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: ParentRepositoryScope.read(context)
                  .behavioursForStudent(child!['student_id'] as int),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final source = snapshot.data!.isEmpty
                    ? _sampleBehaviours(selectedChild)
                    : snapshot.data!;
                final positive = source
                    .where((row) => _kind(row) == 'positive')
                    .length;
                final negative = source
                    .where((row) => _kind(row) == 'negative')
                    .length;
                final notes = source
                    .where((row) => _kind(row) == 'note')
                    .length;
                final visible = filter == 'all'
                    ? source
                    : source.where((row) => _kind(row) == filter).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _BehaviourFilters(
                      selected: filter,
                      counts: {
                        'all': source.length,
                        'positive': positive,
                        'negative': negative,
                        'note': notes,
                      },
                      onSelected: (value) => setState(() => filter = value),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _BehaviourStat(
                          value: '$positive',
                          label: 'Positive',
                          color: const Color(0xFF15885D),
                        ),
                        const SizedBox(width: 9),
                        _BehaviourStat(
                          value: '$negative',
                          label: 'Needs attention',
                          color: const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 9),
                        _BehaviourStat(
                          value: '$notes',
                          label: 'Notes',
                          color: const Color(0xFF1687A0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filter == 'all') ...[
                      _BehaviourInsight(
                        firstName: '${child!['student_name']}'.split(' ').first,
                        positive: positive,
                        negative: negative,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (visible.isEmpty)
                      _AcademicEmpty(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        title:
                            'No ${filter == 'negative' ? 'concerns' : filter} updates',
                        message: 'Teacher observations in this category will appear here.',
                      )
                    else
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BehaviourCard(
                            item: visible[i],
                            index: i,
                            acknowledged: acknowledged.contains(
                              '${visible[i]['created_at']}-$i',
                            ),
                            onAcknowledge: () => setState(
                              () => acknowledged.add(
                                '${visible[i]['created_at']}-$i',
                              ),
                            ),
                            onMessage: () => _messageTeacher(visible[i]),
                          ),
                        ),
                    if (filter == 'all') ...[
                      const SizedBox(height: 2),
                      const _SupportCard(),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );

  void _messageTeacher(Map<String, Object?> item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Message the teacher',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Regarding “${item['tag']}”',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Ask for context or share how you will follow up at home…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Message added to your conversation draft.'),
                  ),
                );
              },
              child: const Text('Save message draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BehaviourFilters extends StatelessWidget {
  const _BehaviourFilters({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: counts.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final key = counts.keys.elementAt(index), active = key == selected;
        final label = key == 'all'
            ? 'All'
            : key == 'note'
            ? 'Notes'
            : '${key[0].toUpperCase()}${key.substring(1)}';
        return ChoiceChip(
          selected: active,
          onSelected: (_) => onSelected(key),
          label: Text('$label ${counts[key]}'),
          selectedColor: _navy,
          labelStyle: TextStyle(
            color: active ? Colors.white : _muted,
            fontWeight: FontWeight.w800,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(color: active ? _navy : const Color(0xFFE0E2ED)),
        );
      },
    ),
  );
}

class _BehaviourStat extends StatelessWidget {
  const _BehaviourStat({
    required this.value,
    required this.label,
    required this.color,
  });
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
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BehaviourInsight extends StatelessWidget {
  const _BehaviourInsight({
    required this.firstName,
    required this.positive,
    required this.negative,
  });
  final String firstName;
  final int positive, negative;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBFD), Color(0xFFF2EFFF)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD7EDF2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly insight',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                positive > negative
                    ? '$firstName is showing a strong positive pattern. Teachers most often noticed collaboration and participation.'
                    : 'This week has a mixed pattern. A calm check-in about routines may help uncover what changed.',
                style: const TextStyle(color: _ink, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 8),
              const Text(
                'Insight based on teacher observations—not a diagnosis or permanent label.',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BehaviourCard extends StatelessWidget {
  const _BehaviourCard({
    required this.item,
    required this.index,
    required this.acknowledged,
    required this.onAcknowledge,
    required this.onMessage,
  });
  final Map<String, Object?> item;
  final int index;
  final bool acknowledged;
  final VoidCallback onAcknowledge, onMessage;
  @override
  Widget build(BuildContext context) {
    final kind = _kind(item);
    final color = kind == 'positive'
        ? const Color(0xFF15885D)
        : kind == 'negative'
        ? const Color(0xFFC62828)
        : const Color(0xFF1687A0);
    final teacher = index.isEven
        ? 'Ms Layla Fahmy · Biology'
        : 'Mr Fadi Chami · Mathematics';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A241D73),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['tag']}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kind == 'negative'
                      ? 'Needs attention'
                      : '${kind[0].toUpperCase()}${kind.substring(1)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${item['note']}',
            style: const TextStyle(color: Color(0xFF5F6680), height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teacher,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              Text(
                index == 0 ? 'Yesterday, 11:20' : '${index + 3} March',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message teacher'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: acknowledged ? null : onAcknowledge,
                tooltip: acknowledged ? 'Acknowledged' : 'Mark as seen',
                icon: Icon(
                  acknowledged
                      ? Icons.check_circle_rounded
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.favorite_outline_rounded, color: Color(0xFF7737EE)),
            SizedBox(width: 9),
            Text(
              'Continue the conversation at home',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Try: “I saw your teacher noticed something today. What happened from your point of view?”',
          style: TextStyle(color: Color(0xFF5F6680), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        const Text(
          'Focus on patterns, context, and next steps—not labels. For urgent safety concerns, contact the school directly.',
          style: TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School support contacts',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'The school has not published a support contact yet. For urgent concerns, use the verified school office details supplied at enrollment.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('View school support contacts'),
        ),
      ],
    ),
  );
}

String _kind(Map<String, Object?> item) {
  final value = '${item['kind']}'.toLowerCase();
  if (value.contains('positive') || value.contains('praise')) {
    return 'positive';
  }
  if (value.contains('negative') || value.contains('concern')) {
    return 'negative';
  }
  return 'note';
}

List<Map<String, Object?>> _sampleBehaviours(int childIndex) => [
  {
    'kind': 'positive',
    'tag': childIndex.isEven ? 'Helped a peer' : 'Excellent focus',
    'note': childIndex.isEven
        ? 'Stayed behind to help a classmate finish the lab write-up without being asked.'
        : 'Worked independently throughout the reading task and asked thoughtful questions.',
    'created_at': '2026-09-01',
  },
  {
    'kind': 'negative',
    'tag': 'Homework not completed',
    'note': 'The latest problem set was not handed in. We agreed it would come in by Friday.',
    'created_at': '2026-08-31',
  },
  {
    'kind': 'positive',
    'tag': 'Great participation',
    'note': 'Led the group discussion and made space for quieter students to contribute.',
    'created_at': '2026-08-28',
  },
  {
    'kind': 'note',
    'tag': 'Check-in suggested',
    'note': 'Seemed quieter than usual after lunch. No immediate concern, but a gentle check-in may be helpful.',
    'created_at': '2026-08-27',
  },
];
