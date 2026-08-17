import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/vytal_motion.dart';
import '../../core/theme/vytal_colors.dart';
import '../shared/health_ui.dart';

enum BodyRegion { chest, legs, head }

/// Phase 5 — interactive holographic body / wearable stage.
///
/// Uses perspective transforms + ambient motion (not a full GPU mesh). Animations
/// pause when [TickerMode] is off or the route is not visible.
class LiveBodyStage extends StatefulWidget {
  const LiveBodyStage({
    super.key,
    required this.highlightHeart,
    this.ambientMotionLevel = 2,
    this.showRing = true,
    this.childOverlay,
    this.onRegionSelected,
  });

  final bool highlightHeart;
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
    if (widget.ambientMotionLevel > 0) {
      _breath.repeat(reverse: true);
      if (widget.ambientMotionLevel >= 2) {
        _spin.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant LiveBodyStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ambientMotionLevel != widget.ambientMotionLevel) {
      _spin.duration = Duration(
        milliseconds: 12000 ~/ math.max(1, widget.ambientMotionLevel),
      );
      if (widget.ambientMotionLevel <= 0) {
        _breath.stop();
        _spin.stop();
      } else {
        if (!_breath.isAnimating) _breath.repeat(reverse: true);
        if (widget.ambientMotionLevel >= 2 && !_spin.isAnimating) {
          _spin.repeat();
        }
        if (widget.ambientMotionLevel < 2) _spin.stop();
      }
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
    final animate = VytalMotion.shouldAnimate(context);
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
                  final y = details.localPosition.dy / h;
                  if (y < 0.28) {
                    widget.onRegionSelected!(BodyRegion.head);
                  } else if (y < 0.55) {
                    widget.onRegionSelected!(BodyRegion.chest);
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
                            color: VytalColors.cyan.withValues(alpha: 0.25 + breath * 0.15),
                            blurRadius: 28,
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
                        BodySilhouette(highlightHeart: widget.highlightHeart),
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
            color: VytalColors.cyan.withValues(alpha: 0.45),
            blurRadius: 12 + pulse * 8,
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
