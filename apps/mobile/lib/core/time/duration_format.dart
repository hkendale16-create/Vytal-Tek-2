String formatClock(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$mm:$ss';
  }
  return '$mm:$ss';
}

String formatClockMs(int totalMs) {
  final ms = totalMs < 0 ? 0 : totalMs;
  final whole = ms ~/ 1000;
  final tenths = (ms % 1000) ~/ 100;
  return '${formatClock(whole)}.$tenths';
}
