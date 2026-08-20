import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';
import '../../fitness/calendar_controller.dart';
import '../../fitness/equipment_workout_builder.dart';
import '../../fitness/gym_discovery_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';

enum _GymViewMode { list, map }

class GymsNearMeScreen extends ConsumerStatefulWidget {
  const GymsNearMeScreen({super.key});

  @override
  ConsumerState<GymsNearMeScreen> createState() => _GymsNearMeScreenState();
}

class _GymsNearMeScreenState extends ConsumerState<GymsNearMeScreen> {
  var _mode = _GymViewMode.list;
  final _city = TextEditingController();
  GymPlace? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gymDiscoveryProvider.notifier).loadNearby();
    });
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null) {
      return GymProfileScreen(
        place: _profile!,
        onBack: () => setState(() => _profile = null),
      );
    }

    final state = ref.watch(gymDiscoveryProvider);
    final extras = context.vytalExtras;

    return SectionScaffold(
      title: 'Gyms Near Me',
      subtitle: 'Location is only used when you open this screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Row(
              children: [
                Icon(Icons.privacy_tip_outlined,
                    color: extras.textMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We request location only to find nearby facilities. '
                    'Search by city anytime if you prefer not to share it.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: extras.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VytalTabSelector<_GymViewMode>(
            values: _GymViewMode.values,
            selected: _mode,
            labelOf: (m) => m == _GymViewMode.list ? 'List' : 'Map',
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 12),
          if (state.locationDenied || state.places.isEmpty) ...[
            TextField(
              controller: _city,
              textInputAction: TextInputAction.search,
              onSubmitted: (q) =>
                  ref.read(gymDiscoveryProvider.notifier).searchCity(q),
              decoration: InputDecoration(
                labelText: 'Search city',
                hintText: 'e.g. Austin, TX',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => ref
                      .read(gymDiscoveryProvider.notifier)
                      .searchCity(_city.text),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.error != null) ...[
            Text(
              state.error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: VytalColors.caution),
            ),
            const SizedBox(height: 8),
          ],
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_mode == _GymViewMode.map)
            _GymMapViewport(
              places: state.places,
              onSelect: (place) => setState(() => _profile = place),
            )
          else if (state.places.isEmpty)
            GlassPanel(
              child: Text(
                state.locationDenied
                    ? 'Enter a city above to browse fitness facilities.'
                    : 'No gyms found yet. Try refreshing or a city search.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final place in state.places) ...[
              _GymCard(
                place: place,
                onView: () => setState(() => _profile = place),
              ),
              const SizedBox(height: 8),
            ],
          if (state.saved.isNotEmpty) ...[
            const SizedBox(height: 16),
            const VytalSectionHeader(title: 'Saved'),
            for (final saved in state.saved) ...[
              _GymCard(
                place: saved.place,
                onView: () => setState(() => _profile = saved.place),
              ),
              const SizedBox(height: 8),
            ],
          ],
          TextButton(
            onPressed: () =>
                ref.read(gymDiscoveryProvider.notifier).loadNearby(force: true),
            child: const Text('Refresh nearby'),
          ),
        ],
      ),
    );
  }
}

class _GymMapViewport extends StatelessWidget {
  const _GymMapViewport({
    required this.places,
    required this.onSelect,
  });

