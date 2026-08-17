import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/vytal_motion.dart';
import '../../core/theme/vytal_colors.dart';
import '../../domain/devices/wearable_device.dart';

/// Lightweight 3D torus (ring) for Home. Lazy, paused offscreen / Reduce Motion.
class LiveDeviceStage extends StatefulWidget {
  const LiveDeviceStage({
    super.key,
    this.deviceKind = VytalDeviceKind.smartRing,
    this.connected = false,
    this.demo = false,
    this.heartRateBpm,
    this.onTap,
    this.height = 210,
  });

  final VytalDeviceKind deviceKind;
  final bool connected;
  final bool demo;
  final int? heartRateBpm;
  final VoidCallback? onTap;
  final double height;

  @override
  State<LiveDeviceStage> createState() => _LiveDeviceStageState();
}

class _LiveDeviceStageState extends State<LiveDeviceStage>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _float;
  late final AnimationController _pulse;
  double _dragYaw = 0.4;
  double _dragPitch = 0.35;
  bool _showReading = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  bool _canAnimate(BuildContext context) {
    if (!VytalMotion.hudMotionEnabled(context)) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutter')) return false;
    return true;
  }

  void _sync() {
    if (!mounted) return;
    if (_canAnimate(context)) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _spin.stop();
      _float.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    widget.onTap?.call();
    setState(() => _showReading = true);
    await _pulse.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _showReading = false);
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final animate = _canAnimate(context);
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onTap: _handleTap,
        onPanUpdate: (details) {
          setState(() {
            _dragYaw += details.delta.dx * 0.012;
            _dragPitch =
                (_dragPitch + details.delta.dy * 0.008).clamp(0.05, 0.85);
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _float, _pulse]),
          builder: (context, _) {
            final autoYaw = animate ? _spin.value * math.pi * 2 : 0.0;
            final lift = animate ? (_float.value - 0.5) * 8 : 0.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, lift),
                  child: CustomPaint(
                    size: Size(widget.height * 1.15, widget.height),
                    painter: _RingPainter(
                      yaw: _dragYaw + autoYaw * 0.35,
                      pitch: _dragPitch,
                      pulse: _pulse.value,
                      connected: widget.connected,
                      kind: widget.deviceKind,
                    ),
                  ),
                ),
                if (_showReading)
                  Positioned(
                    bottom: 12,
                    child: _LiveChip(
                      bpm: widget.heartRateBpm,
                      demo: widget.demo,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.bpm, required this.demo});

  final int? bpm;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final label = bpm == null
        ? (demo ? 'Demo · no live HR' : 'No live HR yet')
        : '${demo ? 'Demo ' : ''}$bpm BPM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VytalColors.teal.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: VytalColors.teal,
            ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.yaw,
    required this.pitch,
    required this.pulse,
    required this.connected,
    required this.kind,
  });

  final double yaw;
  final double pitch;
  final double pulse;
  final bool connected;
  final VytalDeviceKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 6;
    const major = 16;
    const minor = 10;
    final R = size.width * 0.22;
    final r = size.width * (kind == VytalDeviceKind.watch ? 0.055 : 0.07);
    final pulseScale = 1 + pulse * 0.08;

    final quads = <_Quad>[];
    for (var i = 0; i < major; i++) {
      for (var j = 0; j < minor; j++) {
        final u0 = i / major * math.pi * 2;
        final u1 = (i + 1) / major * math.pi * 2;
        final v0 = j / minor * math.pi * 2;
        final v1 = (j + 1) / minor * math.pi * 2;
        final p00 = _project(_torus(u0, v0, R, r), cx, cy, pulseScale);
        final p10 = _project(_torus(u1, v0, R, r), cx, cy, pulseScale);
        final p11 = _project(_torus(u1, v1, R, r), cx, cy, pulseScale);
        final p01 = _project(_torus(u0, v1, R, r), cx, cy, pulseScale);
        final n = _normal(u0 + 0.01, v0 + 0.01);
        quads.add(
          _Quad(
            points: [p00.xy, p10.xy, p11.xy, p01.xy],
            z: (p00.z + p10.z + p11.z + p01.z) / 4,
            shade: n,
          ),
        );
      }
    }
    quads.sort((a, b) => a.z.compareTo(b.z));

    final floor = Paint()
      ..color = VytalColors.teal.withValues(alpha: 0.08 + pulse * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.82),
        width: size.width * 0.42,
        height: 14,
      ),
      floor,
    );

    for (final q in quads) {
      final lit = (0.22 + 0.78 * q.shade).clamp(0.18, 1.0);
      final metal = Color.lerp(
        VytalColors.darkElevated,
        connected ? VytalColors.teal : VytalColors.darkTextSecondary,
        0.25 + lit * 0.45,
      )!;
      final path = Path()
        ..moveTo(q.points[0].dx, q.points[0].dy)
        ..lineTo(q.points[1].dx, q.points[1].dy)
        ..lineTo(q.points[2].dx, q.points[2].dy)
        ..lineTo(q.points[3].dx, q.points[3].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = metal);
    }
  }

  _Vec _torus(double u, double v, double R, double r) {
    final x = (R + r * math.cos(v)) * math.cos(u);
    final y = r * math.sin(v);
    final z = (R + r * math.cos(v)) * math.sin(u);
    return _rotate(_Vec(x, y, z));
  }

  _Vec _rotate(_Vec p) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final x1 = p.x * cy - p.z * sy;
    final z1 = p.x * sy + p.z * cy;
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;
    return _Vec(x1, y2, z2);
  }

  double _normal(double u, double v) {
    final n = _rotate(
      _Vec(math.cos(v) * math.cos(u), math.sin(v), math.cos(v) * math.sin(u)),
    );
    const lx = 0.35;
    const ly = -0.6;
    const lz = 0.72;
    final d = n.x * lx + n.y * ly + n.z * lz;
    return ((d / n.length) + 1) / 2;
  }

  _Proj _project(_Vec p, double cx, double cy, double scale) {
    const f = 420.0;
    final z = p.z + 220;
    final s = f / z * scale;
    return _Proj(Offset(cx + p.x * s, cy + p.y * s), p.z);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.pulse != pulse ||
      oldDelegate.connected != connected;
}

class _Vec {
  const _Vec(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
  double get length => math.sqrt(x * x + y * y + z * z);
}

class _Proj {
  const _Proj(this.xy, this.z);
  final Offset xy;
  final double z;
}

class _Quad {
  _Quad({required this.points, required this.z, required this.shade});
  final List<Offset> points;
  final double z;
  final double shade;
}
