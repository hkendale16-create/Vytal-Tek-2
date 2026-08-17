import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';

/// Glass / HUD panel matching the approved mockups.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final edge = accent ?? VytalColors.teal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: extras.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: edge.withValues(alpha: isDark ? 0.45 : 0.28),
        ),
        boxShadow: [
          if (glow || isDark)
            BoxShadow(
              color: edge.withValues(alpha: isDark ? 0.22 : 0.1),
              blurRadius: isDark ? 22 : 14,
              spreadRadius: isDark ? 1 : 0,
            ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
  }
}

/// Large circular readiness / score gauge from the Home mockup.
class ReadinessGauge extends StatelessWidget {
  const ReadinessGauge({
    super.key,
    required this.score,
    required this.label,
    this.subtitle,
    this.provenance,
    this.onTap,
  });

  final int? score;
  final String label;
  final String? subtitle;
  final DataProvenance? provenance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final value = ((score ?? 0).clamp(0, 100)) / 100.0;
    final hasScore = score != null;

    final gauge = SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isDark)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: VytalColors.cyan.withValues(alpha: 0.18),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              // Always determinate so empty state is static (no perpetual spin).
              value: hasScore ? value : 0,
              strokeWidth: 12,
              backgroundColor: context.vytalExtras.elevated,
              color: VytalColors.teal,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasScore ? '$score' : '—',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: hasScore ? VytalColors.teal : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: VytalColors.teal,
                  letterSpacing: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
              if (provenance == DataProvenance.demo) ...[
                const SizedBox(height: 6),
                Text(
                  'DEMO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VytalColors.caution,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return gauge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: gauge,
      ),
    );
  }
}

class MetricHudTile extends StatelessWidget {
  const MetricHudTile({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.icon,
    this.provenance,
    this.emptyMessage,
    this.onTap,
  });

  final String title;
  final String? value;
  final String unit;
  final IconData? icon;
  final DataProvenance? provenance;
  final String? emptyMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null;
    final panel = GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: VytalColors.teal),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.vytalExtras.textMuted,
                  ),
                ),
              ),
              if (provenance == DataProvenance.demo)
                Text(
                  'Demo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VytalColors.caution,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasValue)
            RichText(
              text: TextSpan(
                text: value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: VytalColors.teal,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              emptyMessage ?? 'No reading',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

/// Simple trend line. Callers must pass real or explicitly labeled demo series.
class VitalSparkline extends StatelessWidget {
  const VitalSparkline({
    super.key,
    required this.values,
    this.color = VytalColors.teal,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(height: 140);
    }
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 2;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height *
          (1 - ((values[i] - minV) / (maxV - minV)).clamp(0, 1));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class ProvenanceCaption extends StatelessWidget {
  const ProvenanceCaption({super.key, required this.provenance, this.detail});

  final DataProvenance provenance;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final label = switch (provenance) {
      DataProvenance.demo => 'Demo · not real hardware',
      DataProvenance.wearable => 'Wearable',
      DataProvenance.manual => 'Manual',
      DataProvenance.derived => 'Derived',
    };
    return Text(
      detail == null ? label : '$label · $detail',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Activity move / exercise / stand rings inspired by the mockup.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.move,
    required this.exercise,
    required this.stand,
  });

  final double move;
  final double exercise;
  final double stand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: 180,
      child: CustomPaint(
        painter: _RingsPainter(
          move: move.clamp(0, 1),
          exercise: exercise.clamp(0, 1),
          stand: stand.clamp(0, 1),
          track: context.vytalExtras.elevated,
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.move,
    required this.exercise,
    required this.stand,
    required this.track,
  });

  final double move;
  final double exercise;
  final double stand;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    void ring(double radius, double progress, Color color) {
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = track
        ..strokeCap = StrokeCap.round;
      final valuePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, trackPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        progress * 6.28318,
        false,
        valuePaint,
      );
    }

    ring(74, move, VytalColors.teal);
    ring(56, exercise, VytalColors.green);
    ring(38, stand, VytalColors.cyan);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.move != move ||
      oldDelegate.exercise != exercise ||
      oldDelegate.stand != stand;
}

/// Soft body silhouette for Body screen until Phase 5 3D assets.
class BodySilhouette extends StatelessWidget {
  const BodySilhouette({super.key, this.highlightHeart = false});

  final bool highlightHeart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 0.55,
      child: CustomPaint(
        painter: _BodyPainter(
          outline: VytalColors.teal.withValues(alpha: isDark ? 0.85 : 0.7),
          fill: VytalColors.teal.withValues(alpha: isDark ? 0.12 : 0.08),
          heart: highlightHeart,
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.outline,
    required this.fill,
    required this.heart,
  });

  final Color outline;
  final Color fill;
  final bool heart;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.62, h * 0.04, w * 0.68, h * 0.12, w * 0.68, h * 0.16)
      ..cubicTo(w * 0.68, h * 0.2, w * 0.62, h * 0.24, w * 0.5, h * 0.24)
      ..cubicTo(w * 0.38, h * 0.24, w * 0.32, h * 0.2, w * 0.32, h * 0.16)
      ..cubicTo(w * 0.32, h * 0.12, w * 0.38, h * 0.04, w * 0.5, h * 0.04)
      ..moveTo(w * 0.5, h * 0.24)
      ..lineTo(w * 0.72, h * 0.3)
      ..lineTo(w * 0.86, h * 0.48)
      ..lineTo(w * 0.78, h * 0.5)
      ..lineTo(w * 0.66, h * 0.36)
      ..lineTo(w * 0.64, h * 0.55)
      ..lineTo(w * 0.7, h * 0.92)
      ..lineTo(w * 0.58, h * 0.92)
      ..lineTo(w * 0.54, h * 0.62)
      ..lineTo(w * 0.46, h * 0.62)
      ..lineTo(w * 0.42, h * 0.92)
      ..lineTo(w * 0.3, h * 0.92)
      ..lineTo(w * 0.36, h * 0.55)
      ..lineTo(w * 0.34, h * 0.36)
      ..lineTo(w * 0.22, h * 0.5)
      ..lineTo(w * 0.14, h * 0.48)
      ..lineTo(w * 0.28, h * 0.3)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = outline,
    );
    if (heart) {
      canvas.drawCircle(
        Offset(w * 0.52, h * 0.34),
        7,
        Paint()..color = VytalColors.alert.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) =>
      oldDelegate.heart != heart;
}

class SleepStageLegend extends StatelessWidget {
  const SleepStageLegend({
    super.key,
    required this.rem,
    required this.deep,
    required this.light,
    required this.awake,
  });

  final double rem;
  final double deep;
  final double light;
  final double awake;

  @override
  Widget build(BuildContext context) {
    final total = (rem + deep + light + awake).clamp(0.001, 999);
    Widget row(String name, double part, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
            Text('${((part / total) * 100).round()}%'),
          ],
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(flex: (rem * 100).round().clamp(1, 100), child: Container(color: VytalColors.violet)),
                Expanded(flex: (deep * 100).round().clamp(1, 100), child: Container(color: const Color(0xFF3D6BFF))),
                Expanded(flex: (light * 100).round().clamp(1, 100), child: Container(color: VytalColors.cyan)),
                Expanded(flex: (awake * 100).round().clamp(1, 100), child: Container(color: VytalColors.caution)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        row('REM', rem, VytalColors.violet),
        row('Deep', deep, const Color(0xFF3D6BFF)),
        row('Light', light, VytalColors.cyan),
        row('Awake', awake, VytalColors.caution),
      ],
    );
  }
}
