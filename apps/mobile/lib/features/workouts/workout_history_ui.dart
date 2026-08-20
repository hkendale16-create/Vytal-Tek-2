import 'package:flutter/material.dart';

import '../../core/time/duration_format.dart';
import '../../domain/models/workout_models.dart';
import '../../workouts/workout_gps.dart';
import '../shared/health_ui.dart';

String formatWorkoutWhen(DateTime completedAt) {
  final local = completedAt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${local.month}/${local.day}/${local.year}';
}

Future<void> showWorkoutHistoryDetail(
  BuildContext context,
  WorkoutHistoryEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text(entry.name, style: theme.textTheme.titleLarge),
              Text(
                '${entry.activityKind.label} · ${formatWorkoutWhen(entry.completedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duration', style: theme.textTheme.labelSmall),
                    Text(formatClock(entry.durationSeconds),
                        style: theme.textTheme.titleMedium),
                    if (entry.distanceMeters != null) ...[
                      const SizedBox(height: 8),
                      Text('Distance', style: theme.textTheme.labelSmall),
                      Text(formatDistanceKm(entry.distanceMeters!),
                          style: theme.textTheme.titleMedium),
                    ],
                    if (entry.trainingVolumeKg != null) ...[
                      const SizedBox(height: 8),
                      Text('Volume', style: theme.textTheme.labelSmall),
                      Text('${entry.trainingVolumeKg!.round()} kg',
                          style: theme.textTheme.titleMedium),
                    ],
                    if (entry.averageHr != null) ...[
                      const SizedBox(height: 8),
                      Text('Avg HR', style: theme.textTheme.labelSmall),
                      Text('${entry.averageHr} BPM',
                          style: theme.textTheme.titleMedium),
                    ],
                    if (entry.estimatedCalories != null) ...[
                      const SizedBox(height: 8),
                      Text('Calories (est.)',
                          style: theme.textTheme.labelSmall),
                      Text('${entry.estimatedCalories}',
                          style: theme.textTheme.titleMedium),
                    ],
                  ],
                ),
              ),
              if (entry.setLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Sets', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final log in entry.setLogs)
                  if (log.completed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(log.exerciseName),
                      subtitle: Text(
                        'Set ${log.setNumber} · ${log.setType.label}'
                        '${log.reps != null ? ' · ${log.reps} reps' : ''}'
                        '${log.weightKg != null ? ' · ${log.weightKg!.round()} kg' : ''}',
                      ),
                    ),
              ],
              if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Notes', style: theme.textTheme.titleMedium),
                Text(entry.notes!),
              ],
            ],
          );
        },
      );
    },
  );
}

class WorkoutHistoryTile extends StatelessWidget {
  const WorkoutHistoryTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final WorkoutHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: theme.textTheme.titleMedium),
                Text(
                  '${entry.activityKind.label} · ${formatClock(entry.durationSeconds)}'
                  '${entry.setLogs.isNotEmpty ? ' · ${entry.setLogs.where((l) => l.completed).length} sets' : ''}'
                  ' · ${formatWorkoutWhen(entry.completedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (entry.trainingVolumeKg != null)
                  Text(
                    'Volume ${entry.trainingVolumeKg!.round()} kg',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
