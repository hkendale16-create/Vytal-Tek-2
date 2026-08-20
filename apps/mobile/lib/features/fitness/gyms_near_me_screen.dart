import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../fitness/gym_discovery_controller.dart';
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
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'List view preferred — map tiles coming',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Showing the same nearby results without an embedded map.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: extras.textMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final place in state.places.take(6)) ...[
                    _GymCard(
                      place: place,
                      onView: () => setState(() => _profile = place),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
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
    final reliable = saved?.hasReliableEquipment == true || place.equipmentKnown;
    if (!reliable) {
      final confirmed = await showModalBottomSheet<List<GymEquipmentItem>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _EquipmentChecklistSheet(
          initial: saved?.effectiveEquipment ?? place.equipment,
        ),
      );
      if (confirmed == null) return;
      await ref.read(gymDiscoveryProvider.notifier).saveGym(place);
      await ref
          .read(gymDiscoveryProvider.notifier)
          .updateEquipment(place.id, confirmed);
      if (!mounted) return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutHereSheet(gymName: place.name),
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

class _WorkoutHereSheet extends StatefulWidget {
  const _WorkoutHereSheet({required this.gymName});

  final String gymName;

  @override
  State<_WorkoutHereSheet> createState() => _WorkoutHereSheetState();
}

class _WorkoutHereSheetState extends State<_WorkoutHereSheet> {
  var _duration = 45;
  var _goal = 'Full body';

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
            'Workout at ${widget.gymName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text('Goal', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in ['Full body', 'Upper', 'Lower', 'Cardio'])
                ChoiceChip(
                  label: Text(g),
                  selected: _goal == g,
                  showCheckmark: false,
                  selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                  onSelected: (_) => setState(() => _goal = g),
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
                onChanged: (v) => setState(() => _duration = v.round()),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/workouts/builder');
            },
            child: const Text('Open workout builder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
        ],
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
