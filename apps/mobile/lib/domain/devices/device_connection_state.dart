enum DeviceConnectionState {
  unpaired,
  scanning,
  pairing,
  connected,
  syncing,
  reconnecting,
  disconnected,
  error,
}

extension DeviceConnectionStateX on DeviceConnectionState {
  String get label => switch (this) {
        DeviceConnectionState.unpaired => 'Not paired',
        DeviceConnectionState.scanning => 'Scanning',
        DeviceConnectionState.pairing => 'Pairing',
        DeviceConnectionState.connected => 'Connected',
        DeviceConnectionState.syncing => 'Syncing',
        DeviceConnectionState.reconnecting => 'Reconnecting',
        DeviceConnectionState.disconnected => 'Disconnected',
        DeviceConnectionState.error => 'Connection issue',
      };

  bool get isLinked =>
      this == DeviceConnectionState.connected ||
      this == DeviceConnectionState.syncing;
}
