import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/entitlements.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class AiCoachScreen extends ConsumerWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final canAsk = session.entitlements.canUse(EntitlementKeys.aiBasic);

    return SectionScaffold(
      title: 'Ask Vytal',
      subtitle: 'Wellness coach grounded in your data — not a physician.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyMetricCard(
            title: 'AI Coach foundation',
            message: canAsk
                ? 'Chat and insight cards arrive in Phase 6. Context will include profile, notes, and verified wearable summaries only.'
                : 'This feature requires a plan that includes AI access.',
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Ask Vytal anything…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              suffixIcon: const Icon(Icons.mic_none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Safety: Vytal will not invent diagnoses. Missing data is stated as missing.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
