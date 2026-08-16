import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    return SectionScaffold(
      title: 'Analytics',
      subtitle: 'Trends use aggregated summaries — not every raw sample.',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: const [
              StatusPill(label: '7D'),
              StatusPill(label: '30D'),
              StatusPill(label: '90D'),
              StatusPill(label: '1Y'),
            ],
          ),
          const SizedBox(height: 16),
          EmptyMetricCard(
            title: 'No trend data yet',
            message: session.demoModeEnabled
                ? 'Demo mode is on for UI exploration. Simulated charts must stay clearly labeled Demo and are not wired in Phase 1.'
                : 'Charts appear when wearable or manual history exists. Unsupported sensors stay hidden.',
          ),
        ],
      ),
    );
  }
}
