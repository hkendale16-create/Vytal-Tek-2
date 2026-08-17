import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../battery/battery_intelligence.dart';
import '../../battery/battery_providers.dart';
import '../../core/theme/vytal_colors.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../monitoring/monitoring_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class BatteryScreen extends ConsumerWidget {
  const BatteryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(batteryIntelligenceProvider);
    final monitoring = ref.watch(monitoringControllerProvider);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Battery',
      subtitle: 'Alerts, coarse estimates, and charging tips — no invented %.',
      actions: [
        IconButton(
          tooltip: 'Devices',
          onPressed: () => context.push('/devices'),
          icon: const Icon(Icons.watch_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            glow: insight.alertLevel != BatteryAlertLevel.ok,
            accent: switch (insight.alertLevel) {
              BatteryAlertLevel.critical || BatteryAlertLevel.low =>
                VytalColors.alert,
              BatteryAlertLevel.watch => VytalColors.caution,
              BatteryAlertLevel.ok => null,
            },
            child: Column(
              children: [
                Text(
                  insight.hasWearableReading
                      ? '${insight.wearablePercent}%'
                      : '—',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (insight.isDemo) ...[
                  const SizedBox(height: 8),
                  const StatusPill(label: 'Demo battery', emphasis: true),
                ],
                if (insight.estimatedHoursRemaining != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'About ${insight.estimatedHoursRemaining} hours remaining at ${monitoring.mode.label} (estimate).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  insight.charging
                      ? 'Charging'
                      : 'Charging state unknown until the wearable reports it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  insight.lastChargeAt == null
                      ? 'Last charge: not reported'
                      : 'Last charge: ${insight.lastChargeAt!.toLocal()}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (insight.estimatedSyncWindows != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Roughly ${insight.estimatedSyncWindows} sync windows left at ${monitoring.mode.label} load (estimate only).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final tip in insight.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bolt_outlined,
                            size: 18, color: VytalColors.teal),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tip)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/settings/monitoring'),
            child: const Text('Adjust monitoring'),
          ),
        ],
      ),
    );
  }
}
