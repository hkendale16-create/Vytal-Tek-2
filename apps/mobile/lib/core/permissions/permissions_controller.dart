import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_catalog.dart';

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, Map<String, VytalPermissionStatus>>(
  (ref) => PermissionsController()..refresh(),
);

class PermissionsController
    extends StateNotifier<Map<String, VytalPermissionStatus>> {
  PermissionsController() : super(const {});

  Future<void> refresh() async {
    final next = <String, VytalPermissionStatus>{};
    for (final item in PermissionCatalog.core) {
      next[item.id] = await _statusFor(item);
    }
    state = next;
  }

  Future<VytalPermissionStatus> request(PermissionDescriptor item) async {
    if (item.unsupportedOnCurrentPlatform || kIsWeb && item.id == 'bluetooth') {
      final mapped = VytalPermissionStatus.unsupported;
      state = {...state, item.id: mapped};
      return mapped;
    }
    if (item.platformPermission == null) {
      return VytalPermissionStatus.notApplicable;
    }
    final current = await item.platformPermission!.status;
    if (current.isPermanentlyDenied) {
      final mapped = VytalPermissionStatus.permanentlyDenied;
      state = {...state, item.id: mapped};
      return mapped;
    }
    final result = await item.platformPermission!.request();
    final mapped = _map(result);
    state = {...state, item.id: mapped};
    return mapped;
  }

  Future<bool> openSystemSettings() => ph.openAppSettings();

  Future<VytalPermissionStatus> _statusFor(PermissionDescriptor item) async {
    if (item.unsupportedOnCurrentPlatform) {
      return VytalPermissionStatus.unsupported;
    }
    if (item.platformPermission == null) {
      return VytalPermissionStatus.notApplicable;
    }
    try {
      return _map(await item.platformPermission!.status);
    } catch (_) {
      return VytalPermissionStatus.unsupported;
    }
  }

  VytalPermissionStatus _map(ph.PermissionStatus status) {
    return switch (status) {
      ph.PermissionStatus.granted => VytalPermissionStatus.granted,
      ph.PermissionStatus.denied => VytalPermissionStatus.denied,
      ph.PermissionStatus.permanentlyDenied =>
        VytalPermissionStatus.permanentlyDenied,
      ph.PermissionStatus.restricted => VytalPermissionStatus.restricted,
      ph.PermissionStatus.limited => VytalPermissionStatus.limited,
      ph.PermissionStatus.provisional => VytalPermissionStatus.limited,
    };
  }
}
