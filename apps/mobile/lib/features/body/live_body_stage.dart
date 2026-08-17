import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/vytal_motion.dart';
import '../../core/theme/vytal_colors.dart';

enum BodyRegion { chest, legs, head, shoulders, core }

/// Phase 5 — interactive holographic body / wearable stage.
///
/// Uses perspective transforms + ambient motion (not a full GPU mesh). Animations
/// pause when [TickerMode] is off or the route is not visible.
class LiveBodyStage extends StatefulWidget {
  const LiveBodyStage({
    super.key,
    this.highlightHeart = false,
    this.highlightShoulders = false,
    this.highlightLegs = false,
    this.highlightCore = false,
    this.ambientMotionLevel = 2,
    this.showRing = true,
    this.childOverlay,
    this.onRegionSelected,
  });

  final bool highlightHeart;
  final bool highlightShoulders;
  final bool highlightLegs;
  final bool highlightCore;
  final int ambientMotionLevel;
  final bool showRing;
  final Widget? childOverlay;
  final ValueChanged<BodyRegion>? onRegionSelected;

  @override
  State<LiveBodyStage> createState() => _LiveBodyStageState();
}

class _LiveBodyStageState extends State<LiveBodyStage>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _spin;
  double _dragYaw = 0;
  double _dragPitch = 0;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: VytalMotion.ambient,
    );
    _spin = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 12000 ~/ math.max(1, widget.ambientMotionLevel)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant LiveBodyStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ambientMotionLevel != widget.ambientMotionLevel) {
      _spin.duration = Duration(
        milliseconds: 12000 ~/ math.max(1, widget.ambientMotionLevel),
      );
    }
    _syncMotion();
  }

  void _syncMotion() {
    final animate =
        widget.ambientMotionLevel > 0 && VytalMotion.hudMotionEnabled(context);
    if (!animate) {
      _breath.stop();
      _spin.stop();
      return;
    }
    if (!_breath.isAnimating) _breath.repeat(reverse: true);
    if (widget.ambientMotionLevel >= 2) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = VytalMotion.hudMotionEnabled(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _dragYaw += details.delta.dx * 0.01;
              _dragPitch =
                  (_dragPitch + details.delta.dy * 0.008).clamp(-0.45, 0.45);
            });
          },
          onDoubleTap: () => setState(() {
            _dragYaw = 0;
            _dragPitch = 0;
          }),
          onTapUp: widget.onRegionSelected == null
              ? null
              : (details) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;
                  final y = details.localPosition.dy / h;
                  final x = details.localPosition.dx / w;
                  if (y < 0.22) {
                    widget.onRegionSelected!(BodyRegion.head);
                  } else if (y < 0.38 && (x < 0.32 || x > 0.68)) {
                    widget.onRegionSelected!(BodyRegion.shoulders);
                  } else if (y < 0.52) {
                    widget.onRegionSelected!(BodyRegion.chest);
                  } else if (y < 0.62) {
                    widget.onRegionSelected!(BodyRegion.core);
                  } else {
                    widget.onRegionSelected!(BodyRegion.legs);
                  }
                },
          child: AnimatedBuilder(
            animation: Listenable.merge([_breath, _spin]),
            builder: (context, _) {
              final breath = animate ? _breath.value : 0.5;
              final autoYaw =
                  animate && widget.ambientMotionLevel >= 2 ? _spin.value * math.pi * 2 * 0.08 : 0.0;
              final yaw = _dragYaw + autoYaw;
              final pitch = _dragPitch;
              final scale = 0.96 + breath * 0.04;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft holographic floor glow
                  Positioned(
                    bottom: 12,
                    child: Container(
                      width: constraints.maxWidth * 0.55,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: VytalColors.cyan.withValues(alpha: 0.12 + breath * 0.08),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateY(yaw)
                      ..rotateX(pitch)
                      ..multiply(Matrix4.diagonal3Values(scale, scale, scale)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(
                            constraints.maxWidth * 0.55,
                            constraints.maxHeight * 0.78,
                          ),
                          painter: _HumanMeshPainter(
                            yaw: yaw,
                            pitch: pitch,
                            breath: breath,
                            highlightHeart: widget.highlightHeart,
                            highlightShoulders: widget.highlightShoulders,
                            highlightLegs: widget.highlightLegs,
                            highlightCore: widget.highlightCore,
                          ),
                        ),
                        if (widget.showRing)
                          Positioned(
                            right: constraints.maxWidth * 0.18,
                            top: constraints.maxHeight * 0.42,
                            child: _WearableRingGlyph(pulse: breath),
                          ),
                      ],
                    ),
                  ),
                  if (widget.childOverlay != null) widget.childOverlay!,
                  Positioned(
                    bottom: 0,
                    child:                 Text(
                  'Drag to rotate · tap chest for heart, legs for training load · double-tap to reset',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VytalColors.teal.withValues(alpha: 0.8),
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _WearableRingGlyph extends StatelessWidget {
  const _WearableRingGlyph({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final size = 28.0 + pulse * 4;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VytalColors.cyan, width: 3),
        boxShadow: [
          BoxShadow(
            color: VytalColors.cyan.withValues(alpha: 0.22),
            blurRadius: 8 + pulse * 4,
          ),
        ],
        gradient: RadialGradient(
          colors: [
            VytalColors.cyan.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _HumanMeshPainter extends CustomPainter {
  _HumanMeshPainter({
    required this.yaw,
    required this.pitch,
    required this.breath,
    required this.highlightHeart,
    required this.highlightShoulders,
    required this.highlightLegs,
    required this.highlightCore,
  });

  final double yaw;
  final double pitch;
  final double breath;
  final bool highlightHeart;
  final bool highlightShoulders;
  final bool highlightLegs;
  final bool highlightCore;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.46;
    void ellipsoid(Offset c, double rx, double ry, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            color,
            Color.lerp(color, Colors.black, 0.28)!,
          ],
        ).createShader(
          Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        paint,
      );
    }

    final sway = math.sin(yaw) * 10;
    final lift = breath * 4;
    final skin = VytalColors.teal.withValues(alpha: 0.38);
    final limb = VytalColors.cyan.withValues(alpha: 0.32);
    final load = VytalColors.green.withValues(alpha: 0.55);

    ellipsoid(
      Offset(cx + sway * 0.15, cy - size.height * 0.32 + lift),
      22,
      26,
      skin,
    );
    ellipsoid(
      Offset(cx + sway, cy - size.height * 0.08 + lift),
      48,
      70,
      highlightCore ? load : skin,
    );
    ellipsoid(
      Offset(cx - 58 + sway, cy - size.height * 0.12 + lift),
      16,
      48,
      highlightShoulders ? load : limb,
    );
    ellipsoid(
      Offset(cx + 58 + sway, cy - size.height * 0.12 + lift),
      16,
      48,
      highlightShoulders ? load : limb,
    );
    ellipsoid(
      Offset(cx - 18 + sway * 0.4, cy + size.height * 0.22 + lift * 0.4),
      18,
      70,
      highlightLegs ? load : limb,
    );
    ellipsoid(
      Offset(cx + 18 + sway * 0.4, cy + size.height * 0.22 + lift * 0.4),
      18,
      70,
      highlightLegs ? load : limb,
    );
    if (highlightHeart) {
      canvas.drawCircle(
        Offset(cx + 8 + sway, cy - size.height * 0.12 + lift),
        7 + breath * 2,
        Paint()
          ..color = VytalColors.teal.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HumanMeshPainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.breath != breath ||
      oldDelegate.highlightHeart != highlightHeart ||
      oldDelegate.highlightShoulders != highlightShoulders ||
      oldDelegate.highlightLegs != highlightLegs ||
      oldDelegate.highlightCore != highlightCore;
}
