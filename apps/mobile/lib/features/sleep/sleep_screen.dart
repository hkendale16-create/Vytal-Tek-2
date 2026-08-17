import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
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
    final extras = context.vytalExtras;
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
      violetGlow: true,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: extras.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isToday
                    ? null
                    : () => setState(
                          () => _day = _day.add(const Duration(days: 1)),
                        ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SizedBox(
            height: 300,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReadinessGauge(
                        score: score,
                        size: 196,
                        label: 'SLEEP SCORE',
                        provenance: score == null ? null : DataProvenance.demo,
                        onTap: () => context.push('/ask'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        !_isToday
                            ? 'No sleep record for this day.'
                            : score == null
                                ? (sleep?.freshness.label ??
                                    'Sleep score appears after wearable sleep sync.')
                                : 'Demo sleep presentation for UI review.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: extras.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 12,
                  child: FloatingHud(
                    child: SizedBox(
                      width: 124,
                      child: MetricHudTile(
                        compact: true,
                        accent: VytalColors.violet,
                        title: 'Duration',
                        value: durationLabel,
                        unit: '',
                        emptyMessage: 'No recent reading',
                        provenance: durationLabel != null && isDemo
                            ? DataProvenance.demo
                            : sleep?.provenance,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 36,
                  child: FloatingHud(
                    delay: const Duration(milliseconds: 420),
                    child: SizedBox(
                      width: 132,
                      child: MetricHudTile(
                        compact: true,
                        accent: VytalColors.violet,
                        title: 'Bedtime',
                        value: isDemo ? '23:12' : null,
                        unit: isDemo ? '→ 06:24' : '',
                        emptyMessage: 'No recent reading',
                        provenance:
                            isDemo ? DataProvenance.demo : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.graphic_eq,
            accent: VytalColors.violet,
            title: 'Overnight HRV',
            subtitle: health?.hrv.hasValue == true && _isToday
                ? '${health!.hrv.value} ms'
                : 'No recent reading',
            onTap: () => context.push('/vitals/${HealthMetricKeys.hrv}'),
          ),
          const SizedBox(height: 8),
          const HudStrip(
            icon: Icons.monitor_heart_outlined,
            accent: VytalColors.violet,
            title: 'Resting HR',
            subtitle: 'Not supported by this device',
          ),
          const SizedBox(height: 8),
          const HudStrip(
            icon: Icons.air,
            accent: VytalColors.violet,
            title: 'Respiratory rate',
            subtitle: 'Not supported by this device',
          ),
          const SizedBox(height: 8),
          const HudStrip(
            icon: Icons.nights_stay_outlined,
            accent: VytalColors.violet,
            title: 'Sleep debt / consistency',
            subtitle: 'No recent reading',
          ),
          const SizedBox(height: 16),
          EntitlementGate(
            entitlementKey: EntitlementKeys.sleepAdvanced,
            compactPaywall: true,
            child: GlassPanel(
              accent: const Color(0xFF3D6BFF),
              glow: true,
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
          const SizedBox(height: 8),
          TextButton.icon(
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
