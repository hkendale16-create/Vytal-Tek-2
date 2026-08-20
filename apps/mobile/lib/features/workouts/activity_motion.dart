import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/workout_models.dart';

/// Lightweight activity-specific motion. Duration follows workout state, not a generic loop.
class ActivityMotion extends StatefulWidget {
  const ActivityMotion({
    super.key,
    required this.kind,
    required this.running,
  });

  final WorkoutActivityKind kind;
  final bool running;

  @override
  State<ActivityMotion> createState() => _ActivityMotionState();
}

class _ActivityMotionState extends State<ActivityMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.kind),
    );
    if (widget.running) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ActivityMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _controller.duration = _durationFor(widget.kind);
    }
    if (widget.running && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.running && _controller.isAnimating) {
      _controller.stop();
    }
  }

  Duration _durationFor(WorkoutActivityKind kind) {
    return switch (kind) {
      WorkoutActivityKind.running ||
      WorkoutActivityKind.treadmill =>
        const Duration(milliseconds: 420),
      WorkoutActivityKind.walking => const Duration(milliseconds: 780),
      WorkoutActivityKind.cycling ||
      WorkoutActivityKind.elliptical =>
        const Duration(milliseconds: 520),
      WorkoutActivityKind.stairClimber => const Duration(milliseconds: 480),
      WorkoutActivityKind.rowing => const Duration(milliseconds: 640),
      WorkoutActivityKind.jumpRope || WorkoutActivityKind.hiit =>
        const Duration(milliseconds: 360),
      WorkoutActivityKind.cardio => const Duration(milliseconds: 500),
      WorkoutActivityKind.strength => const Duration(milliseconds: 900),
      WorkoutActivityKind.calisthenics => const Duration(milliseconds: 720),
      WorkoutActivityKind.custom => const Duration(milliseconds: 700),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _ActivityPainter(
              kind: widget.kind,
              t: widget.running ? _controller.value : 0.2,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({required this.kind, required this.t});

  final WorkoutActivityKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VytalColors.teal
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (kind) {
      case WorkoutActivityKind.running:
      case WorkoutActivityKind.treadmill:
        _figure(canvas, Offset(cx, cy), paint, stride: 28 + t * 18, bounce: t * 10);
      case WorkoutActivityKind.walking:
        _figure(canvas, Offset(cx, cy), paint, stride: 14 + t * 10, bounce: t * 4);
      case WorkoutActivityKind.cycling:
      case WorkoutActivityKind.elliptical:
        canvas.drawCircle(Offset(cx - 28, cy + 18), 16, paint);
        canvas.drawCircle(Offset(cx + 28, cy + 18), 16, paint);
        canvas.drawLine(Offset(cx - 28, cy + 18), Offset(cx + 28, cy + 18), paint);
        canvas.drawLine(
          Offset(cx, cy + 18),
          Offset(cx + 8, cy - 22),
          paint,
        );
        final angle = t * 6.28;
        canvas.drawLine(
          Offset(cx + 28, cy + 18),
          Offset(
            cx + 28 + 14 * math.cos(angle),
            cy + 18 + 14 * math.sin(angle),
          ),
          paint,
        );
      case WorkoutActivityKind.stairClimber:
        _figure(canvas, Offset(cx, cy), paint, stride: 10 + t * 8, bounce: t * 16);
      case WorkoutActivityKind.rowing:
        final stroke = math.sin(t * 6.28) * 18;
        canvas.drawLine(Offset(cx - 36, cy + 22), Offset(cx + 36, cy + 22), paint);
        _figure(canvas, Offset(cx + stroke, cy), paint, stride: 6, bounce: 2);
      case WorkoutActivityKind.jumpRope:
        _figure(canvas, Offset(cx, cy), paint, stride: 8, bounce: t * 18);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy + 8), radius: 34),
          t * 6.28,
          3.2,
          false,
          paint,
        );
      case WorkoutActivityKind.strength:
        final lift = (t - 0.5).abs() * 24;
        canvas.drawLine(Offset(cx - 40, cy + 10 - lift), Offset(cx + 40, cy + 10 - lift), paint);
        _figure(canvas, Offset(cx, cy + 8), paint, stride: 8, bounce: -lift);
      case WorkoutActivityKind.calisthenics:
        _figure(canvas, Offset(cx, cy), paint, stride: 16 + t * 8, bounce: t * 8);
      case WorkoutActivityKind.cardio:
      case WorkoutActivityKind.hiit:
        _figure(canvas, Offset(cx, cy), paint, stride: 22 + t * 16, bounce: t * 12);
        canvas.drawCircle(Offset(cx + 50, cy - 20), 6 + t * 4, paint);
      case WorkoutActivityKind.custom:
        _figure(canvas, Offset(cx, cy), paint, stride: 12, bounce: t * 6);
    }
  }

  void _figure(
    Canvas canvas,
    Offset origin,
    Paint paint, {
    required double stride,
    required double bounce,
  }) {
    final head = Offset(origin.dx, origin.dy - 28 - bounce);
    canvas.drawCircle(head, 8, paint);
    canvas.drawLine(head.translate(0, 8), origin.translate(0, 10 - bounce), paint);
    canvas.drawLine(
      origin.translate(0, -4 - bounce),
      origin.translate(-18, 8 - bounce),
      paint,
    );
    canvas.drawLine(
      origin.translate(0, -4 - bounce),
      origin.translate(18, 8 - bounce),
      paint,
    );
    canvas.drawLine(
      origin.translate(0, 10 - bounce),
      origin.translate(-stride, 36),
      paint,
    );
    canvas.drawLine(
      origin.translate(0, 10 - bounce),
      origin.translate(stride, 36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.kind != kind;
}
