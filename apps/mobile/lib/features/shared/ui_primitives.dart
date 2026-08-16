import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
          actions: actions,
        ),
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.emphasis = false,
  });

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis
            ? VytalColors.teal.withValues(alpha: 0.16)
            : extras.elevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: extras.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: emphasis ? VytalColors.teal : null,
            ),
      ),
    );
  }
}

class EmptyMetricCard extends StatelessWidget {
  const EmptyMetricCard({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VYTAL',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: isDark ? Colors.white : VytalColors.lightTextPrimary,
              ),
        ),
        if (!compact) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: Divider(color: VytalColors.teal.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'TEK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: VytalColors.teal,
                        letterSpacing: 3,
                      ),
                ),
              ),
              Expanded(child: Divider(color: VytalColors.teal.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ],
    );
  }
}
