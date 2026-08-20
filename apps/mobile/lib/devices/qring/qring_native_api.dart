import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qring_capability_matrix.dart';

/// Platform contract for the QRing / QCBand native SDK bridge.
///
/// Implementations must never invent vitals — return null / omit keys when the
/// device or SDK has no reading.
abstract class QRingNativeApi {
  Future<bool> isAvailable();

  Future<void> initialize();

  /// Emits discovered devices until [stopScan] or timeout.
  Stream<QRingScanResult> startScan({
    Duration timeout = const Duration(seconds: 12),
  });

  Future<void> stopScan();

  /// Connect + post-GATT handshake (SetTime + capability bitmap).
  Future<QRingNativeConnectionResult> connect(String deviceId);

  Future<void> disconnect({bool unbind = false});

  Future<bool> isConnected();

  Future<QRingDeviceSupportFlags> getCapabilities();

  Future<QRingBatteryReading?> readBattery();

  Future<QRingHealthSnapshot> syncHealth();

  Future<void> startWorkoutMonitoring();

  Future<void> stopWorkoutMonitoring();
}

class QRingScanResult {
  const QRingScanResult({
    required this.deviceId,
    required this.name,
    this.rssi,
  });

  final String deviceId;
  final String name;
  final int? rssi;

  factory QRingScanResult.fromMap(Map<dynamic, dynamic> map) {
    return QRingScanResult(
      deviceId: map['deviceId'] as String? ?? '',
      name: map['name'] as String? ?? 'QRing',
      rssi: map['rssi'] as int?,
    );
  }
}

class QRingNativeConnectionResult {
  const QRingNativeConnectionResult({
    required this.deviceId,
    required this.name,
    required this.flags,
    this.firmwareVersion,
  });

  final String deviceId;
  final String name;
  final QRingDeviceSupportFlags flags;
  final String? firmwareVersion;

