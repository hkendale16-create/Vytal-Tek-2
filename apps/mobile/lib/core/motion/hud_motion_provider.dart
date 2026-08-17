import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/monitoring_mode.dart';
import '../../monitoring/monitoring_controller.dart';

/// False when HUD float / 3D ambient motion should stop.
final hudMotionEnabledProvider = Provider<bool>((ref) {
  final slice = ref.watch(
    monitoringControllerProvider.select(
      (s) => (
        mode: s.mode,
        foreground: s.signals.appInForeground,
        saver: s.signals.phoneBatterySaver,
      ),
    ),
  );
  if (!slice.foreground) return false;
  if (slice.mode == MonitoringMode.standby) return false;
  if (slice.saver) return false;
  return true;
});
