import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';

/// Compact uppercase section title used across Workout, Timer, and History.
class VytalSectionHeader extends StatelessWidget {
  const VytalSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: extras.textMuted,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: theme.textTheme.titleMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Compact category chips (Cardio | Strength | Calisthenics, timer modes).
class VytalTabSelector<T> extends StatelessWidget {
  const VytalTabSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final active = value == selected;
          return ChoiceChip(
            label: Text(labelOf(value)),
            selected: active,
            onSelected: (_) => onChanged(value),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: VytalColors.teal.withValues(alpha: 0.16),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: active ? VytalColors.teal : extras.textMuted,
            ),
            side: BorderSide(
              color: active
                  ? VytalColors.teal.withValues(alpha: 0.45)
                  : extras.border,
            ),
          );
        },
      ),
    );
  }
}
