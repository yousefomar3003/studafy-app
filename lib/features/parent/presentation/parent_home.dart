part of '../../../parent_features.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});
  @override
  State<ParentHomePage> createState() => ParentHomePageState();
}

class ParentHomePageState extends State<ParentHomePage> {
  final controller = PageController();
  List<Map<String, Object?>> children = [];
  int selected = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    _load();
  }

  void _contextChanged() {
    if (!mounted || children.isEmpty) return;
    final next = _activeChildIndex(children, selected);
    if (next != selected) {
      setState(() => selected = next);
      if (controller.hasClients) {
        controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _load({int? selectStudent}) async {
    final rows = await ParentRepositoryScope.read(context).linkedChildren();
    if (!mounted) return;
    var next = _activeChildIndex(rows, selected);
    if (selectStudent != null) {
      final found = rows.indexWhere(
        (row) => row['student_id'] == selectStudent,
      );
      if (found >= 0) next = found;
    }
    setState(() {
      children = rows;
      selected = next;
      loading = false;
    });
    if (rows.isNotEmpty) _rememberChild(rows[next]);
    if (rows.isNotEmpty && controller.hasClients) controller.jumpToPage(next);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _ParentHeader(),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (children.isEmpty)
          Expanded(child: _EmptyChildren(onAdd: _addChild))
        else ...[
          _ChildSwitcher(
            children: children,
            selected: selected,
            onSelected: (value) {
              setState(() => selected = value);
              _rememberChild(children[value]);
              controller.animateToPage(
                value,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
            onAdd: _addChild,
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: children.length,
              onPageChanged: (value) {
                setState(() => selected = value);
                _rememberChild(children[value]);
              },
              itemBuilder: (context, index) =>
                  _ChildDashboard(child: children[index], index: index),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _addChild() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a child',
                style: TextStyle(
                  fontSize: 23,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Choose how you would like to add them to your family.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              _AddChildChoice(
                icon: Icons.badge_outlined,
                title: 'Connect an existing child',
                subtitle: 'Use the Studafy ID provided by their school',
                onTap: () => Navigator.pop(context, 'existing'),
              ),
              const SizedBox(height: 12),
              _AddChildChoice(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Create a new child',
                subtitle: 'For a child who is not on Studafy yet',
                onTap: () => Navigator.pop(context, 'new'),
              ),
              const SizedBox(height: 10),
              const Text(
                'A school can connect the new profile to classes later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'existing') await _findChild();
    if (choice == 'new') await _createChild();
  }

  Future<void> _findChild() async {
    final repository = ParentRepositoryScope.read(context);
    final id = TextEditingController();
    final shouldSearch = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
              'Add a child',
              style: TextStyle(
                fontSize: 23,
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Enter the Studafy ID shown on your child’s school profile.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: id,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Studafy ID',
                hintText: 'STU-0001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, id.text.trim().isNotEmpty),
              child: const Text('Find child'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final scanned = await scanStudentQr(context);
                if (scanned != null) id.text = scanned;
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan student QR'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The ID must match exactly. You can create a profile if your child does not have one yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    if (shouldSearch != true || !mounted) return;
    final found = await repository.studentByStudafyId(id.text);
    if (!mounted) return;
    if (found != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const CircleAvatar(
            backgroundColor: Color(0xFFE6F9FD),
            child: Icon(Icons.person_rounded, color: _navy),
          ),
          title: Text('${found['name']}'),
          content: Text(
            'Studafy ID ${found['studafy_id']}\n\nAdd this student to your family?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add child'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await repository.linkChild(found['id'] as int);
        await _load(selectStudent: found['id'] as int);
      }
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_search_rounded, color: _navy, size: 38),
        title: const Text('No child found'),
        content: Text(
          'We could not find “${id.text.toUpperCase()}”. Check the ID with your school, or create a new child profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create profile'),
          ),
        ],
      ),
    );
    if (create == true && mounted) await _createChild();
  }

  Future<void> _createChild() async {
    final repository = ParentRepositoryScope.read(context);
    final name = TextEditingController(), email = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create child profile',
                style: TextStyle(
                  fontSize: 23,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'A unique Studafy ID will be created. Your school can connect academic records later.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Child’s full name',
                ),
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Enter the child’s name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Child’s email (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Create and add child'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      final studentId = await repository.createAndLinkChild(
        name: name.text,
        email: email.text,
      );
      await _load(selectStudent: studentId);
    }
  }
}

class _AddChildChoice extends StatelessWidget {
  const _AddChildChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFDDE0ED)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE6F9FD),
              child: Icon(icon, color: _navy),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    ),
  );
}
