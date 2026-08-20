enum DeviceConnectionState {
  unpaired,
  scanning,
  pairing,
  connecting,
  connected,
  syncing,
  ready,
  reconnecting,
  disconnected,
  devicesFound,
  error,
}

extension DeviceConnectionStateX on DeviceConnectionState {
  String get label => switch (this) {
        DeviceConnectionState.unpaired => 'Not paired',
        DeviceConnectionState.scanning => 'Searching',
        DeviceConnectionState.pairing => 'Pairing',
        DeviceConnectionState.connecting => 'Connecting',
        DeviceConnectionState.connected => 'Connected',
        DeviceConnectionState.syncing => 'Synchronizing',
        DeviceConnectionState.ready => 'Ready',
        DeviceConnectionState.reconnecting => 'Reconnecting',
        DeviceConnectionState.disconnected => 'Disconnected',
        DeviceConnectionState.devicesFound => 'Devices found',
        DeviceConnectionState.error => 'Connection failed',
      };

  bool get isLinked =>
      this == DeviceConnectionState.connected ||
      this == DeviceConnectionState.syncing ||
      this == DeviceConnectionState.ready;
}
