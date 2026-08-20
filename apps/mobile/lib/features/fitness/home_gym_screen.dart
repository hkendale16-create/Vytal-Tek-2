import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../fitness/gym_discovery_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';

/// Toggle owned equipment for home workouts — never invents commercial gym stock.
class HomeGymScreen extends ConsumerWidget {
  const HomeGymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeGymProvider);
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final items = GymEquipmentItem.values
        .where((e) => e != GymEquipmentItem.noEquipment)
        .toList();

    return SectionScaffold(
      title: 'Home Gym',
      subtitle: 'Select what you own. Workouts filter to your gear.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VytalSectionHeader(
                  title: 'Equipment',
                  subtitle: 'Tap chips to toggle. Changes save automatically.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      FilterChip(
                        label: Text(item.label),
                        selected: profile.equipment.contains(item),
                        showCheckmark: false,
                        selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                        side: BorderSide(
                          color: profile.equipment.contains(item)
                              ? VytalColors.teal.withValues(alpha: 0.45)
                              : extras.border,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: profile.equipment.contains(item)
                              ? VytalColors.teal
                              : extras.textMuted,
                        ),
                        onSelected: (_) =>
                            ref.read(homeGymProvider.notifier).toggle(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.isEmpty
                ? 'No equipment selected — bodyweight and free-movement options stay available.'
                : '${profile.equipment.length} item${profile.equipment.length == 1 ? '' : 's'} selected.',
            style: theme.textTheme.bodySmall?.copyWith(color: extras.textMuted),
          ),
        ],
      ),
    );
  }
}
