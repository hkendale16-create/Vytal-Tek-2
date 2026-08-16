import 'package:flutter/material.dart';

import '../shared/ui_primitives.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionScaffold(
      title: 'Activity',
      subtitle: 'Workouts, routines, and timers work with or without a wearable.',
      child: Column(
        children: [
          EmptyMetricCard(
            title: 'Routines',
            message:
                'Custom routine builder and AI workout creation land in later phases. Phase 1 reserves this navigation destination.',
          ),
          SizedBox(height: 12),
          EmptyMetricCard(
            title: 'Timers',
            message:
                'Stopwatch, countdown, and interval timer engines are planned next. Background-safe timer behavior is required before release.',
          ),
        ],
      ),
    );
  }
}
