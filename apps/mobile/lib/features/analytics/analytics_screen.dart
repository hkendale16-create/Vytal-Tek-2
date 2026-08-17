import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../health/daily_summary_analytics.dart';
import '../../health/daily_summary_store.dart';
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
  final _analytics = const DailySummaryAnalytics();

  static const _basicRanges = {'7D', '30D'};
  static const _advancedRanges = {'90D', '1Y'};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final entitlements = ref.watch(entitlementServiceProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final summaries = ref.watch(dailySummaryStoreProvider).sorted;
    final demo = health?.provenance == DataProvenance.demo ||
        summaries.any((s) => s.provenance == DataProvenance.demo);
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final canAdvanced = entitlements.canUse(EntitlementKeys.analyticsAdvanced);
    final canHistory = entitlements.canUse(EntitlementKeys.historyExtended);
    final cached = _analytics.series(
      summaries: summaries,
      metric: _metric,
      range: _range,
      now: DateTime.now(),
    );
    final usingDemoFallback = cached.length < 2 && demo;
    final values = cached.length >= 2
        ? cached
        : (usingDemoFallback ? _demoSeries(_metric, _range) : const <double>[]);

    return SectionScaffold(
      title: 'Analytics',
      subtitle: 'Daily totals — not raw sensor samples.',
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DailySummaryAnalytics.metrics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final metric = DailySummaryAnalytics.metrics[index];
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
              glow: values.length >= 2,
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
                    child: values.length >= 2
                        ? VitalSparkline(values: values)
                        : Center(
                            child: Text(
                              session.demoModeEnabled
                                  ? 'Pair a demo device to preview labeled trend charts.'
                                  : 'Charts appear after a few days of summaries. Vytal does not download raw sample history for this view.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: extras.textMuted,
                              ),
                            ),
                          ),
                  ),
                  if (usingDemoFallback) ...[
                    const SizedBox(height: 8),
                    const ProvenanceCaption(provenance: DataProvenance.demo),
                  ] else if (values.length >= 2) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${values.length} aggregated point${values.length == 1 ? '' : 's'} from local daily summaries.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: extras.textMuted,
                      ),
                    ),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/recovery'),
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery insight',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        demo
                            ? 'Demo: body status looks ready for training based on labeled demo HRV and sleep — not medical advice.'
                            : 'Insights stay empty until verified wearable summaries exist. Vytal will not invent diagnoses.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap for Recovery or Ask Vytal',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: extras.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Labeled Demo series only — used when Demo is on and the cache is still empty.
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
