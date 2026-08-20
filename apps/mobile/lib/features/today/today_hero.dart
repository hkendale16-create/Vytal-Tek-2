import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';
import '../shared/health_ui.dart';

/// WHOOP-style daily hero: one headline, one score, one primary action.
class TodayHero extends StatelessWidget {
  const TodayHero({
    super.key,
    required this.headline,
    required this.guidance,
    required this.readinessScore,
    required this.provenance,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryKey,
  });

  final String headline;
  final String guidance;
  final int? readinessScore;
  final DataProvenance? provenance;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return GlassPanel(
      glow: readinessScore != null && readinessScore! >= 60,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TRAINING READINESS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: VytalColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            guidance,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: extras.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ReadinessGauge(
              score: readinessScore,
              size: 200,
              label: 'READINESS',
              subtitle: readinessScore == null
                  ? 'Connect a device or train App-Only'
                  : provenance == DataProvenance.demo
                      ? 'Demo presentation'
                      : null,
              provenance: readinessScore == null ? null : provenance,
              onTap: null,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: secondaryKey,
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class TodayMetricRow extends StatelessWidget {
  const TodayMetricRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class TodayCompactMetric extends StatelessWidget {
  const TodayCompactMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.onTap,
  });

  final String label;
  final String? value;
  final String unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: extras.textMuted,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value ?? '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: theme.textTheme.bodySmall?.copyWith(
                  color: extras.textMuted,
                )),
            ],
          ),
        ),
      ),
    );
  }
}
