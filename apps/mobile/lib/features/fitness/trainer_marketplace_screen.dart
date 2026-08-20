import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/ecosystem_future.dart';
import '../../domain/models/entitlements.dart';
import '../../fitness/ecosystem_controller.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';
import 'upgrade_prompts.dart';

/// Browse trainer programs — local catalog, no live payments.
class TrainerMarketplaceScreen extends ConsumerWidget {
  const TrainerMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(ecosystemProvider);
    final entitlements = ref.watch(appSessionProvider).entitlements;
    final extras = context.vytalExtras;
    final programs = TrainerMarketplaceCatalog.featured;

    return SectionScaffold(
      title: 'Trainer Programs',
      subtitle: 'Browse previews — fees are not charged in this build.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Text(
              'Marketplace browse only. Saving a program or expressing interest '
              'stays on this device. Platform fees are reserved in the listing '
              'metadata and are never charged here.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          if (eco.savedProgramIds.isNotEmpty) ...[
            VytalSectionHeader(
              title: 'Saved',
              subtitle: '${eco.savedProgramIds.length} on this device',
            ),
            const SizedBox(height: 8),
          ],
          for (final program in programs) ...[
            _ProgramCard(
              program: program,
              saved: eco.savedProgramIds.contains(program.id),
              interested: eco.interestProgramIds.contains(program.id),
              canUseAdvanced: entitlements.canUse(EntitlementKeys.plansAdvanced),
              onSave: () =>
                  ref.read(ecosystemProvider.notifier).saveProgram(program.id),
              onInterest: () => ref
                  .read(ecosystemProvider.notifier)
                  .expressInterest(program.id),
              onAdvancedGate: () => ContextualUpgradeSheet.show(
                context,
                title: 'Pro preview programs',
                bullets: const [
                  'Browse advanced trainer paths',
                  'Save and track interest locally',
                  'Payments stay off until account checkout',
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
    required this.canUseAdvanced,
    required this.onSave,
    required this.onInterest,
    required this.onAdvancedGate,
  });

  final TrainerProgramListing program;
  final bool saved;
  final bool interested;
  final bool canUseAdvanced;
  final VoidCallback onSave;
  final VoidCallback onInterest;
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
                for (final area in program.focusAreas)
                  StatusPill(label: area),
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
                  child: Text(interested ? 'Interest noted' : 'I\'m interested'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
