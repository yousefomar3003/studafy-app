import 'package:flutter/material.dart';

const studafyNavy = Color(0xFF241D73);
const studafyCyan = Color(0xFF20C6E8);
const studafyInk = Color(0xFF171441);
const studafyMuted = Color(0xFF737B98);
const studafyCanvas = Color(0xFFF7F6FE);

/// Brand lockup shared by the session flow and every shell.
class StudafyLogo extends StatelessWidget {
  const StudafyLogo({super.key, this.size = 46});
  final double size;
  @override
  Widget build(BuildContext c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size * .56,
        height: size * .56,
        margin: EdgeInsets.only(right: size * .05),
        decoration: BoxDecoration(
          color: studafyCyan.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size * .18),
        ),
        child: Icon(Icons.add_rounded, color: studafyCyan, size: size * .45),
      ),
      Text(
        'studafy',
        style: TextStyle(
          fontSize: size,
          height: 1,
          letterSpacing: -2,
          fontWeight: FontWeight.w900,
          color: studafyNavy,
        ),
      ),
    ],
  );
}

/// Shared card primitive used across features.
class FeatureCard extends StatelessWidget {
  const FeatureCard({super.key, required this.child, this.onTap, this.tint});
  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;
  @override
  Widget build(BuildContext c) => Card(
    elevation: 1,
    shadowColor: const Color(0xFF7737EE).withValues(alpha: .12),
    color: tint == null
        ? Colors.white
        : Color.alphaBlend(tint!.withValues(alpha: .065), Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: (tint ?? studafyCyan).withValues(alpha: .11)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    ),
  );
}

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
