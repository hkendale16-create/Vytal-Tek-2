import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';
import '../../fitness/progress_analytics.dart';
import '../../fitness/progress_photo_capture.dart';
import '../../fitness/repositories/local_fitness_store.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';
import 'upgrade_prompts.dart';

final progressPhotosProvider =
    StateNotifierProvider<ProgressPhotosController, List<ProgressPhoto>>((ref) {
  return ProgressPhotosController(ref)..restore();
});

class ProgressPhotosController extends StateNotifier<List<ProgressPhoto>> {
  ProgressPhotosController(this._ref) : super(const []);

  final Ref _ref;
  final _uuid = const Uuid();

  Future<void> restore() async {
    state = await _ref.read(progressPhotoRepositoryProvider).load();
  }

  Future<void> addEntry({
    required String angle,
    double? weightKg,
    String? notes,
    String? localPath,
  }) async {
    final entry = ProgressPhoto(
      id: _uuid.v4(),
      capturedAt: DateTime.now().toUtc(),
      localPath: localPath ?? 'on-device://note/${_uuid.v4()}',
      angle: angle,
      weightKg: weightKg,
      notes: notes,
    );
    state = [entry, ...state];
    await _ref.read(progressPhotoRepositoryProvider).save(state);
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _ref.read(progressPhotoRepositoryProvider).save(state);
  }
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  var _range = ProgressRange.d30;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider).entries;
    final snapshot = ProgressAnalytics.build(history: history, range: _range);
    final photos = ref.watch(progressPhotosProvider);
    final extras = context.vytalExtras;

    return SectionScaffold(
      title: 'Progress',
      subtitle: 'Training trends from your logged sessions.',
      actions: [
        IconButton(
          tooltip: 'History',
          onPressed: () => context.push('/workouts/history'),
          icon: const Icon(Icons.history),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VytalTabSelector<ProgressRange>(
            values: ProgressRange.values,
            selected: _range,
            labelOf: (r) => r.label,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(title: 'Training'),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Workouts',
                  value: '${snapshot.workouts}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Time',
                  value: snapshot.trainingTimeLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Volume',
                  value: snapshot.volumeLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ref
              .watch(appSessionProvider)
              .entitlements
              .canUse(EntitlementKeys.progressAdvanced))
            _AdvancedTrendPanel(history: history)
          else
            const ProPreviewCard(
              title: 'Advanced Progress',
              subtitle:
                  '12-week strength trends, comparisons, and deeper volume analysis.',
              previewLabel: '12-Week Strength Trend · preview',
            ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Strength',
            subtitle: 'Top lift changes from your history.',
          ),
          if (snapshot.strengthDeltas.isEmpty)
            GlassPanel(
              child: Text(
                'Log weighted sets to see lift deltas here.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: extras.textMuted),
              ),
            )
          else
            for (final pr in snapshot.strengthDeltas.take(5)) ...[
              GlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pr.exerciseName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${pr.weightKg.toStringAsFixed(0)} kg',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: VytalColors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (pr.deltaKg != null) ...[
                      const SizedBox(width: 8),
                      StatusPill(
                        label:
                            '${pr.deltaKg! >= 0 ? '+' : ''}${pr.deltaKg!.toStringAsFixed(1)}',
                        emphasis: pr.deltaKg! > 0,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          DeviceFunnelCard(completedWorkouts: history.length),
          const SizedBox(height: 8),
          const VytalSectionHeader(title: 'Consistency'),
          GlassPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workouts / week',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: extras.textMuted),
                      ),
                      Text(
                        snapshot.workoutsPerWeek.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: '${snapshot.streakDays} day streak',
                  emphasis: snapshot.streakDays > 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HudStrip(
            icon: Icons.history,
            title: 'Workout history',
            subtitle: 'Open full session log',
            onTap: () => context.push('/workouts/history'),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Progress photos',
            subtitle: 'Private — files stay on this device.',
          ),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Optional check-ins stay local. You can attach a camera or '
                  'gallery photo, or log metadata only.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: extras.textMuted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _logPhotoEntry(context),
                  child: const Text('Add progress photo'),
                ),
              ],
            ),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final photo in photos) ...[
              GlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasImageFile(photo.localPath)) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.file(
                            File(photo.localPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 120,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        StatusPill(label: photo.angle, emphasis: true),
                        const Spacer(),
                        Text(
                          _formatDate(photo.capturedAt.toLocal()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: extras.textMuted),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => ref
                              .read(progressPhotosProvider.notifier)
                              .remove(photo.id),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                    if (photo.weightKg != null) ...[
                      const SizedBox(height: 6),
                      Text('${photo.weightKg!.toStringAsFixed(1)} kg'),
                    ],
                    if (photo.notes != null && photo.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        photo.notes!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 12),
          const DeviceFunnelCard(),
        ],
      ),
    );
  }

  bool _hasImageFile(String path) {
    if (kIsWeb || path.isEmpty || path.startsWith('on-device://')) {
      return false;
    }
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _logPhotoEntry(BuildContext context) async {
    var angle = 'front';
    final weight = TextEditingController();
    final notes = TextEditingController();
    String? localPath;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final extras = context.vytalExtras;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: extras.elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: extras.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add progress photo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final a in ['front', 'side', 'back'])
                        ChoiceChip(
                          label: Text(a),
                          selected: angle == a,
                          showCheckmark: false,
                          selectedColor:
                              VytalColors.teal.withValues(alpha: 0.16),
                          onSelected: (_) => setModal(() => angle = a),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final path = await ProgressPhotoCapture.pickAndStore(
                              source: ImageSource.camera,
                            );
                            if (path != null) {
                              setModal(() => localPath = path);
                            }
                          },
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final path = await ProgressPhotoCapture.pickAndStore(
                              source: ImageSource.gallery,
                            );
                            if (path != null) {
                              setModal(() => localPath = path);
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (localPath != null) ...[
                    const SizedBox(height: 8),
                    StatusPill(label: 'Photo attached', emphasis: true),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg, optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved != true) return;
    await ref.read(progressPhotosProvider.notifier).addEntry(
          angle: angle,
          weightKg: double.tryParse(weight.text.trim()),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          localPath: localPath,
        );
    weight.dispose();
    notes.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AdvancedTrendPanel extends StatelessWidget {
  const _AdvancedTrendPanel({required this.history});

  final List<WorkoutHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final now = DateTime.now();
    final weeks = <double>[];
    for (var w = 11; w >= 0; w--) {
      final end = now.subtract(Duration(days: w * 7));
      final start = end.subtract(const Duration(days: 7));
      final volume = history
          .where(
            (e) =>
                e.completedAt.toLocal().isAfter(start) &&
                !e.completedAt.toLocal().isAfter(end),
          )
          .fold<double>(0, (sum, e) => sum + (e.trainingVolumeKg ?? 0));
      weeks.add(volume);
    }
    final max = weeks.fold<double>(0, (m, v) => v > m ? v : m);

    return GlassPanel(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '12-WEEK VOLUME',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: VytalColors.teal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Weekly training volume from your logged sets (Pro).',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in weeks) ...[
                  Expanded(
                    child: Container(
                      height: max <= 0 ? 4 : (8 + (v / max) * 64).clamp(4, 72),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: VytalColors.teal.withValues(
                          alpha: v <= 0 ? 0.2 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
