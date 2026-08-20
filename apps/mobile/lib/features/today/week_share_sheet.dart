import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import 'training_guidance.dart';

Future<void> showWeekShareSheet(
  BuildContext context, {
  required WeeklyScorecard scorecard,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _WeekShareSheet(scorecard: scorecard),
  );
}

class _WeekShareSheet extends StatelessWidget {
  const _WeekShareSheet({required this.scorecard});

  final WeeklyScorecard scorecard;

  String get _shareText {
    final streak = scorecard.streakDays > 0
        ? ' · ${scorecard.streakDays}d streak'
        : '';
    return 'Vytal week$streak\n'
        '${scorecard.sessions} sessions · ${scorecard.totalMinutes} min · '
        '${scorecard.trainingDays} training days\n'
        '${scorecard.suggestion}\n'
        'Honest fitness OS — works with your ring or just your phone.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share your week', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Copy the summary or screenshot the card.',
            style: theme.textTheme.bodySmall?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 16),
          WeekShareCard(scorecard: scorecard),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _shareText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Week summary copied.')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy summary'),
          ),
        ],
      ),
    );
  }
}

/// Visual week card meant for screenshots / social shares.
class WeekShareCard extends StatelessWidget {
  const WeekShareCard({super.key, required this.scorecard});

  final WeeklyScorecard scorecard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VYTAL',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
              color: VytalColors.teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scorecard.isMondayReview ? 'Week in review' : 'This week',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (scorecard.streakDays > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                label: '${scorecard.streakDays} day streak',
                emphasis: true,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _ShareStat(label: 'Sessions', value: '${scorecard.sessions}'),
              _ShareStat(label: 'Minutes', value: '${scorecard.totalMinutes}'),
              _ShareStat(label: 'Days', value: '${scorecard.trainingDays}'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            scorecard.suggestion,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Text(
            'Honest fitness OS · ring optional',
            style: theme.textTheme.labelSmall?.copyWith(
              color: VytalColors.teal,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.label, required this.value});

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
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
