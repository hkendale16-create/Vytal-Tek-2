import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vytal_colors.dart';
import 'vytal_motion.dart';

/// Near-static charcoal field. Accent blobs stay barely visible.
///
/// Honors Reduce Motion, [HudMotionScope], and widget tests.
class AnimatedAmbientBackground extends StatefulWidget {
  const AnimatedAmbientBackground({
    super.key,
    this.intensity = 0.35,
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
      duration: const Duration(seconds: 42),
    );
  }

  bool _canAnimate(BuildContext context) {
    if (!VytalMotion.hudMotionEnabled(context)) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutter')) return false;
    return widget.intensity > 0.05;
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
    final scale = widget.intensity * (isDark ? 1.0 : 0.55);
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
    final charcoal = isDark ? VytalColors.darkElevated : VytalColors.lightElevated;
    final accent = includeViolet ? VytalColors.violet : VytalColors.teal;

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
      Offset(size.width * 0.5 + drift * 8, size.height * 0.08 + drift2 * 6),
      240,
      charcoal,
      0.55 * scale,
    );
    blob(
      Offset(size.width * 0.86 + drift2 * 6, size.height * 0.22),
      160,
      accent,
      0.028 * scale,
    );
    blob(
      Offset(size.width * 0.12, size.height * 0.92 + drift * 4),
      180,
      charcoal,
      0.4 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.scale != scale ||
      oldDelegate.isDark != isDark;
}
