import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'workout_gps.dart';

/// Phone GPS for outdoor workouts. Web uses the browser Geolocation API.
abstract final class PhoneGps {
  static bool get supported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Stream<GpsFix> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
      ),
    ).map(
      (p) => GpsFix(
        latitude: p.latitude,
        longitude: p.longitude,
        at: p.timestamp,
        speedMps: p.speed.isFinite && p.speed >= 0 ? p.speed : null,
        accuracyMeters: p.accuracy.isFinite ? p.accuracy : null,
      ),
    );
  }
}
