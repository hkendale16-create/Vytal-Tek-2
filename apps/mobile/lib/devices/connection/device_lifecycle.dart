import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/devices/device_connection_state.dart';
import '../../state/app_session_controller.dart';
import 'device_connection_controller.dart';

/// Reconnects a saved wearable when the app returns to the foreground.
final deviceLifecycleProvider = Provider<void>((ref) {
  final listener = _DeviceLifecycleListener(ref);
  WidgetsBinding.instance.addObserver(listener);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(listener));
});

class _DeviceLifecycleListener extends WidgetsBindingObserver {
  _DeviceLifecycleListener(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final session = _ref.read(appSessionProvider);
    if (session.pairedDevice == null || session.demoModeEnabled) return;
    final connection = _ref.read(deviceConnectionProvider);
    if (connection.state.isLinked) return;
    unawaited(
      _ref.read(deviceConnectionProvider.notifier).reconnectIfNeeded(),
    );
  }
}
