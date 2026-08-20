import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';

/// Backend-portable calendar store. UI never talks to SharedPreferences directly.
abstract class FitnessCalendarRepository {
  Future<List<FitnessCalendarEvent>> loadEvents();
  Future<void> saveEvents(List<FitnessCalendarEvent> events);
}

/// Gym discovery provider — Overpass, Places, or demo.
abstract class GymDiscoveryRepository {
  Future<List<GymPlace>> nearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
  });

  Future<List<GymPlace>> searchCity(String query);
}

/// Saved gyms + user equipment profiles.
abstract class SavedGymRepository {
  Future<List<SavedGym>> load();
  Future<void> save(List<SavedGym> gyms);
}

abstract class HomeGymRepository {
  Future<HomeGymProfile> load();
  Future<void> save(HomeGymProfile profile);
}

abstract class PlanEnrollmentRepository {
  Future<List<PlanEnrollment>> load();
  Future<void> save(List<PlanEnrollment> enrollments);
}

abstract class ProgressPhotoRepository {
  Future<List<ProgressPhoto>> load();
  Future<void> save(List<ProgressPhoto> photos);
}

/// Result of attempting to flush the outbound fitness sync queue.
class FitnessSyncFlushResult {
  const FitnessSyncFlushResult({
    required this.flushedCount,
    required this.remainingCount,
    required this.mode,
    this.message,
  });

  final int flushedCount;
  final int remainingCount;
  final FitnessSyncFlushMode mode;
  final String? message;

  bool get isRemoteSuccess => mode == FitnessSyncFlushMode.remoteOk;
}

enum FitnessSyncFlushMode {
  /// No endpoint configured — queue kept on-device.
  localOnly,

  /// POST succeeded; flushed items cleared.
  remoteOk,

  /// POST failed; queue unchanged.
  remoteFailed,
}

/// Sync hook for AWS / cloud providers.
///
/// Implementations must not claim cloud delivery without a real 2xx response.
abstract class FitnessSyncPort {
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry);

  Future<FitnessSyncFlushResult> flush();

  Future<int> pendingCount();
}

class NoOpFitnessSyncPort implements FitnessSyncPort {
  @override
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry) async {}

  @override
  Future<FitnessSyncFlushResult> flush() async {
    return const FitnessSyncFlushResult(
      flushedCount: 0,
      remainingCount: 0,
      mode: FitnessSyncFlushMode.localOnly,
      message: 'No-op sync port',
    );
  }

  @override
  Future<int> pendingCount() async => 0;
}
