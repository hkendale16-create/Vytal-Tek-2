import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import 'training_guidance.dart';

class WeeklyScorecardCard extends StatelessWidget {
  const WeeklyScorecardCard({super.key, required this.scorecard});

  final WeeklyScorecard scorecard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final title = scorecard.isMondayReview ? 'Week in review' : 'This week';

    return GlassPanel(
      glow: scorecard.sessions > 0,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
                ),
              ),
              if (scorecard.streakDays > 0)
                StatusPill(
                  label: '${scorecard.streakDays}d streak',
                  emphasis: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Sessions',
                value: '${scorecard.sessions}',
              ),
              _Stat(
                label: 'Minutes',
                value: '${scorecard.totalMinutes}',
              ),
              _Stat(
                label: 'Days',
                value: '${scorecard.trainingDays}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            scorecard.suggestion,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: extras.textMuted,
              height: 1.35,
            ),
          ),
          if (scorecard.sessions > 0) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/workouts/history'),
                child: const Text('History'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: extras.textMuted,
              letterSpacing: 1.1,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
