import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/data_provenance.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _range = '7D';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final demo = health?.provenance == DataProvenance.demo;
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Insights',
      subtitle: 'Trends use aggregated summaries — not every raw sample.',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final range in const ['7D', '30D', '90D', '1Y'])
                ChoiceChip(
                  label: Text(range),
                  selected: _range == range,
                  onSelected: (_) => setState(() => _range = range),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Heart rate trend · $_range', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: demo
                      ? CustomPaint(
                          painter: _SparklinePainter(
                            values: const [68, 72, 70, 74, 71, 69, 72],
                            color: VytalColors.teal,
                          ),
                          child: const SizedBox.expand(),
                        )
                      : Center(
                          child: Text(
                            session.demoModeEnabled
                                ? 'Pair a demo device to preview labeled trend charts.'
                                : 'Charts appear when wearable or manual history exists.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                ),
                if (demo) ...[
                  const SizedBox(height: 8),
                  const ProvenanceCaption(provenance: DataProvenance.demo),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
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
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 2;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height *
          (1 - ((values[i] - minV) / (maxV - minV)).clamp(0, 1));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
