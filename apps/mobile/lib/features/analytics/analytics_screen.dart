import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../state/app_session_controller.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _range = '7D';
  String _metric = 'Heart Rate';

  static const _basicRanges = {'7D', '30D'};
  static const _advancedRanges = {'90D', '1Y'};
  static const _metrics = [
    'Heart Rate',
    'HRV',
    'Sleep',
    'Activity',
    'Recovery',
    'Workout Load',
  ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final entitlements = ref.watch(entitlementServiceProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final demo = health?.provenance == DataProvenance.demo;
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final canAdvanced = entitlements.canUse(EntitlementKeys.analyticsAdvanced);
    final canHistory = entitlements.canUse(EntitlementKeys.historyExtended);

    return SectionScaffold(
      title: 'Insights',
      subtitle: 'Aggregated trends — not every raw sample.',
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _metrics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final metric = _metrics[index];
                return ChoiceChip(
                  label: Text(metric),
                  selected: _metric == metric,
                  onSelected: (_) => setState(() => _metric = metric),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final range in const ['7D', '30D', '90D', '1Y']) ...[
                if (range != '7D') const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(range)),
                    selected: _range == range,
                    onSelected: (_) {
                      setState(() => _range = range);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_advancedRanges.contains(_range) && !(canAdvanced || canHistory))
            const SoftPaywall(
              entitlementKey: EntitlementKeys.analyticsAdvanced,
              compact: true,
            )
          else
            GlassPanel(
              glow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_metric · $_range',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: demo
                        ? VitalSparkline(
                            values: _demoSeries(_metric, _range),
                          )
                        : Center(
                            child: Text(
                              session.demoModeEnabled
                                  ? 'Pair a demo device to preview labeled trend charts.'
                                  : 'Charts appear when wearable or manual history exists.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: extras.textMuted,
                              ),
                            ),
                          ),
                  ),
                  if (demo) ...[
                    const SizedBox(height: 8),
                    const ProvenanceCaption(provenance: DataProvenance.demo),
                  ],
                  if (_basicRanges.contains(_range) &&
                      !entitlements.canUse(EntitlementKeys.analyticsBasic))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Basic insights require analytics.basic.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          EntitlementGate(
            entitlementKey: EntitlementKeys.recoveryAdvanced,
            compactPaywall: true,
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery insight', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    demo
                        ? 'Demo: body status looks ready for training based on labeled demo HRV and sleep — not medical advice.'
                        : 'Insights stay empty until verified wearable summaries exist. Vytal will not invent diagnoses.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Labeled Demo series only — length follows the selected range.
  List<double> _demoSeries(String metric, String range) {
    final n = switch (range) {
      '7D' => 7,
      '30D' => 30,
      '90D' => 16,
      '1Y' => 12,
      _ => 7,
    };
    final base = switch (metric) {
      'HRV' => 62.0,
      'Sleep' => 7.2,
      'Activity' => 6400.0,
      'Recovery' => 80.0,
      'Workout Load' => 42.0,
      _ => 70.0,
    };
    return List<double>.generate(n, (i) => base + ((i % 5) - 2) * (base * 0.02));
  }
}
