import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    return SectionScaffold(
      title: 'Body',
      subtitle: 'Digital body visualization — adaptive quality in Phase 5.',
      child: Column(
        children: [
          EmptyMetricCard(
            title: '3D body overview',
            message: session.operatingMode == OperatingMode.connected
                ? 'Connected Mode is active. Regions will illuminate only for supported or calculated metrics.'
                : 'App-Only Mode: the body view stays available as a shell. No fabricated muscle-load or vitals.',
          ),
          const SizedBox(height: 12),
          const EmptyMetricCard(
            title: 'Capability-aware UI',
            message:
                'Unsupported device metrics are hidden via DeviceCapabilities — never shown as placeholders in production.',
          ),
        ],
      ),
    );
  }
}
