import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Left-edge swipe → previous route. Does not capture mid-screen pans
/// (charts, sliders, 3D rotation). Root shells should use [RootPopGuard].
class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  double _dx = 0;
  bool _tracking = false;

  static const _edge = 28.0;
  static const _commit = 72.0;

  void _reset() {
    if (_dx == 0 && !_tracking) return;
    setState(() {
      _dx = 0;
      _tracking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(_dx * 0.35, 0),
          child: widget.child,
        ),
        if (widget.enabled)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _edge,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                if (!context.canPop()) return;
                _tracking = true;
              },
              onHorizontalDragUpdate: (details) {
                if (!_tracking) return;
                setState(() {
                  _dx = (_dx + details.delta.dx).clamp(0, 160);
                });
              },
              onHorizontalDragEnd: (details) {
                if (!_tracking) return;
                final velocity = details.primaryVelocity ?? 0;
                final shouldPop = _dx > _commit || velocity > 700;
                if (shouldPop && context.canPop()) {
                  context.pop();
                }
                _reset();
              },
              onHorizontalDragCancel: _reset,
            ),
          ),
      ],
    );
  }
}

/// Prevents Android system-back from leaving the app on primary tabs.
class RootPopGuard extends StatelessWidget {
  const RootPopGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: child,
    );
  }
}
