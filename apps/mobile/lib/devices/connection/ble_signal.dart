/// Human-readable BLE signal strength from RSSI (dBm).
abstract final class BleSignal {
  static String label(int? rssi) {
    if (rssi == null) return 'Unknown';
    if (rssi >= -55) return 'Strong';
    if (rssi >= -70) return 'Good';
    if (rssi >= -85) return 'Medium';
    return 'Weak';
  }
}
