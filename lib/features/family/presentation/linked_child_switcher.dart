import 'package:flutter/material.dart';

import '../../../core/studafy_domain.dart';
import '../domain/family.dart';
import 'family_scope.dart';

/// Which of a guardian's children the other tabs are showing, and a way to
/// change it without going back to Home.
///
/// A child enrolled at two schools has a record at each; when two entries
/// share a name, each is labelled with its school so the guardian can tell
/// which one they are looking at.
class LinkedChildSwitcher extends StatefulWidget {
  const LinkedChildSwitcher({super.key, required this.onSelect});

  /// Makes [child] the one every tab follows.
  final ValueChanged<GuardianChild> onSelect;

  @override
  State<LinkedChildSwitcher> createState() => _LinkedChildSwitcherState();
}

class _LinkedChildSwitcherState extends State<LinkedChildSwitcher> {
  List<GuardianChild> _children = const [];

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!mounted) return;
    final result = await FamilyScope.of(context).children();
    if (!mounted) return;
    final verified = result.fold(
      onSuccess: (list) => [
        for (final child in list)
          if (child.isVerified) child,
      ],
      onFailure: (_) => const <GuardianChild>[],
    );
    setState(() => _children = verified);
    // Nothing selected yet - or a child no longer linked: follow the first.
    final selected = ActiveContextController.instance.selectedStudent?.id;
    if (verified.isNotEmpty &&
        !verified.any((child) => child.studentId == selected)) {
      widget.onSelect(verified.first);
    }
  }

  String _label(GuardianChild child) {
    final sameName = _children.where(
      (other) => other.studentName == child.studentName,
    );
    return sameName.length > 1
        ? '${child.studentName} · ${child.schoolName}'
        : child.studentName;
  }

  @override
  Widget build(BuildContext context) {
    if (_children.isEmpty) return const SizedBox.shrink();
    final selectedId = ActiveContextController.instance.selectedStudent?.id;
    final current = _children
        .where((child) => child.studentId == selectedId)
        .firstOrNull;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.child_care_rounded, size: 18),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              current == null ? '—' : _label(current),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (_children.length > 1) ...[
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ],
      ),
    );
    // One child: say who this is about, nothing to choose.
    if (_children.length == 1) {
      return Center(child: pill);
    }
    return Center(
      child: PopupMenuButton<GuardianChild>(
        tooltip: Localizations.localeOf(context).languageCode == 'ar'
            ? 'اختر الطفل'
            : 'Choose child',
        onSelected: widget.onSelect,
        itemBuilder: (_) => [
          for (final child in _children)
            CheckedPopupMenuItem(
              value: child,
              checked: child.studentId == selectedId,
              child: Text(_label(child)),
            ),
        ],
        child: pill,
      ),
    );
  }
}