  final List<GymPlace> places;
  final ValueChanged<GymPlace> onSelect;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final visible = places.take(12).toList();
    if (visible.isEmpty) {
      return GlassPanel(
        child: Text(
          'No gyms to plot yet. Search by city or enable location.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GymScatterPainter(
                              places: visible,
                              pinColor: VytalColors.teal,
                              gridColor: extras.border,
                            ),
                          ),
                        ),
                        for (final place in visible) ...[
                          Builder(
                            builder: (context) {
                              final point = _GymMapViewport._normalize(
                                place,
                                visible,
                              );
                              return Positioned(
                                left: point.dx * constraints.maxWidth - 22,
                                top: point.dy * constraints.maxHeight - 22,
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  tooltip: place.name,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => onSelect(place),
                                  icon: const Icon(
                                    Icons.location_on,
                                    color: VytalColors.teal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Relative map of nearby results — tap a pin to open a gym. '
                  'No continuous tile fetch.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: extras.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final place in visible.take(4)) ...[
          _GymCard(place: place, onView: () => onSelect(place)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  static Offset _normalize(GymPlace place, List<GymPlace> all) {
    final lats = all.map((e) => e.latitude);
    final lngs = all.map((e) => e.longitude);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() < 0.0001 ? 0.01 : (maxLat - minLat);
    final lngSpan = (maxLng - minLng).abs() < 0.0001 ? 0.01 : (maxLng - minLng);
    final x = ((place.longitude - minLng) / lngSpan).clamp(0.08, 0.92);
    final y = (1 - ((place.latitude - minLat) / latSpan)).clamp(0.08, 0.92);
    return Offset(x.toDouble(), y.toDouble());
  }
}

class _GymScatterPainter extends CustomPainter {
  _GymScatterPainter({
    required this.places,
    required this.pinColor,
    required this.gridColor,
  });

  final List<GymPlace> places;
  final Color pinColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..color = pinColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _GymScatterPainter oldDelegate) =>
      oldDelegate.places != places;
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.place, required this.onView});

  final GymPlace place;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (place.distanceLabel.isNotEmpty)
                StatusPill(label: place.distanceLabel, emphasis: true),
            ],
          ),
          if (place.hoursLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              place.hoursLabel!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
          ],
          if (place.amenities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in place.amenities.take(4)) StatusPill(label: a),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onView, child: const Text('View')),
          ),
        ],
      ),
    );
  }
}

class GymProfileScreen extends ConsumerStatefulWidget {
  const GymProfileScreen({
    super.key,
    required this.place,
    required this.onBack,
  });

  final GymPlace place;
  final VoidCallback onBack;

  @override
  ConsumerState<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends ConsumerState<GymProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final discovery = ref.watch(gymDiscoveryProvider);
    final saved = discovery.saved.where((g) => g.place.id == place.id).firstOrNull;
    final extras = context.vytalExtras;

    return SectionScaffold(
      title: place.name,
      subtitle: place.type.label,
      actions: [
        IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (place.address != null) ...[
                  Text('Address', style: Theme.of(context).textTheme.labelSmall),
                  Text(place.address!, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 10),
                ],
                if (place.hoursLabel != null) ...[
                  Text('Hours', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    place.hoursLabel!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 10),
                ],
                if (place.distanceLabel.isNotEmpty)
                  StatusPill(label: place.distanceLabel, emphasis: true),
                if (place.amenities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in place.amenities) StatusPill(label: a),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openDirections(place),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Directions'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final notifier = ref.read(gymDiscoveryProvider.notifier);
              if (saved != null) {
                await notifier.unsaveGym(place.id);
              } else {
                await notifier.saveGym(place);
              }
            },
            child: Text(saved != null ? 'Saved' : 'Save'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _workoutHere(place, saved),
            child: const Text('Workout Here'),
          ),
          const SizedBox(height: 12),
          Text(
            'Equipment is never invented. Confirm what you see on the floor '
            'before filtering workouts.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(GymPlace place) async {
    final geo = Uri.parse(
      'geo:${place.latitude},${place.longitude}?q=${Uri.encodeComponent(place.name)}',
    );
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
    );
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo);
    } else {
      await launchUrl(maps, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _workoutHere(GymPlace place, SavedGym? saved) async {
    var equipment = saved?.effectiveEquipment ?? place.equipment;
    final reliable = saved?.hasReliableEquipment == true || place.equipmentKnown;
    if (!reliable) {
      final confirmed = await showModalBottomSheet<List<GymEquipmentItem>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _EquipmentChecklistSheet(
          initial: equipment,
        ),
      );
      if (confirmed == null) return;
      await ref.read(gymDiscoveryProvider.notifier).saveGym(place);
      await ref
          .read(gymDiscoveryProvider.notifier)
          .updateEquipment(place.id, confirmed);
      equipment = confirmed;
      if (!mounted) return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutHereSheet(
        gymName: place.name,
        gymId: place.id,
        equipment: equipment,
      ),
    );
  }
}