  factory QRingNativeConnectionResult.fromMap(Map<dynamic, dynamic> map) {
    return QRingNativeConnectionResult(
      deviceId: map['deviceId'] as String? ?? '',
      name: map['name'] as String? ?? 'QRing',
      firmwareVersion: map['firmwareVersion'] as String?,
      flags: QRingDeviceSupportFlags.fromNativeMap(
        Map<String, dynamic>.from(
          (map['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      ),
    );
  }
}

class QRingBatteryReading {
  const QRingBatteryReading({
    required this.percent,
    this.charging = false,
    this.rawLevel,
  });

  final int percent;
  final bool charging;

  /// iOS discrete 0–8 when provided.
  final int? rawLevel;

  factory QRingBatteryReading.fromMap(Map<dynamic, dynamic> map) {
    return QRingBatteryReading(
      percent: map['percent'] as int? ?? 0,
      charging: map['charging'] as bool? ?? false,
      rawLevel: map['rawLevel'] as int?,
    );
  }
}

/// Snapshot of capability-gated readings from a sync pass. Null fields mean
/// no value was returned by the SDK (not fabricated).
class QRingHealthSnapshot {
  const QRingHealthSnapshot({
    this.battery,
    this.heartRateBpm,
    this.hrvMs,
    this.spo2Percent,
    this.temperatureCelsius,
    this.sleepMinutes,
    this.steps,
    this.calories,
    this.distanceMeters,
    this.sleepAvailable = false,
    this.stepsAvailable = false,
  });

  final QRingBatteryReading? battery;
  final int? heartRateBpm;
  final int? hrvMs;
  final int? spo2Percent;
  final double? temperatureCelsius;
  final int? sleepMinutes;
  final int? steps;
  final int? calories;
  final int? distanceMeters;
  final bool sleepAvailable;
  final bool stepsAvailable;

  factory QRingHealthSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final batteryMap = map['battery'];
    return QRingHealthSnapshot(
      battery: batteryMap is Map
          ? QRingBatteryReading.fromMap(batteryMap)
          : null,
      heartRateBpm: map['heartRateBpm'] as int?,
      hrvMs: map['hrvMs'] as int?,
      spo2Percent: map['spo2Percent'] as int?,
      temperatureCelsius: (map['temperatureCelsius'] as num?)?.toDouble(),
      sleepMinutes: map['sleepMinutes'] as int?,
      steps: map['steps'] as int?,
      calories: map['calories'] as int?,
      distanceMeters: map['distanceMeters'] as int?,
      sleepAvailable: map['sleepAvailable'] as bool? ?? false,
      stepsAvailable: map['stepsAvailable'] as bool? ?? false,
    );
  }
}

/// MethodChannel + EventChannel backed API (Android / iOS).
class MethodChannelQRingNativeApi implements QRingNativeApi {
  factory MethodChannelQRingNativeApi({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) {
    if (methodChannel != null || eventChannel != null) {
      return MethodChannelQRingNativeApi._(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
    }
    return _shared;
  }

  MethodChannelQRingNativeApi._({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ??
            const MethodChannel('com.vytaltek.qring/methods'),
        _events =
            eventChannel ?? const EventChannel('com.vytaltek.qring/events');

  static final MethodChannelQRingNativeApi _shared =
      MethodChannelQRingNativeApi._();

  final MethodChannel _methods;
  final EventChannel _events;

  StreamSubscription<dynamic>? _eventSub;
  final _scanController = StreamController<QRingScanResult>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _liveHrController = StreamController<int>.broadcast();
  Completer<QRingNativeConnectionResult>? _connectCompleter;
  bool _listening = false;

  Stream<void> get unexpectedDisconnects => _disconnectController.stream;
  Stream<String> get nativeErrors => _errorController.stream;
  Stream<int> get liveHeartRateUpdates => _liveHrController.stream;

  static const _unsupportedPlatforms = {
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.fuchsia,
  };

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      rethrow;
    }
  }

  Future<void> _ensureListening() async {
    if (_listening) return;
    _listening = true;
    _eventSub = _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    final payload = event['payload'];
    switch (type) {
      case 'scanResult':
        if (payload is Map) {
          _scanController.add(QRingScanResult.fromMap(payload));
        }
      case 'heartRateUpdate':
        if (payload is Map) {
          final bpm = payload['bpm'] as int?;
          if (bpm != null && bpm > 0) {
            _liveHrController.add(bpm);
          }
        }
      case 'connection':
        if (payload is Map) {
          final state = payload['state'] as String?;
          final completer = _connectCompleter;
          if (state == 'connected' &&
              completer != null &&
              !completer.isCompleted) {
            completer.complete(
              QRingNativeConnectionResult.fromMap(payload),
            );
            if (identical(_connectCompleter, completer)) {
              _connectCompleter = null;
            }
          } else if ((state == 'error' || state == 'disconnected') &&
              completer != null &&
              !completer.isCompleted) {
            completer.completeError(
              PlatformException(
                code: payload['code'] as String? ??
                    (state == 'disconnected' ? 'disconnected' : 'connect_failed'),
                message: payload['message'] as String? ??
                    'Could not connect to the wearable.',
              ),
            );
            if (identical(_connectCompleter, completer)) {
              _connectCompleter = null;
            }
          } else if (state == 'disconnected') {
            _disconnectController.add(null);
          }
        }
      case 'error':
        final code = event['code'] as String? ??
            (payload is Map ? payload['code'] as String? : null) ??
            'native_error';
        if (code == 'bluetooth_off' && _connectCompleter != null) {
          _connectCompleter!.completeError(
            PlatformException(
              code: 'bluetooth_off',
              message: 'Bluetooth is turned off. Turn it on, then try again.',
            ),
          );
          _connectCompleter = null;
        }
        _errorController.add(code);
      default:
        break;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || _unsupportedPlatforms.contains(defaultTargetPlatform)) {
      return false;
    }
    final result = await _invoke<bool>('isAvailable');
    return result ?? false;
  }

  @override
  Future<void> initialize() async {
    await _ensureListening();
    await _invoke<void>('initialize');
  }

  @override
  Stream<QRingScanResult> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) {
    unawaited(() async {
      await _ensureListening();
      await _invoke<void>('startScan', {
        'timeoutMs': timeout.inMilliseconds,
      });
    }());
    return _scanController.stream;
  }

  @override
  Future<void> stopScan() async {
    await _invoke<void>('stopScan');
  }

  @override
  Future<QRingNativeConnectionResult> connect(String deviceId) async {
    await _ensureListening();
    final completer = Completer<QRingNativeConnectionResult>();
    _connectCompleter = completer;
    try {
      final immediate = await _invoke<Map>('connect', {'deviceId': deviceId});
      if (immediate != null && !completer.isCompleted) {
        completer.complete(QRingNativeConnectionResult.fromMap(immediate));
        _connectCompleter = null;
      }
    } on PlatformException catch (error) {
      // Event channel may have already completed this connect successfully.
      if (completer.isCompleted) {
        return completer.future;
      }
      if (identical(_connectCompleter, completer)) {
        _connectCompleter = null;
      }
      // Ignore benign cancel from a superseded native connect attempt.
      if (error.code == 'cancelled' && completer.isCompleted) {
        return completer.future;
      }
      if (error.code == 'cancelled') {
        throw PlatformException(
          code: 'connect_failed',
          message: error.message ?? 'Could not connect to the wearable.',
        );
      }
      rethrow;
    }
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        if (identical(_connectCompleter, completer)) {
          _connectCompleter = null;
        }
        throw PlatformException(
          code: 'connect_timeout',
          message:
              'Connecting timed out. Keep the ring nearby and try again.',
        );
      },
    );
  }

  @override
  Future<void> disconnect({bool unbind = false}) async {
    await _invoke<void>('disconnect', {'unbind': unbind});
  }

  @override
  Future<bool> isConnected() async {
    return await _invoke<bool>('isConnected') ?? false;
  }

  @override
  Future<QRingDeviceSupportFlags> getCapabilities() async {
    final map = await _invoke<Map>('getCapabilities');
    if (map == null) return QRingDeviceSupportFlags.pending;
    return QRingDeviceSupportFlags.fromNativeMap(
      Map<String, dynamic>.from(map.cast<String, dynamic>()),
    );
  }

  @override
  Future<QRingBatteryReading?> readBattery() async {
    final map = await _invoke<Map>('readBattery');
    if (map == null) return null;
    return QRingBatteryReading.fromMap(map);
  }

  @override
  Future<QRingHealthSnapshot> syncHealth() async {
    final map = await _invoke<Map>('syncHealth');
    if (map == null) return const QRingHealthSnapshot();
    return QRingHealthSnapshot.fromMap(map);
  }

  @override
  Future<void> startWorkoutMonitoring() async {
    await _invoke<void>('startWorkoutMonitoring');
  }

  @override
  Future<void> stopWorkoutMonitoring() async {
    await _invoke<void>('stopWorkoutMonitoring');
  }

  void dispose() {
    // Shared bridge stays alive; cancel only this wrapper's subscription if any.
    _eventSub?.cancel();
  }
}
