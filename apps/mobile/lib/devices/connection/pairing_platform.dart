import 'package:flutter/foundation.dart';

/// Where wearable BLE pairing can actually run.
///
/// QRing is wired for Android and iOS native builds. Web and desktop cannot
/// host the vendor SDK — that is a per-platform limit, not a global disable.
abstract final class PairingPlatform {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.fuchsia);

  /// Native QRing BLE pairing is implemented for Android and iOS only.
  static bool get blePairingSupported => isMobile;

  static String get shortName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isDesktop) return 'Desktop';
    return 'this platform';
  }

  static String limitationMessage({required bool demoModeEnabled}) {
    if (blePairingSupported) return '';
    if (isWeb) {
      return 'Bluetooth wearable pairing isn’t available in the web browser. '
          'Use the Android or iOS app to pair a Vytal ring'
          '${demoModeEnabled ? '' : ', or enable Demo mode in Settings to try the flow'}'
          '.';
    }
    if (isDesktop) {
      return 'This desktop build can’t reach the wearable Bluetooth SDK. '
          'Pair from the Android or iOS app'
          '${demoModeEnabled ? '' : ', or enable Demo mode in Settings'}'
          '.';
    }
    return 'Bluetooth wearable pairing isn’t available on this platform yet.';
  }
}
