import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/workout_models.dart';
import 'fitness_repositories.dart';

const fitnessSyncQueueKey = 'vytal.fitness.sync_queue.v1';
const fitnessSyncEndpointKey = 'vytal.fitness.sync_endpoint.v1';
const fitnessSyncTokenKey = 'vytal.fitness.sync_token.v1';

/// Local-first sync queue with optional HTTP flush.
///
/// Without a configured endpoint, [flush] keeps the queue and reports
/// [FitnessSyncFlushMode.localOnly]. With an endpoint, POSTs JSON and clears
/// only on HTTP 2xx. Failures leave the queue intact.
class LocalQueuedFitnessSyncPort implements FitnessSyncPort {
  LocalQueuedFitnessSyncPort({
    SharedPreferences? prefs,
    http.Client? httpClient,
    String? endpointUrl,
    String? authToken,
  })  : _prefs = prefs,
        _http = httpClient ?? http.Client(),
        _endpointOverride = endpointUrl,
        _authTokenOverride = authToken;

  final SharedPreferences? _prefs;
  final http.Client _http;
  String? _endpointOverride;
  final String? _authTokenOverride;

  Future<SharedPreferences> _store() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> setEndpointUrl(String? url) async {
    final prefs = await _store();
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(fitnessSyncEndpointKey);
      _endpointOverride = null;
      return;
    }
    await prefs.setString(fitnessSyncEndpointKey, trimmed);
    _endpointOverride = trimmed;
  }

  Future<String?> loadEndpointUrl() async {
    if (_endpointOverride != null && _endpointOverride!.trim().isNotEmpty) {
      return _endpointOverride!.trim();
    }
    final prefs = await _store();
    final stored = prefs.getString(fitnessSyncEndpointKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      _endpointOverride = stored;
      return stored;
    }
    return null;
  }

  Future<String?> _resolveAuthToken() async {
    if (_authTokenOverride != null && _authTokenOverride!.trim().isNotEmpty) {
      return _authTokenOverride!.trim();
    }
    final prefs = await _store();
    return prefs.getString(fitnessSyncTokenKey)?.trim();
  }

  @override
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry) async {
    final prefs = await _store();
    final raw = prefs.getString(fitnessSyncQueueKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        list.addAll(
          (jsonDecode(raw) as List).cast<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ),
        );
      } catch (_) {
        // Reset corrupt queue.
      }
    }
    list.removeWhere((e) => e['id'] == entry.id);
    list.add({
      'id': entry.id,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
      'kind': 'workout_completed',
      'payload': entry.toJson(),
    });
    // Cap queue so offline devices don't grow unbounded.
    final trimmed = list.length > 100 ? list.sublist(list.length - 100) : list;
    await prefs.setString(fitnessSyncQueueKey, jsonEncode(trimmed));
  }

  Future<List<Map<String, dynamic>>> peek() async {
    final prefs = await _store();
    final raw = prefs.getString(fitnessSyncQueueKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<int> pendingCount() async {
    return (await peek()).length;
  }

  @override
  Future<FitnessSyncFlushResult> flush() async {
    final prefs = await _store();
    final events = await peek();
    if (events.isEmpty) {
      final endpoint = await loadEndpointUrl();
      return FitnessSyncFlushResult(
        flushedCount: 0,
        remainingCount: 0,
        mode: endpoint == null
            ? FitnessSyncFlushMode.localOnly
            : FitnessSyncFlushMode.remoteOk,
        message: 'Queue empty',
      );
    }

    final endpoint = await loadEndpointUrl();
    if (endpoint == null) {
      return FitnessSyncFlushResult(
        flushedCount: 0,
        remainingCount: events.length,
        mode: FitnessSyncFlushMode.localOnly,
        message:
            'No sync endpoint configured. Events stay on-device until you add one in Settings.',
      );
    }

    try {
      final uri = Uri.parse(endpoint);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final token = await _resolveAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'source': 'vytal_tek_mobile',
          'eventCount': events.length,
          'events': events,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(fitnessSyncQueueKey, jsonEncode(const <Object>[]));
        return FitnessSyncFlushResult(
          flushedCount: events.length,
          remainingCount: 0,
          mode: FitnessSyncFlushMode.remoteOk,
          message: 'Synced ${events.length} event(s)',
        );
      }

      return FitnessSyncFlushResult(
        flushedCount: 0,
        remainingCount: events.length,
        mode: FitnessSyncFlushMode.remoteFailed,
        message: 'Sync failed (${response.statusCode}). Queue kept locally.',
      );
    } catch (e) {
      return FitnessSyncFlushResult(
        flushedCount: 0,
        remainingCount: events.length,
        mode: FitnessSyncFlushMode.remoteFailed,
        message: 'Sync error: $e. Queue kept locally.',
      );
    }
  }

  /// Test helper: clear queue without network.
  Future<void> clearQueueForTests() async {
    final prefs = await _store();
    await prefs.setString(fitnessSyncQueueKey, jsonEncode(const <Object>[]));
  }
}
