import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vytal_colors.dart';
import 'vytal_motion.dart';

/// App-wide ambient canvas: slow gradient drift + very light particles.
///
/// One engine per screen via [SectionScaffold] / Home. Honors Reduce Motion,
/// [HudMotionScope] (background / Standby / battery saver), and widget tests.
class AnimatedAmbientBackground extends StatefulWidget {
  const AnimatedAmbientBackground({
    super.key,
    this.intensity = 0.85,
    this.includeViolet = false,
  });

  final double intensity;
  final bool includeViolet;

  @override
  State<AnimatedAmbientBackground> createState() =>
      _AnimatedAmbientBackgroundState();
}

class _AnimatedAmbientBackgroundState extends State<AnimatedAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
  }

  bool _canAnimate(BuildContext context) {
    if (!VytalMotion.hudMotionEnabled(context)) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutter')) return false;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canAnimate(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.intensity * (isDark ? 1.0 : 0.72);
    if (!_canAnimate(context)) {
      return IgnorePointer(
        child: CustomPaint(
          painter: _AmbientPainter(
            t: 0,
            isDark: isDark,
            scale: scale,
            includeViolet: widget.includeViolet,
            animate: false,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AmbientPainter(
              t: _controller.value,
              isDark: isDark,
              scale: scale,
              includeViolet: widget.includeViolet,
              animate: true,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.t,
    required this.isDark,
    required this.scale,
    required this.includeViolet,
    required this.animate,
  });

  final double t;
  final bool isDark;
  final double scale;
  final bool includeViolet;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = animate ? math.sin(t * math.pi * 2) : 0.0;
    final drift2 = animate ? math.cos(t * math.pi * 2) : 0.0;

    void blob(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    blob(
      Offset(size.width * 0.18 + drift * 18, size.height * 0.08 + drift2 * 10),
      210,
      VytalColors.teal,
      0.09 * scale,
    );
    blob(
      Offset(size.width * 0.88 + drift2 * 14, size.height * 0.28 + drift * 12),
      180,
      includeViolet ? VytalColors.violet : VytalColors.cyan,
      0.07 * scale,
    );
    blob(
      Offset(size.width * 0.22 + drift2 * 10, size.height * 0.92 + drift * 8),
      160,
      VytalColors.cyan,
      0.06 * scale,
    );

    if (!animate) return;
    final particlePaint = Paint()
      ..color = VytalColors.teal.withValues(alpha: isDark ? 0.10 : 0.06);
    for (var i = 0; i < 8; i++) {
      final phase = (t + i / 8) % 1.0;
      final x = size.width * ((0.12 + i * 0.11 + drift * 0.01) % 1.0);
      final y = size.height * (0.15 + (phase * 0.7));
      canvas.drawCircle(Offset(x, y), 1.6, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.scale != scale ||
      oldDelegate.isDark != isDark;
}
