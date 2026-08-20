import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import 'coach_chat_controller.dart';
import 'coach_vital_engine.dart';

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  var _lastPrompt = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prompt = GoRouterState.of(context).uri.queryParameters['prompt'];
    if (prompt != null && prompt.trim().isNotEmpty && prompt != _lastPrompt) {
      _lastPrompt = prompt;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _controller.text = prompt;
        await _send();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    _controller.clear();
    await ref.read(coachChatProvider.notifier).send(text);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final chat = ref.watch(coachChatProvider);
    final canAsk = session.entitlements.canUse(EntitlementKeys.aiBasic);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Coach',
      subtitle: 'Useful with or without a wearable — never invents vitals.',
      actions: [
        IconButton(
          tooltip: 'Clear chat',
          onPressed: canAsk
              ? () => ref.read(coachChatProvider.notifier).clear()
              : null,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              height: 360,
              child: ListView.builder(
                controller: _scroll,
                itemCount: chat.messages.length + (chat.isThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= chat.messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: _Bubble(
                        fromCoach: true,
                        text: 'Thinking…',
                      ),
                    );
                  }
                  final message = chat.messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Bubble(
                      fromCoach: message.fromCoach,
                      text: message.text,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in CoachVitalEngine.suggestedPrompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: !canAsk || chat.isThinking
                      ? null
                      : () async {
                          _controller.text = prompt;
                          await _send();
                        },
                ),
            ],
          ),
          if (chat.generatedWorkout != null) ...[
            const SizedBox(height: 12),
            _GeneratedWorkoutCard(routine: chat.generatedWorkout!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: canAsk && !chat.isThinking,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: canAsk
                        ? 'Ask Coach Vital…'
                        : 'AI access required',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canAsk && !chat.isThinking ? _send : null,
                child: const Icon(Icons.send_rounded),
              ),
            ],
          ),
          if (!canAsk) ...[
            const SizedBox(height: 12),
            const SoftPaywall(
              entitlementKey: EntitlementKeys.aiBasic,
              compact: true,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Coach Vital never invents wearable readings and will not diagnose.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const EntitlementGate(
            entitlementKey: EntitlementKeys.aiAdvanced,
            compactPaywall: true,
            child: GlassPanel(
              child: Text(
                'Adaptive coaching is on — recovery-aware planning uses verified wearable context when present.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedWorkoutCard extends ConsumerWidget {
  const _GeneratedWorkoutCard({required this.routine});

  final WorkoutRoutine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(routine.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < routine.exercises.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${i + 1}. ${routine.exercises[i].name}  '
                '${routine.exercises[i].sets} × '
                '${routine.exercises[i].reps ?? '${routine.exercises[i].durationSeconds}s'}',
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                  context.push('/workouts/active');
                },
                child: const Text('Start Workout'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final saved = await ref
                      .read(workoutLibraryProvider.notifier)
                      .addCustomRoutine(routine.copyWith(source: 'ai'));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        saved == null
                            ? 'Custom routines need workouts.custom.'
                            : 'Saved to My Routines.',
                      ),
                    ),
                  );
                },
                child: const Text('Save Routine'),
              ),
              OutlinedButton(
                onPressed: () {
                  ref.read(pendingRoutineDraftProvider.notifier).state = routine;
                  context.push('/workouts/builder');
                },
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(coachChatProvider.notifier).regenerateWorkout(),
                child: const Text('Regenerate'),
              ),
            ],
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
