import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';

class VytalHudDestination {
  const VytalHudDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating glass dock so the 5 product tabs cannot be mistaken for
/// Material Home / Activity / Sleep / Insights / Profile.
class VytalHudDock extends StatelessWidget {
  const VytalHudDock({
    super.key,
    required this.index,
    required this.onSelect,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<VytalHudDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: VytalColors.teal.withValues(alpha: isDark ? 0.28 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: extras.elevated.withValues(alpha: isDark ? 0.78 : 0.92),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: VytalColors.teal.withValues(alpha: isDark ? 0.5 : 0.35),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _DockItem(
                          destination: destinations[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final VytalHudDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final color = selected ? VytalColors.teal : extras.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? VytalColors.teal.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? VytalColors.teal.withValues(alpha: 0.85)
                      : extras.border.withValues(alpha: 0.6),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: VytalColors.teal.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.8,
                    fontSize: 9,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
