import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../domain/models/fitness_hub_models.dart';
import 'repositories/fitness_repositories.dart';
import 'repositories/local_fitness_store.dart';

/// OpenStreetMap Overpass provider — no API key. Cached + radius-limited.
class OverpassGymDiscoveryRepository implements GymDiscoveryRepository {
  OverpassGymDiscoveryRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final _uuid = const Uuid();

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  @override
  Future<List<GymPlace>> nearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
  }) async {
    final roundedLat = (latitude * 100).round() / 100;
    final roundedLng = (longitude * 100).round() / 100;
    final cacheKey =
        'n:${roundedLat.toStringAsFixed(2)},${roundedLng.toStringAsFixed(2)},${radiusMeters.round()}';
    final cached = await GymQueryCache.read(cacheKey: cacheKey);
    if (cached != null) return cached;

    final query = '''
[out:json][timeout:20];
(
  node["leisure"="fitness_centre"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="sports_centre"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="gym"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="fitness_centre"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="sports_centre"](around:$radiusMeters,$latitude,$longitude);
);
out center 40;
''';

    try {
      final response = await _client.post(
        Uri.parse(_endpoint),
        body: {'data': query},
      ).timeout(const Duration(seconds: 22));
      if (response.statusCode != 200) {
        return _demoNear(latitude, longitude);
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (decoded['elements'] as List?) ?? const [];
      final places = <GymPlace>[];
      for (final raw in elements) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final tags = Map<String, dynamic>.from(
          (map['tags'] as Map?) ?? const {},
        );
        final lat = (map['lat'] as num?)?.toDouble() ??
            (map['center'] is Map
                ? (map['center']['lat'] as num?)?.toDouble()
                : null);
        final lon = (map['lon'] as num?)?.toDouble() ??
            (map['center'] is Map
                ? (map['center']['lon'] as num?)?.toDouble()
                : null);
        if (lat == null || lon == null) continue;
        final name = (tags['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        places.add(
          GymPlace(
            id: 'osm-${map['type']}-${map['id']}',
            name: name,
            latitude: lat,
            longitude: lon,
            type: _inferType(tags),
            address: _address(tags),
            distanceMeters: _haversine(latitude, longitude, lat, lon),
            phone: tags['phone'] as String?,
            website: tags['website'] as String? ?? tags['contact:website'] as String?,
            amenities: _amenities(tags),
            equipmentKnown: false,
          ),
        );
      }
      places.sort(
        (a, b) => (a.distanceMeters ?? 1e9).compareTo(b.distanceMeters ?? 1e9),
      );
      final result = places.take(40).toList();
      if (result.isEmpty) {
        final demo = _demoNear(latitude, longitude);
        await GymQueryCache.write(cacheKey, demo);
        return demo;
      }
      await GymQueryCache.write(cacheKey, result);
      return result;
    } catch (_) {
      return _demoNear(latitude, longitude);
    }
  }

  @override
  Future<List<GymPlace>> searchCity(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final cacheKey = 'c:${q.toLowerCase()}';
    final cached = await GymQueryCache.read(cacheKey: cacheKey);
    if (cached != null) return cached;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '1',
      });
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'VytalTek/1.0 (fitness hub)'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return _demoSearch(q);
      final list = jsonDecode(response.body) as List;
      if (list.isEmpty) return _demoSearch(q);
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '') ?? 0;
      final lon = double.tryParse(first['lon']?.toString() ?? '') ?? 0;
      final places = await nearby(latitude: lat, longitude: lon);
      await GymQueryCache.write(cacheKey, places);
      return places;
    } catch (_) {
      return _demoSearch(q);
    }
  }

  GymType _inferType(Map<String, dynamic> tags) {
    final sport = '${tags['sport'] ?? ''}'.toLowerCase();
    final name = '${tags['name'] ?? ''}'.toLowerCase();
    if (sport.contains('climbing') || name.contains('climb')) {
      return GymType.climbing;
    }
    if (sport.contains('boxing') ||
        sport.contains('mma') ||
        name.contains('boxing') ||
        name.contains('mma')) {
      return GymType.boxingMma;
    }
    if (name.contains('crossfit')) return GymType.crossfit;
    if (tags['leisure'] == 'sports_centre') return GymType.recreation;
    return GymType.fitnessCenter;
  }

  String? _address(Map<String, dynamic> tags) {
    final street = tags['addr:street'];
    final num = tags['addr:housenumber'];
    final city = tags['addr:city'];
    final parts = <String>[
      if (num != null && street != null) '$num $street',
      if (num == null && street != null) '$street',
      if (city != null) '$city',
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  List<String> _amenities(Map<String, dynamic> tags) {
    final out = <String>[];
    if (tags['wheelchair'] == 'yes') out.add('Wheelchair access');
    if (tags['changing_table'] == 'yes') out.add('Changing room');
    if (tags['shower'] == 'yes') out.add('Showers');
    return out;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  List<GymPlace> _demoNear(double lat, double lng) {
    return [
      GymPlace(
        id: 'demo-strength-${_uuid.v4().substring(0, 8)}',
        name: 'Neighborhood Strength Club',
        latitude: lat + 0.008,
        longitude: lng + 0.004,
        type: GymType.independent,
        address: 'Near you (sample)',
        distanceMeters: 1100,
        hoursLabel: 'Open until 10 PM',
        amenities: const ['Strength', 'Cardio', 'Free Weights'],
        equipmentKnown: false,
      ),
      GymPlace(
        id: 'demo-fit-${_uuid.v4().substring(0, 8)}',
        name: 'City Fitness Center',
        latitude: lat - 0.006,
        longitude: lng + 0.01,
        type: GymType.commercial,
        address: 'Near you (sample)',
        distanceMeters: 2200,
        hoursLabel: 'Open until 11 PM',
        amenities: const ['Strength', 'Cardio', 'Classes'],
        equipmentKnown: false,
      ),
      GymPlace(
        id: 'demo-climb-${_uuid.v4().substring(0, 8)}',
        name: 'Vertical Climbing Hall',
        latitude: lat + 0.012,
        longitude: lng - 0.007,
        type: GymType.climbing,
        distanceMeters: 2800,
        hoursLabel: 'Open until 9 PM',
        amenities: const ['Climbing', 'Training'],
        equipmentKnown: false,
      ),
    ];
  }

  List<GymPlace> _demoSearch(String query) {
    return [
      GymPlace(
        id: 'demo-search-1',
        name: 'Fitness Hub — $query',
        latitude: 0,
        longitude: 0,
        type: GymType.fitnessCenter,
        address: query,
        hoursLabel: 'Hours vary',
        amenities: const ['Strength', 'Cardio'],
        equipmentKnown: false,
      ),
    ];
  }
}

class GymDiscoveryState {
  const GymDiscoveryState({
    this.places = const [],
    this.saved = const [],
    this.loading = false,
    this.error,
    this.locationDenied = false,
    this.manualQuery,
    this.lastLat,
    this.lastLng,
  });

  final List<GymPlace> places;
  final List<SavedGym> saved;
  final bool loading;
  final String? error;
  final bool locationDenied;
  final String? manualQuery;
  final double? lastLat;
  final double? lastLng;

  GymDiscoveryState copyWith({
    List<GymPlace>? places,
    List<SavedGym>? saved,
    bool? loading,
    String? error,
    bool? locationDenied,
    String? manualQuery,
    double? lastLat,
    double? lastLng,
    bool clearError = false,
  }) {
    return GymDiscoveryState(
      places: places ?? this.places,
      saved: saved ?? this.saved,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      locationDenied: locationDenied ?? this.locationDenied,
      manualQuery: manualQuery ?? this.manualQuery,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
    );
  }
}

final gymDiscoveryRepositoryProvider = Provider<GymDiscoveryRepository>((ref) {
  return OverpassGymDiscoveryRepository();
});

final gymDiscoveryProvider =
    StateNotifierProvider<GymDiscoveryController, GymDiscoveryState>((ref) {
  return GymDiscoveryController(ref)..restoreSaved();
});

class GymDiscoveryController extends StateNotifier<GymDiscoveryState> {
  GymDiscoveryController(this._ref) : super(const GymDiscoveryState());

  final Ref _ref;
  DateTime? _lastFetchAt;

  GymDiscoveryRepository get _discovery =>
      _ref.read(gymDiscoveryRepositoryProvider);
  SavedGymRepository get _savedRepo => _ref.read(savedGymRepositoryProvider);

  Future<void> restoreSaved() async {
    final saved = await _savedRepo.load();
    state = state.copyWith(saved: saved);
  }

  /// Request location only when user opens gym discovery.
  Future<void> loadNearby({bool force = false}) async {
    if (!force &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < const Duration(seconds: 8)) {
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    final permission = await Geolocator.checkPermission();
    var perm = permission;
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      state = state.copyWith(
        loading: false,
        locationDenied: true,
        error:
            'Location is optional. Search another city, or enable location for nearby gyms.',
      );
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      // Debounce slight map moves — round to ~1km grid.
      if (!force &&
          state.lastLat != null &&
          state.lastLng != null &&
          _haversine(
                state.lastLat!,
                state.lastLng!,
                position.latitude,
                position.longitude,
              ) <
              400) {
        state = state.copyWith(loading: false);
        return;
      }
      final places = await _discovery.nearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _lastFetchAt = DateTime.now();
      state = state.copyWith(
        places: places,
        loading: false,
        locationDenied: false,
        lastLat: position.latitude,
        lastLng: position.longitude,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load nearby gyms. Try a city search.',
      );
    }
  }

  Future<void> searchCity(String query) async {
    state = state.copyWith(loading: true, manualQuery: query, clearError: true);
    try {
      final places = await _discovery.searchCity(query);
      state = state.copyWith(places: places, loading: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'City search failed. Try again.',
      );
    }
  }

  Future<void> saveGym(GymPlace place) async {
    final next = [
      ...state.saved.where((g) => g.place.id != place.id),
      SavedGym(place: place, savedAt: DateTime.now().toUtc()),
    ];
    state = state.copyWith(saved: next);
    await _savedRepo.save(next);
  }

  Future<void> unsaveGym(String placeId) async {
    final next = state.saved.where((g) => g.place.id != placeId).toList();
    state = state.copyWith(saved: next);
    await _savedRepo.save(next);
  }

  Future<void> updateEquipment(
    String placeId,
    List<GymEquipmentItem> equipment,
  ) async {
    final next = state.saved.map((g) {
      if (g.place.id != placeId) return g;
      return SavedGym(
        place: g.place,
        savedAt: g.savedAt,
        userEquipment: equipment,
        favorite: g.favorite,
      );
    }).toList();
    state = state.copyWith(saved: next);
    await _savedRepo.save(next);
  }

  SavedGym? savedFor(String placeId) {
    for (final g in state.saved) {
      if (g.place.id == placeId) return g;
    }
    return null;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

final homeGymProvider =
    StateNotifierProvider<HomeGymController, HomeGymProfile>((ref) {
  return HomeGymController(ref)..restore();
});

class HomeGymController extends StateNotifier<HomeGymProfile> {
  HomeGymController(this._ref) : super(const HomeGymProfile());

  final Ref _ref;

  Future<void> restore() async {
    state = await _ref.read(homeGymRepositoryProvider).load();
  }

  Future<void> setEquipment(List<GymEquipmentItem> equipment) async {
    state = HomeGymProfile(equipment: equipment);
    await _ref.read(homeGymRepositoryProvider).save(state);
  }

  Future<void> toggle(GymEquipmentItem item) async {
    final next = [...state.equipment];
    if (next.contains(item)) {
      next.remove(item);
    } else {
      next.add(item);
    }
    await setEquipment(next);
  }
}
