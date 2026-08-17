import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/workout_models.dart';
import '../../workouts/exercise_library.dart';
import '../../workouts/workout_controllers.dart';
import '../ai/coach_chat_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class MuscleGroupPickerScreen extends ConsumerWidget {
  const MuscleGroupPickerScreen({super.key, this.groupName});

  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MuscleGroup? group = () {
      for (final item in MuscleGroup.values) {
        if (item.name == groupName) return item;
      }
      return null;
    }();
    if (group != null) {
      return _MuscleExercisesScreen(group: group);
    }
    return SectionScaffold(
      title: 'Choose Muscle Group',
      subtitle: 'Pick a region, then build a session or ask Vytal.',
      child: Column(
        children: [
          for (final item in MuscleGroup.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HudStrip(
                icon: Icons.fitness_center,
                title: item.label,
                subtitle:
                    '${ExerciseLibrary.forGroup(item).length} exercises',
                onTap: () => context.push('/workouts/muscles?group=${item.name}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MuscleExercisesScreen extends ConsumerStatefulWidget {
  const _MuscleExercisesScreen({required this.group});

  final MuscleGroup group;

  @override
  ConsumerState<_MuscleExercisesScreen> createState() =>
      _MuscleExercisesScreenState();
}

class _MuscleExercisesScreenState
    extends ConsumerState<_MuscleExercisesScreen> {
  final _selected = <String>{};

  List<ExerciseDefinition> get _items =>
      ExerciseLibrary.forGroup(widget.group);

  Future<void> _startSelected() async {
    final picked = _items.where((e) => _selected.contains(e.name)).toList();
    if (picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one exercise.')),
      );
      return;
    }
    ref.read(workoutSessionProvider.notifier).startStrengthDraft(
          name: '${widget.group.label} session',
        );
    for (final def in picked) {
      ref.read(workoutSessionProvider.notifier).addExerciseToSession(
            def.toExercise(),
          );
    }
    if (mounted) context.push('/workouts/active');
  }

  Future<void> _saveRoutine() async {
    final picked = _items.where((e) => _selected.contains(e.name)).toList();
    if (picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one exercise.')),
      );
      return;
    }
    final nameController = TextEditingController(
      text: '${widget.group.label} routine',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as routine'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Routine name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return;
    final saved = await ref.read(workoutLibraryProvider.notifier).addCustomRoutine(
          WorkoutRoutine(
            id: '',
            name: name.isEmpty ? '${widget.group.label} routine' : name,
            exercises: picked.map((e) => e.toExercise()).toList(),
            activityKind: WorkoutActivityKind.strength,
            source: 'user',
          ),
        );
    if (!mounted) return;
    if (saved == null) {
      context.push('/settings/subscription');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to My Routines.')),
    );
  }

  Future<void> _askVytal() async {
    var minutes = 40;
    final confirmed = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${widget.group.label} workout'),
          content: StatefulBuilder(
            builder: (context, setDialog) {
              return Row(
                children: [
                  const Text('Minutes'),
                  IconButton(
                    onPressed: () => setDialog(() => minutes = (minutes - 5).clamp(15, 90)),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$minutes'),
                  IconButton(
                    onPressed: () => setDialog(() => minutes = (minutes + 5).clamp(15, 90)),
                    icon: const Icon(Icons.add),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, minutes),
              child: const Text('Ask Vytal'),
            ),
          ],
        );
      },
    );
    if (confirmed == null || !mounted) return;
    await ref.read(coachChatProvider.notifier).send(
          'Build me a $confirmed-minute ${widget.group.label.toLowerCase()} workout.',
        );
    if (mounted) context.go('/ask');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionScaffold(
      title: widget.group.label,
      subtitle: 'Choose exercises, start now, or ask Vytal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in _items)
            CheckboxListTile(
              value: _selected.contains(item.name),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(item.name);
                  } else {
                    _selected.remove(item.name);
                  }
                });
              },
              title: Text(item.name),
              subtitle: Text(
                '${item.equipment} · ${item.defaultSets} sets'
                '${item.defaultReps != null ? ' × ${item.defaultReps}' : ''}',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _startSelected,
            child: const Text('Start session'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saveRoutine,
            child: const Text('Save as routine'),
          ),
          TextButton(
            onPressed: _askVytal,
            child: Text(
              'Ask Vytal to build a ${widget.group.label.toLowerCase()} workout',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
