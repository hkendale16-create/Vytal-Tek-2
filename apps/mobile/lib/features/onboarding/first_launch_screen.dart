import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class FirstLaunchScreen extends ConsumerWidget {
  const FirstLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandMark(),
                      const SizedBox(height: 28),
                      Text(
                        'Live Health. Real Feedback. Stronger You.',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'LIVE BETTER. BECOME STRONGER. EVERY DAY.',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: VytalColors.teal,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vytal Tek is a personal health and performance platform. '
                        'You can start today — a wearable makes it smarter later.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Do you already have a Vytal Tek device?',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _ChoiceCard(
                        title: DeviceArrivalChoice.alreadyHaveDevice.label,
                        subtitle:
                            'Continue into the app, then connect when ready.',
                        onTap: () => ref
                            .read(appSessionProvider.notifier)
                            .completeFirstLaunch(
                              DeviceArrivalChoice.alreadyHaveDevice,
                            ),
                      ),
                      _ChoiceCard(
                        title: DeviceArrivalChoice.deviceOnTheWay.label,
                        subtitle:
                            'Use App-Only Mode until it arrives. Your profile stays.',
                        onTap: () => ref
                            .read(appSessionProvider.notifier)
                            .completeFirstLaunch(
                              DeviceArrivalChoice.deviceOnTheWay,
                            ),
                      ),
                      _ChoiceCard(
                        title: DeviceArrivalChoice.appWithoutDevice.label,
                        subtitle:
                            'AI coaching, routines, timers, notes, and goals are available now.',
                        onTap: () => ref
                            .read(appSessionProvider.notifier)
                            .completeFirstLaunch(
                              DeviceArrivalChoice.appWithoutDevice,
                            ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      Text(
                        'No pressure to pair hardware. App-Only and Connected Mode share one account.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: VytalColors.teal.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
