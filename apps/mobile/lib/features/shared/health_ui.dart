import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/motion/vytal_motion.dart';
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isDark ? 18 : 10, sigmaY: isDark ? 18 : 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: extras.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: edge.withValues(alpha: isDark ? 0.45 : 0.28),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft radial blobs behind HUD canvases — matches the landing ambient field.
class AmbientCanvasGlow extends StatelessWidget {
  const AmbientCanvasGlow({
    super.key,
    this.intensity = 0.42,
    this.includeViolet = false,
  });

  final double intensity;
  final bool includeViolet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = intensity * (isDark ? 1.0 : 0.55);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -50,
            child: _blob(VytalColors.teal, 320, 0.22 * scale),
          ),
          Positioned(
            top: 180,
            right: -70,
            child: _blob(
              includeViolet ? VytalColors.violet : VytalColors.cyan,
              280,
              0.18 * scale,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            child: _blob(VytalColors.cyan, 220, 0.12 * scale),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Subtle vertical float for orbiting HUD tiles. Honors Reduce Motion.
class FloatingHud extends StatefulWidget {
  const FloatingHud({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.amplitude = 6,
  });

  final Widget child;
  final Duration delay;
  final double amplitude;

  @override
  State<FloatingHud> createState() => _FloatingHudState();
}

class _FloatingHudState extends State<FloatingHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  bool _canFloat(BuildContext context) {
    if (!VytalMotion.shouldAnimate(context)) return false;
    // Repeating tickers prevent pumpAndSettle in widget tests.
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutter')) return false;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canFloat(context)) {
      if (!_controller.isAnimating) {
        Future<void>.delayed(widget.delay, () {
          if (mounted && _canFloat(context)) {
            _controller.repeat(reverse: true);
          }
        });
      }
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canFloat(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, (t - 0.5) * widget.amplitude * 2),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class HudAction {
  const HudAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Circular icon orbs — compact chrome instead of filled-button dumps.
class HudActionRail extends StatelessWidget {
  const HudActionRail({super.key, required this.actions});

  final List<HudAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _HudOrb(action: action),
            ),
          ),
      ],
    );
  }
}

class _HudOrb extends StatelessWidget {
  const _HudOrb({required this.action});

  final HudAction action;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: extras.glassFill,
              border: Border.all(color: extras.border),
              boxShadow: [
                BoxShadow(
                  color: VytalColors.teal.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(action.icon, color: VytalColors.teal, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: extras.textMuted,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

/// Slim tappable glass row for device, coach, and timer status.
class HudStrip extends StatelessWidget {
  const HudStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.accent = VytalColors.teal,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final child = GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      accent: accent,
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: extras.textMuted,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: accent.withValues(alpha: 0.7),
            ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
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
    this.size = 220,
  });

  final int? score;
  final String label;
  final String? subtitle;
  final DataProvenance? provenance;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final value = ((score ?? 0).clamp(0, 100)) / 100.0;
    final hasScore = score != null;
    final ring = size * (200 / 220);

    final gauge = SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isDark)
            Container(
              width: ring,
              height: ring,
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
            width: ring,
            height: ring,
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
    this.compact = false,
    this.accent,
  });

  final String title;
  final String? value;
  final String unit;
  final IconData? icon;
  final DataProvenance? provenance;
  final String? emptyMessage;
  final VoidCallback? onTap;
  final bool compact;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null;
    final edge = accent ?? VytalColors.teal;
    final panel = GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 14),
      glow: compact,
      accent: edge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 13 : 16, color: edge),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.vytalExtras.textMuted,
                    letterSpacing: compact ? 1.1 : 1.3,
                    fontSize: compact ? 9 : 11,
                  ),
                ),
              ),
              if (provenance == DataProvenance.demo)
                Text(
                  'Demo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VytalColors.caution,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 9 : 11,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          if (hasValue)
            RichText(
              text: TextSpan(
                text: value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontSize: compact ? 20 : 24,
                ),
                children: [
                  TextSpan(
                    text: unit.isEmpty ? '' : ' $unit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: edge,
                      fontSize: compact ? 11 : 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              emptyMessage ?? 'No reading',
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: compact ? 10 : 12,
              ),
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
    this.size = 180,
  });

  final double move;
  final double exercise;
  final double stand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
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
    final stroke = (size.width * 0.067).clamp(8.0, 14.0);
    void ring(double radius, double progress, Color color) {
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track
        ..strokeCap = StrokeCap.round;
      final valuePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
      canvas.drawCircle(center, radius, trackPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        progress * 6.28318,
        false,
        valuePaint,
      );
    }

    final outer = size.width / 2 - stroke;
    ring(outer, move, VytalColors.teal);
    ring(outer - stroke * 1.7, exercise, VytalColors.green);
    ring(outer - stroke * 3.4, stand, VytalColors.cyan);
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
