import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_catalog.dart';
import 'permissions_controller.dart';

/// Contextual permission sheet. Does not request every permission at launch.
Future<bool> ensureVytalPermission({
  required BuildContext context,
  required WidgetRef ref,
  required PermissionDescriptor item,
  required String headline,
  required String explanation,
}) async {
  final controller = ref.read(permissionsControllerProvider.notifier);
  await controller.refresh();
  final current = ref.read(permissionsControllerProvider)[item.id] ??
      VytalPermissionStatus.unknown;
  if (current.isEffectivelyGranted) return true;
  if (current == VytalPermissionStatus.unsupported ||
      current == VytalPermissionStatus.notApplicable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} isn’t available on this platform.')),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(headline, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Affected if declined: ${item.affectedWhenDenied}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );
  if (proceed != true) return false;

  final result = await controller.request(item);
  if (result.isEffectivelyGranted) return true;
  if (result == VytalPermissionStatus.permanentlyDenied && context.mounted) {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enable ${item.title}'),
        content: const Text(
          'This permission is blocked in system settings. Open Settings to enable it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (open == true) await controller.openSystemSettings();
  }
  return false;
}
