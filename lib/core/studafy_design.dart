import 'package:flutter/material.dart';

const studafyNavy = Color(0xFF241D73);
const studafyCyan = Color(0xFF20C6E8);
const studafyInk = Color(0xFF171441);
const studafyMuted = Color(0xFF737B98);
const studafyCanvas = Color(0xFFF7F6FE);

class StudafyNavItem {
  const StudafyNavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Persistent navigation shared by every mobile role.
class StudafyNavigationBar extends StatelessWidget {
  const StudafyNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.accent = studafyNavy,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<StudafyNavItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) => NavigationBarTheme(
    data: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? accent : studafyMuted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : studafyMuted,
        ),
      ),
    ),
    child: NavigationBar(
      height: 72,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withValues(alpha: .12),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    ),
  );
}

class StudafyStatusCard extends StatelessWidget {
  const StudafyStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $message',
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: studafyNavy, size: 34),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: studafyMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}
