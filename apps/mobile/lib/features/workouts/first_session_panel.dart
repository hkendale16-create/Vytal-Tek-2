import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/workout_models.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';

/// Three-tap first win: strength, short walk, or build a plan.
class FirstSessionPanel extends ConsumerWidget {
  const FirstSessionPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return GlassPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR FIRST SESSION',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: VytalColors.teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compact
                ? 'Pick one — under two minutes to start.'
                : 'Earn your first win. No wearable required.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Works in App-Only mode. A ring unlocks live HR later.',
            style: theme.textTheme.bodySmall?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              ref.read(workoutSessionProvider.notifier).startStrengthDraft(
                    name: WorkoutActivityKind.strength.label,
                    kind: WorkoutActivityKind.strength,
                  );
              context.push('/workouts/active');
            },
            icon: const Icon(Icons.fitness_center_outlined),
            label: const Text('Strength Quick Start'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(workoutSessionProvider.notifier).startActivity(
                    WorkoutActivityKind.walking,
                  );
              context.push('/workouts/active');
            },
            icon: const Icon(Icons.directions_walk_outlined),
            label: const Text('10‑min walk'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(
              '/ask?prompt=${Uri.encodeQueryComponent("Build me a 30-minute workout")}',
            ),
            child: const Text('Build a plan'),
          ),
        ],
      ),
    );
  }
}
