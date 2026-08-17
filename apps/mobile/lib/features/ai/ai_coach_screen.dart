import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class AiCoachScreen extends ConsumerWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final canAsk = session.entitlements.canUse(EntitlementKeys.aiBasic);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Coach Vital',
      subtitle: 'Wellness coach grounded in your data — not a physician.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: VytalColors.teal.withValues(alpha: 0.2),
                      child: const Icon(Icons.auto_awesome, color: VytalColors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Coach Vital',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Bubble(
                  fromCoach: true,
                  text: canAsk
                      ? (session.operatingMode == OperatingMode.appOnly
                          ? 'I can use your profile and notes now. Wearable vitals will appear here only after pairing — I will never invent sensor values.'
                          : 'Connected Mode is active. I will only reference verified wearable summaries and your profile.')
                      : 'This feature requires a plan that includes AI access.',
                ),
                if (canAsk) ...[
                  const SizedBox(height: 10),
                  const _Bubble(
                    fromCoach: true,
                    text:
                        'Safety first: Vytal is not a doctor and will not invent diagnoses. Missing data is stated as missing.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: canAsk,
            decoration: InputDecoration(
              hintText: 'Ask Coach Vital…',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: const Icon(Icons.mic_none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Full conversational coaching lands in Phase 6. This UI matches the approved Coach Vital surface.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromCoach});

  final String text;
  final bool fromCoach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: fromCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fromCoach
              ? VytalColors.teal.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VytalColors.teal.withValues(alpha: 0.25),
          ),
        ),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
