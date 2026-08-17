import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/health_metric.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final sleep = health?.sleep;
    final isDemo = health?.provenance == DataProvenance.demo && _isToday;
    final score = isDemo ? 87 : null;
    final durationLabel = !_isToday
        ? null
        : sleep?.hasValue == true
            ? _formatDuration(sleep!.value!)
            : (isDemo ? '7h 12m' : null);

    return SectionScaffold(
      title: 'Sleep',
      subtitle: 'Calmer surface — purple/blue accents from the approved boards.',
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _day = _day.subtract(const Duration(days: 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}'
                  '${_isToday ? ' · Today' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _isToday
                    ? null
                    : () => setState(
                          () => _day = _day.add(const Duration(days: 1)),
                        ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GlassPanel(
            accent: VytalColors.violet,
            glow: true,
            child: Column(
              children: [
                ReadinessGauge(
                  score: score,
                  label: 'SLEEP SCORE',
                  subtitle: durationLabel,
                  provenance: score == null ? null : DataProvenance.demo,
                  onTap: () => context.push('/ask'),
                ),
                const SizedBox(height: 8),
                Text(
                  !_isToday
                      ? 'No sleep record for this day.'
                      : score == null
                          ? (sleep?.freshness.label ??
                              'Sleep score appears after wearable sleep sync.')
                          : 'Demo sleep presentation for UI review.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SleepMetric(
            title: 'Duration',
            value: durationLabel ?? 'No recent reading',
          ),
          _SleepMetric(
            title: 'Bedtime / wake',
            value: isDemo ? '23:12 → 06:24 (Demo)' : 'No recent reading',
          ),
          _SleepMetric(
            title: 'Overnight HRV',
            value: health?.hrv.hasValue == true && _isToday
                ? '${health!.hrv.value} ms'
                : 'No recent reading',
          ),
          _SleepMetric(
            title: 'Resting HR',
            value: 'Not supported by this device',
          ),
          _SleepMetric(
            title: 'Respiratory rate',
            value: 'Not supported by this device',
          ),
          _SleepMetric(
            title: 'Sleep debt / consistency',
            value: 'No recent reading',
          ),
          const SizedBox(height: 16),
          EntitlementGate(
            entitlementKey: EntitlementKeys.sleepAdvanced,
            compactPaywall: true,
            child: GlassPanel(
              accent: const Color(0xFF3D6BFF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stages', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (isDemo)
                    const SleepStageLegend(
                      rem: 1.4,
                      deep: 1.8,
                      light: 3.5,
                      awake: 0.4,
                    )
                  else
                    Text(
                      'Stage breakdown stays empty until the wearable reports sleep.',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/ask'),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ask Vytal about my sleep'),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _SleepMetric extends StatelessWidget {
  const _SleepMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
