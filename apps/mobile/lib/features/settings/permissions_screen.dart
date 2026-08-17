import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_catalog.dart';
import '../../core/permissions/permissions_controller.dart';
import '../shared/ui_primitives.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(permissionsControllerProvider);
    final controller = ref.read(permissionsControllerProvider.notifier);

    return SectionScaffold(
      title: 'Permissions',
      subtitle: 'Vytal asks only for what a feature needs, when you use it.',
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
                      'Feature: ${item.affectedWhenDenied}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => controller.request(item),
                          child: const Text('Enable Permission'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: item.opensAppSettingsWhenDenied
                              ? () async {
                                  await controller.openSystemSettings();
                                }
                              : null,
                          child: const Text('Open Settings'),
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
