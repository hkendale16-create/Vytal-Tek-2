import 'package:flutter/material.dart';

import '../../core/motion/ambient_background.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.glow = true,
    this.violetGlow = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool glow;
  final bool violetGlow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final scroll = CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true, title: Text(title), actions: actions),
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: extras.textMuted,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
    if (!glow) {
      return Scaffold(backgroundColor: extras.canvas, body: scroll);
    }
    return Scaffold(
      backgroundColor: extras.canvas,
      body: Stack(
        children: [
          AnimatedAmbientBackground(includeViolet: violetGlow),
          scroll,
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.emphasis = false});

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(compact ? 36 : 56, compact ? 36 : 56),
          painter: _VytalVPainter(glow: isDark, color: VytalColors.cyan),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          'VYTAL',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            color: isDark ? Colors.white : VytalColors.lightTextPrimary,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Divider(color: VytalColors.teal.withValues(alpha: 0.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'TEK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: VytalColors.teal,
                    letterSpacing: 4,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: VytalColors.teal.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VytalVPainter extends CustomPainter {
  _VytalVPainter({required this.glow, required this.color});

  final bool glow;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.12, h * 0.12)
      ..lineTo(w * 0.48, h * 0.88)
      ..lineTo(w * 0.62, h * 0.55)
      ..moveTo(w * 0.72, h * 0.18)
      ..lineTo(w * 0.88, h * 0.12);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.16
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.62),
      w * 0.055,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _VytalVPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.color != color;
}
