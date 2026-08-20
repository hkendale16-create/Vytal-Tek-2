import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../backend/supabase_config.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/ecosystem_future.dart';
import '../../domain/models/entitlements.dart';
import '../../fitness/ecosystem_controller.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import 'upgrade_prompts.dart';

/// Trainer marketplace — browse, interest, and server checkout with fee ledger.
class TrainerMarketplaceScreen extends ConsumerWidget {
  const TrainerMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(ecosystemProvider);
    final entitlements = ref.watch(appSessionProvider).entitlements;
    final signedIn = ref.watch(authUserProvider) != null;
    final extras = context.vytalExtras;
    final programs = TrainerMarketplaceCatalog.featured;

    return SectionScaffold(
      title: 'Trainer Programs',
      subtitle: 'Checkout settles platform fees on the server.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Text(
              signedIn
                  ? 'Signed in — interest and checkout sync to Vytal servers. '
                      'Paid SKUs use StoreKit/Play when console products exist; '
                      'sandbox receipts work for drills. Sponsored fees are ledgered, not silently skipped.'
                  : 'Sign in to sync interest and run checkout. Previews can still be saved on-device.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/account'),
              child: const Text('Sign in for checkout'),
            ),
          ],
          if (eco.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              eco.lastError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: VytalColors.caution),
            ),
          ],
          const SizedBox(height: 12),
          for (final program in programs) ...[
            _ProgramCard(
              program: program,
              saved: eco.savedProgramIds.contains(program.id),
              interested: eco.interestProgramIds.contains(program.id),
              purchased: eco.purchasedProgramIds.contains(program.id),
              canUseAdvanced: entitlements.canUse(EntitlementKeys.plansAdvanced),
              onSave: () =>
                  ref.read(ecosystemProvider.notifier).saveProgram(program.id),
              onInterest: () => ref
                  .read(ecosystemProvider.notifier)
                  .expressInterest(program.id),
              onCheckout: () async {
                final res = await ref
                    .read(ecosystemProvider.notifier)
                    .checkoutProgram(program.id);
                if (!context.mounted) return;
                final message = res == null
                    ? (ref.read(ecosystemProvider).lastError ??
                        'Checkout failed')
                    : (res['message'] as String? ?? 'Checkout complete');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
              onAdvancedGate: () => ContextualUpgradeSheet.show(
                context,
                title: 'Pro preview programs',
                bullets: const [
                  'Browse advanced trainer paths',
                  'Server checkout with platform fee ledger',
                  'StoreKit / Play when products are live',
                ],
                entitlementKey: EntitlementKeys.plansAdvanced,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.saved,
    required this.interested,
    required this.purchased,
    required this.canUseAdvanced,
    required this.onSave,
    required this.onInterest,
    required this.onCheckout,
    required this.onAdvancedGate,
  });

  final TrainerProgramListing program;
  final bool saved;
  final bool interested;
  final bool purchased;
  final bool canUseAdvanced;
  final VoidCallback onSave;
  final VoidCallback onInterest;
  final VoidCallback onCheckout;
  final VoidCallback onAdvancedGate;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final gated = program.advanced && !canUseAdvanced;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  program.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusPill(
                label: program.priceLabel,
                emphasis: program.advanced,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            program.trainerDisplayName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: VytalColors.teal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            program.tagline,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '${program.weeks} weeks · ${program.daysPerWeek} days/week',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (program.focusAreas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final area in program.focusAreas) StatusPill(label: area),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            program.feeNote,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: gated
                      ? onAdvancedGate
                      : saved
                          ? null
                          : onSave,
                  child: Text(saved ? 'Saved' : 'Save preview'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: gated
                      ? onAdvancedGate
                      : interested
                          ? null
                          : onInterest,
                  child:
                      Text(interested ? 'Interest noted' : 'I\'m interested'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: purchased
                ? null
                : gated
                    ? onAdvancedGate
                    : onCheckout,
            child: Text(
              purchased
                  ? 'Purchased'
                  : program.advanced
                      ? 'Checkout (sandbox / store)'
                      : 'Unlock preview',
            ),
          ),
        ],
      ),
    );
  }
}
