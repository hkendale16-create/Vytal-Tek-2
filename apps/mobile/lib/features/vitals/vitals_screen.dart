import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/vytal_motion.dart';
import '../../core/theme/vytal_colors.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(todayHealthProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Vitals',
      subtitle: 'Missing values stay missing.',
      child: healthAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyMetricCard(
          title: 'Vitals unavailable',
          message: 'Could not load readings. Return to Today and retry.',
        ),
        data: (health) {
          final items = _catalog(health);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (connection.activeDevice == null && !health.hasWearableContext)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: EmptyMetricCard(
                    title: 'No connected reading',
                    message:
                        'Connect a Vytal device to begin receiving this measurement.',
                  ),
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.12,
                children: [
                  for (final item in items)
                    MetricHudTile(
                      compact: true,
                      title: item.title,
                      value: item.value,
                      unit: item.unit,
                      icon: item.icon,
                      provenance: item.provenance,
                      emptyMessage: item.empty,
                      status: item.value == null ? null : item.status,
                      timestampLabel:
                          item.value == null ? null : item.timestampLabel,
                      onTap: () => context.push('/vitals/${item.key}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tap a vital for timeline, status, and Coach context.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  List<_VitalRow> _catalog(TodayHealthSnapshot health) {
    String? intValue(HealthMetricReading<int> r) =>
        r.hasValue ? '${r.value}' : null;
    String hardwareEmpty(String fallback) {
      if (!health.hasWearableContext) {
        return 'Connect a Vytal device to begin receiving this measurement.';
      }
      return fallback;
    }

    String? stamp(DateTime? at) {
      if (at == null) return null;
      final local = at.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return [
      _VitalRow(
        key: HealthMetricKeys.heartRate,
        title: 'Heart Rate',
        value: intValue(health.heartRate),
        unit: 'BPM',
        icon: Icons.favorite_outline,
        provenance: health.heartRate.provenance,
        status: health.heartRate.freshness.label,
        timestampLabel: stamp(health.heartRate.capturedAt),
        empty: hardwareEmpty(
          health.heartRate.statusLabel ?? health.heartRate.freshness.label,
        ),
      ),
      _VitalRow(
        key: HealthMetricKeys.restingHeartRate,
        title: 'Resting Heart Rate',
        value: null,
        unit: 'BPM',
        icon: Icons.monitor_heart_outlined,
        provenance: DataProvenance.wearable,
        empty: hardwareEmpty('Not supported by this device'),
      ),
      _VitalRow(
        key: HealthMetricKeys.hrv,
        title: 'HRV',
        value: intValue(health.hrv),
        unit: 'ms',
        icon: Icons.graphic_eq,
        provenance: health.hrv.provenance,
        status: health.hrv.freshness.label,
        timestampLabel: stamp(health.hrv.capturedAt),
        empty: hardwareEmpty(
          health.hrv.statusLabel ?? health.hrv.freshness.label,
        ),
      ),
      _VitalRow(
        key: HealthMetricKeys.spo2,
        title: 'SpO₂',
        value: intValue(health.spo2),
        unit: '%',
        icon: Icons.water_drop_outlined,
        provenance: health.spo2.provenance,
        status: health.spo2.freshness.label,
        timestampLabel: stamp(health.spo2.capturedAt),
        empty: hardwareEmpty(
          health.spo2.statusLabel ?? health.spo2.freshness.label,
        ),
      ),
      _VitalRow(
        key: HealthMetricKeys.temperature,
        title: 'Temperature',
        value: health.temperature.hasValue
            ? health.temperature.value!.toStringAsFixed(1)
            : null,
        unit: '°C',
        icon: Icons.thermostat,
        provenance: health.temperature.provenance,
        status: health.temperature.freshness.label,
        timestampLabel: stamp(health.temperature.capturedAt),
        empty: hardwareEmpty(
          health.temperature.statusLabel ?? health.temperature.freshness.label,
        ),
      ),
      _VitalRow(
        key: HealthMetricKeys.respiratoryRate,
        title: 'Respiratory Rate',
        value: null,
        unit: '/min',
        icon: Icons.air,
        provenance: DataProvenance.wearable,
        empty: hardwareEmpty('Not supported by this device'),
      ),
      _VitalRow(
        key: HealthMetricKeys.steps,
        title: 'Steps',
        value: health.steps?.toString(),
        unit: '',
        icon: Icons.directions_walk,
        provenance: health.steps == null ? DataProvenance.wearable : health.provenance,
        status: health.steps == null ? null : ReadingFreshness.lastSynced.label,
        empty: hardwareEmpty('No recent reading'),
      ),
      _VitalRow(
        key: HealthMetricKeys.calories,
        title: 'Calories',
        value: health.calories?.toString(),
        unit: 'kcal',
        icon: Icons.local_fire_department_outlined,
        provenance:
            health.calories == null ? DataProvenance.wearable : health.provenance,
        status: health.calories == null ? null : ReadingFreshness.lastSynced.label,
        empty: hardwareEmpty('No recent reading'),
      ),
    ];
  }
}

class _VitalRow {
  const _VitalRow({
    required this.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.provenance,
    required this.empty,
    this.status,
    this.timestampLabel,
  });

  final String key;
  final String title;
  final String? value;
  final String unit;
  final IconData icon;
  final DataProvenance provenance;
  final String empty;
  final String? status;
  final String? timestampLabel;
}

class VitalDetailScreen extends ConsumerStatefulWidget {
  const VitalDetailScreen({super.key, required this.metricKey});

  final String metricKey;

  @override
  ConsumerState<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends ConsumerState<VitalDetailScreen> {
  bool _live = false;
  Timer? _poll;
  HealthMetricReading<dynamic>? _liveReading;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startLive() async {
    _poll?.cancel();
    setState(() => _live = true);
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refreshLive());
    await _refreshLive();
  }

  Future<void> _stopLive() async {
    _poll?.cancel();
    setState(() {
      _live = false;
      _liveReading = null;
    });
  }

  Future<void> _refreshLive() async {
    if (widget.metricKey != HealthMetricKeys.heartRate) return;
    final device = ref.read(wearableDeviceProvider);
    final reading = await device.getHeartRate();
    if (!mounted) return;
    setState(() => _liveReading = reading);
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final snapshot = _readingFor(health);
    final live = _liveReading;
    final reading = live ?? snapshot;
    final bpm = widget.metricKey == HealthMetricKeys.heartRate &&
            reading is HealthMetricReading<int> &&
            reading.hasValue
        ? reading.value
        : null;

    return SectionScaffold(
      title: reading?.displayName ?? 'Vital',
      subtitle: reading?.freshness.label ?? 'No recent reading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            glow: bpm != null,
            child: Column(
              children: [
                if (bpm != null) HeartPulse(bpm: bpm, live: _live || reading?.freshness == ReadingFreshness.live),
                Text(
                  reading?.hasValue == true
                      ? '${_format(reading!.value)} ${reading.unit ?? ''}'
                      : (reading?.statusLabel ??
                          reading?.freshness.label ??
                          'No recent reading'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _live ? 'LIVE' : (reading?.freshness.label ?? 'Last synced'),
                  style: theme.textTheme.labelLarge,
                ),
                if (reading?.capturedAt != null)
                  Text(
                    'Captured ${reading!.capturedAt!.toLocal()}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (reading?.provenance == DataProvenance.demo) ...[
                  const SizedBox(height: 8),
                  const StatusPill(label: 'Demo — not production', emphasis: true),
                ],
              ],
            ),
          ),
          if (widget.metricKey == HealthMetricKeys.heartRate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _live ? _stopLive : _startLive,
                    child: Text(_live ? 'Stop Reading' : 'Start Reading'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timeline', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: _seriesFor(reading).length >= 2
                      ? VitalSparkline(values: _seriesFor(reading))
                      : Center(
                          child: Text(
                            'No recent reading',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                ),
                if (reading?.provenance == DataProvenance.demo)
                  const ProvenanceCaption(provenance: DataProvenance.demo),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coach note', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_explanation(reading), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/ask'),
                  child: const Text('Ask Vytal about this metric'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  HealthMetricReading<dynamic>? _readingFor(TodayHealthSnapshot? health) {
    if (health == null) return null;
    return switch (widget.metricKey) {
      HealthMetricKeys.heartRate => health.heartRate,
      HealthMetricKeys.hrv => health.hrv,
      HealthMetricKeys.spo2 => health.spo2,
      HealthMetricKeys.temperature => health.temperature,
      HealthMetricKeys.steps => health.steps == null
          ? unavailableReading(
              key: HealthMetricKeys.steps,
              displayName: 'Steps',
              provenance: DataProvenance.wearable,
            )
          : HealthMetricReading<int>(
              key: HealthMetricKeys.steps,
              displayName: 'Steps',
              value: health.steps,
              provenance: health.provenance,
              freshness: ReadingFreshness.lastSynced,
            ),
      HealthMetricKeys.calories => health.calories == null
          ? unavailableReading(
              key: HealthMetricKeys.calories,
              displayName: 'Calories',
              provenance: DataProvenance.wearable,
              unit: 'kcal',
            )
          : HealthMetricReading<int>(
              key: HealthMetricKeys.calories,
              displayName: 'Calories',
              value: health.calories,
              unit: 'kcal',
              provenance: health.provenance,
              freshness: ReadingFreshness.lastSynced,
            ),
      HealthMetricKeys.restingHeartRate => unsupportedReading(
          key: HealthMetricKeys.restingHeartRate,
          displayName: 'Resting Heart Rate',
          unit: 'BPM',
        ),
      HealthMetricKeys.respiratoryRate => unsupportedReading(
          key: HealthMetricKeys.respiratoryRate,
          displayName: 'Respiratory Rate',
          unit: '/min',
        ),
      _ => unsupportedReading(
          key: widget.metricKey,
          displayName: 'Metric',
        ),
    };
  }

  List<double> _seriesFor(HealthMetricReading<dynamic>? reading) {
    if (reading == null || !reading.hasValue) return const [];
    if (reading.provenance != DataProvenance.demo) return const [];
    final base = reading.value is num ? (reading.value as num).toDouble() : 0.0;
    return [
      base - 3,
      base - 1,
      base + 1,
      base,
      base + 2,
      base - 2,
      base,
    ];
  }

  String _format(dynamic value) {
    if (value is Duration) {
      return '${value.inHours}h ${value.inMinutes.remainder(60)}m';
    }
    if (value is double) return value.toStringAsFixed(1);
    return '$value';
  }

  String _explanation(HealthMetricReading<dynamic>? reading) {
    if (reading == null || !reading.hasValue) {
      return 'No verified reading is available. Vytal will not invent a value.';
    }
    if (reading.provenance == DataProvenance.demo) {
      return 'This is a labeled Demo stream for development — not a production health measurement.';
    }
    return 'Latest verified ${reading.displayName} from the wearable adapter. Informational only — not a diagnosis.';
  }
}

class HeartPulse extends StatefulWidget {
  const HeartPulse({super.key, required this.bpm, required this.live});

  final int bpm;
  final bool live;

  @override
  State<HeartPulse> createState() => _HeartPulseState();
}

class _HeartPulseState extends State<HeartPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant HeartPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm || oldWidget.live != widget.live) {
      _sync();
    }
  }

  void _sync() {
    if (!widget.live || widget.bpm <= 0 || !VytalMotion.hudMotionEnabled(context)) {
      _controller.stop();
      return;
    }
    final ms = (60000 / widget.bpm).round().clamp(320, 2000);
    _controller.duration = Duration(milliseconds: ms);
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = widget.live ? 0.9 + (_controller.value * 0.2) : 1.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.favorite,
              size: 48,
              color: VytalColors.alert.withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }
}
