import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/devices/wearable_device.dart';

const _registryKey = 'vytal.devices.registry.v1';

/// Multi-device ready registry. Current product may use one wearable.
class DeviceRegistry {
  const DeviceRegistry({this.devices = const []});

  final List<WearableDeviceInfo> devices;

  WearableDeviceInfo? get primary => devices.isEmpty ? null : devices.first;

  DeviceRegistry upsert(WearableDeviceInfo device) {
    final next = [...devices.where((d) => d.id != device.id), device];
    return DeviceRegistry(devices: next);
  }

  DeviceRegistry rename(String id, String displayName) {
    return DeviceRegistry(
      devices: [
        for (final device in devices)
          if (device.id == id)
            device.copyWith(displayName: displayName.trim())
          else
            device,
      ],
    );
  }

  DeviceRegistry remove(String id) {
    return DeviceRegistry(
      devices: devices.where((d) => d.id != id).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'devices': devices.map((d) => d.toJson()).toList(),
      };

  factory DeviceRegistry.fromJson(Map<String, dynamic> json) {
    final raw = json['devices'] as List? ?? const [];
    return DeviceRegistry(
      devices: raw
          .whereType<Map>()
          .map((e) => WearableDeviceInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class DeviceRegistryStore {
  Future<DeviceRegistry> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registryKey);
    if (raw == null) return const DeviceRegistry();
    try {
      return DeviceRegistry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DeviceRegistry();
    }
  }

  Future<void> save(DeviceRegistry registry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registryKey, jsonEncode(registry.toJson()));
  }
}
