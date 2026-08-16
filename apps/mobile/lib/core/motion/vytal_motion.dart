import 'package:flutter/material.dart';

/// Centralized motion durations and easing for Vytal Tek.
///
/// Levels:
/// - L1 Micro: buttons, cards, value ticks
/// - L2 Health response: heartbeat, metric transitions
/// - L3 Ambient: waves, particles, slow device rotation
/// - L4 3D: device and body models (suspended when not visible)
abstract final class VytalMotion {
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration health = Duration(milliseconds: 420);
  static const Duration ambient = Duration(milliseconds: 2400);
  static const Duration scene = Duration(milliseconds: 700);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve softSpring = Curves.easeOutBack;

  /// Returns [preferred] unless reduced motion is active.
  static Duration durationFor(
    BuildContext context, {
    required Duration preferred,
    Duration reduced = Duration.zero,
  }) {
    final disable = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    // Also honor platform accessibility reduce-motion via disableAnimations.
    if (disable) return reduced;
    return preferred;
  }

  static bool shouldAnimate(BuildContext context) {
    return !MediaQuery.disableAnimationsOf(context);
  }
}
