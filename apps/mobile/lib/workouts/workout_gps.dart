import 'dart:math' as math;

/// One GPS sample. Tests inject these; the phone source maps native positions.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.at,
    this.speedMps,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime at;
  final double? speedMps;
  final double? accuracyMeters;
}

/// On-device distance / speed / route from GPS samples. No cloud upload.
class WorkoutGpsTracker {
  double distanceMeters = 0;
  double? currentSpeedMps;
  GpsFix? last;
  final List<GpsFix> points = [];

  static const _maxPoints = 120;
  static const _minStepMeters = 1.2;
  static const _maxStepMeters = 80;

  void reset() {
    distanceMeters = 0;
    currentSpeedMps = null;
    last = null;
    points.clear();
  }

  void add(GpsFix fix) {
    if (fix.accuracyMeters != null && fix.accuracyMeters! > 45) return;
    final previous = last;
    if (previous != null) {
      final delta = haversineMeters(previous, fix);
      final dt = fix.at.difference(previous.at).inMilliseconds / 1000.0;
      if (delta < _minStepMeters) return;
      if (delta > _maxStepMeters) {
        last = fix;
        return;
      }
      distanceMeters += delta;
      if (dt > 0.4) {
        currentSpeedMps = delta / dt;
      }
    }
    if (fix.speedMps != null && fix.speedMps! > 0 && fix.speedMps! < 25) {
      currentSpeedMps = fix.speedMps;
    }
    last = fix;
    points.add(fix);
    if (points.length > _maxPoints) {
      points.removeRange(0, points.length - _maxPoints);
    }
  }

  /// Normalized 0–1 coordinates for a lightweight route sketch.
  List<({double x, double y})> get normalizedRoute {
    if (points.length < 2) return const [];
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final latSpan = math.max(maxLat - minLat, 0.00008);
    final lngSpan = math.max(maxLng - minLng, 0.00008);
    return [
      for (final p in points)
        (
          x: (p.longitude - minLng) / lngSpan,
          y: 1 - ((p.latitude - minLat) / latSpan),
        ),
    ];
  }
}

double haversineMeters(GpsFix a, GpsFix b) {
  const earth = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earth * math.asin(math.sqrt(h));
}

double _rad(double deg) => deg * math.pi / 180;

String formatDistanceKm(double meters) {
  if (meters < 10) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 1000 ? 2 : 1)} km';
}

/// min/km, or null if not enough distance.
String? formatPace(double meters, int elapsedSeconds) {
  if (meters < 20 || elapsedSeconds <= 0) return null;
  final secPerKm = elapsedSeconds / (meters / 1000);
  if (secPerKm > 3600 || secPerKm < 90) return null;
  final m = secPerKm.floor() ~/ 60;
  final s = secPerKm.floor() % 60;
  return '$m:${s.toString().padLeft(2, '0')}/km';
}

String? formatSpeedKmh(double? mps) {
  if (mps == null || mps <= 0) return null;
  return '${(mps * 3.6).toStringAsFixed(1)} km/h';
}

int estimatedStepsFromDistance({
  required double meters,
  required bool running,
}) {
  if (meters <= 0) return 0;
  final stride = running ? 0.78 : 0.72;
  return (meters / stride).round();
}
