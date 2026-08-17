import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_catalog.dart';
import '../../core/permissions/permissions_controller.dart';
import '../shared/ui_primitives.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(permissionsControllerProvider);
    final controller = ref.read(permissionsControllerProvider.notifier);

    return SectionScaffold(
      title: 'Permissions',
      subtitle: 'Vytal asks only for what features need. You can change these anytime.',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          for (final item in PermissionCatalog.core) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusPill(
                          label: (statuses[item.id] ??
                                  VytalPermissionStatus.unknown)
                              .label,
                          emphasis: (statuses[item.id] ??
                                  VytalPermissionStatus.unknown)
                              .isEffectivelyGranted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Why: ${item.whyNeeded}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If disabled: ${item.affectedWhenDenied}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => controller.request(item),
                          child: const Text('Request'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: item.opensAppSettingsWhenDenied
                              ? controller.openSystemSettings
                              : null,
                          child: const Text('System settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