class _EquipmentChecklistSheet extends StatefulWidget {
  const _EquipmentChecklistSheet({required this.initial});

  final List<GymEquipmentItem> initial;

  @override
  State<_EquipmentChecklistSheet> createState() =>
      _EquipmentChecklistSheetState();
}

class _EquipmentChecklistSheetState extends State<_EquipmentChecklistSheet> {
  late Set<GymEquipmentItem> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final items = GymEquipmentItem.values
        .where((e) => e != GymEquipmentItem.noEquipment)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: extras.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: extras.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirm available equipment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Only mark gear you can see. This stays on your saved gym profile.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  FilterChip(
                    label: Text(item.label),
                    selected: _selected.contains(item),
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(item);
                      } else {
                        _selected.remove(item);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutHereSheet extends ConsumerStatefulWidget {
  const _WorkoutHereSheet({
    required this.gymName,
    required this.gymId,
    required this.equipment,
  });

  final String gymName;
  final String gymId;
  final List<GymEquipmentItem> equipment;

  @override
  ConsumerState<_WorkoutHereSheet> createState() => _WorkoutHereSheetState();
}

class _WorkoutHereSheetState extends ConsumerState<_WorkoutHereSheet> {
  var _duration = 45;
  var _goal = 'Full body';
  WorkoutRoutine? _routine;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final labels = EquipmentWorkoutBuilder.labelsFromItems(widget.equipment);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: extras.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: extras.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'BUILD A WORKOUT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_duration-minute $_goal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              labels.isEmpty
                  ? 'Equipment available here · not yet confirmed'
                  : 'Equipment available here · ${labels.take(5).join(' · ')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
            const SizedBox(height: 12),
            Text('Goal', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final g in ['Full body', 'Upper', 'Lower', 'Pull', 'Cardio'])
                  ChoiceChip(
                    label: Text(g),
                    selected: _goal == g,
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() {
                      _goal = g;
                      _routine = null;
                    }),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Duration'),
              subtitle: Text('$_duration min'),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: _duration.toDouble(),
                  min: 20,
                  max: 90,
                  divisions: 14,
                  onChanged: (v) => setState(() {
                    _duration = v.round();
                    _routine = null;
                  }),
                ),
              ),
            ),
            if (_routine != null) ...[
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _routine!.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    for (final ex in _routine!.exercises.take(6))
                      Text(
                        '• ${ex.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      '~${_routine!.estimatedMinutes} min · ${_routine!.exercises.length} exercises',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: extras.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final routine = _routine!;
                  await ref
                      .read(workoutLibraryProvider.notifier)
                      .addCustomRoutine(routine);
                  ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  context.push('/workouts/active');
                },
                child: const Text('Start Workout'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final routine = _routine!;
                  await ref.read(fitnessCalendarProvider.notifier).scheduleWorkout(
                        title: routine.name,
                        date: DateTime.now(),
                        kind: FitnessEventKind.scheduledWorkout,
                        durationMinutes: routine.estimatedMinutes,
                        gymId: widget.gymId,
                        routineId: routine.id,
                        notes: 'Workout Here · ${widget.gymName}',
                      );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to today’s calendar')),
                  );
                },
                child: const Text('Add to Calendar'),
              ),
            ] else
              FilledButton(
                onPressed: () {
                  setState(() {
                    _routine = EquipmentWorkoutBuilder.build(
                      minutes: _duration,
                      focus: _goal,
                      equipmentLabels: labels,
                      locationName: widget.gymName,
                    );
                  });
                },
                child: const Text('Build Workout'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullGym<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
