part of '../../../teacher_features.dart';

const _navy = Color(0xFF241D73),
    _ink = Color(0xFF171441),
    _muted = Color(0xFF8D94AF);
const _cyan = Color(0xFF20C6E8),
    _violet = Color(0xFF7737EE),
    _coral = Color(0xFFFF6B6B),
    _mint = Color(0xFF20B981),
    _sun = Color(0xFFFFB84D);
String _dayName(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

class _AttachmentDraft {
  const _AttachmentDraft(this.kind, this.name, this.uri);
  final String kind, name, uri;
  Map<String, String> toMap() => {'kind': kind, 'name': name, 'uri': uri};
}

class _AttachmentComposer extends StatelessWidget {
  const _AttachmentComposer({required this.items, required this.onChanged});
  final List<_AttachmentDraft> items;
  final VoidCallback onChanged;

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    for (final file in files) {
      if (file.path == null) continue;
      final ext = file.name.split('.').last.toLowerCase();
      final kind = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)
          ? 'image'
          : 'file';
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        file.path!,
        file.name,
      );
      items.add(_AttachmentDraft(kind, file.name, stored));
    }
    onChanged();
  }

  Future<void> _pickPhotos() async {
    final photos = await ImagePicker().pickMultiImage();
    for (final photo in photos) {
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        photo.path,
        photo.name,
      );
      items.add(_AttachmentDraft('image', photo.name, stored));
    }
    onChanged();
  }

  Future<void> _addLink(BuildContext context) async {
    final label = TextEditingController(), url = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Link title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add link'),
          ),
        ],
      ),
    );
    if (saved != true || url.text.trim().isEmpty) return;
    items.add(
      _AttachmentDraft(
        'link',
        label.text.trim().isEmpty ? url.text.trim() : label.text.trim(),
        url.text.trim(),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_cyan.withValues(alpha: .10), _violet.withValues(alpha: .08)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _cyan.withValues(alpha: .22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.attach_file_rounded, color: _violet, size: 19),
            SizedBox(width: 7),
            Text(
              'Attachments',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _AttachButton(
              icon: Icons.insert_drive_file_rounded,
              label: 'Files',
              color: _violet,
              onTap: _pickFiles,
            ),
            _AttachButton(
              icon: Icons.add_photo_alternate_rounded,
              label: 'Photos',
              color: _coral,
              onTap: _pickPhotos,
            ),
            _AttachButton(
              icon: Icons.link_rounded,
              label: 'Link',
              color: _mint,
              onTap: () => _addLink(context),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                InputChip(
                  avatar: Icon(
                    item.kind == 'image'
                        ? Icons.image_rounded
                        : item.kind == 'link'
                        ? Icons.link_rounded
                        : Icons.description_rounded,
                    size: 16,
                    color: _navy,
                  ),
                  label: Text(item.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () {
                    items.remove(item);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 17, color: color),
    label: Text(label),
    backgroundColor: Colors.white,
    side: BorderSide(color: color.withValues(alpha: .22)),
    onPressed: onTap,
  );
}

Widget _attachmentCount(Object? count, {VoidCallback? onTap}) {
  final value = (count as int?) ?? 0;
  if (value == 0) return const SizedBox.shrink();
  return ActionChip(
    visualDensity: VisualDensity.compact,
    avatar: const Icon(Icons.attach_file_rounded, size: 15, color: _violet),
    label: Text('$value'),
    onPressed: onTap,
  );
}

Future<void> _showAttachments(
  BuildContext context,
  String ownerType,
  int ownerId,
) async {
  final rows = await StudafyDatabase.instance.attachments(ownerType, ownerId);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: row['kind'] == 'image'
                      ? _coral.withValues(alpha: .14)
                      : row['kind'] == 'link'
                      ? _mint.withValues(alpha: .14)
                      : _violet.withValues(alpha: .14),
                  child: Icon(
                    row['kind'] == 'image'
                        ? Icons.image_rounded
                        : row['kind'] == 'link'
                        ? Icons.link_rounded
                        : Icons.description_rounded,
                    color: row['kind'] == 'image'
                        ? _coral
                        : row['kind'] == 'link'
                        ? _mint
                        : _violet,
                  ),
                ),
                title: Text('${row['name']}'),
                subtitle: Text('${row['kind']}'),
                trailing: const Icon(Icons.ios_share_rounded),
                onTap: () async {
                  if (row['kind'] == 'link') {
                    await SharePlus.instance.share(
                      ShareParams(text: '${row['uri']}'),
                    );
                  } else {
                    await SharePlus.instance.share(
                      ShareParams(files: [XFile('${row['uri']}')]),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class FeatureHeader extends StatelessWidget {
  const FeatureHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext c) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, _cyan.withValues(alpha: .055)],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Badge(
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ChatsPage()),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          Badge(
            backgroundColor: Colors.red,
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
              icon: const Icon(Icons.notifications_none),
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const MyStudafyPage()),
            ),
            borderRadius: BorderRadius.circular(24),
            child: const CircleAvatar(
              backgroundColor: _navy,
              child: Text(
                'RH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFECEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: index == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index == i ? _navy : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext c) {
    final color = text == 'Published' || text == 'Marked'
        ? const Color(0xFF16875B)
        : text == 'Rejected'
        ? Colors.red
        : const Color(0xFFB37805);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
