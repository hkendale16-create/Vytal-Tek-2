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

/// Sync hook for future AWS / cloud providers — no-op locally.
abstract class FitnessSyncPort {
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry);
  Future<void> flush();
}

class NoOpFitnessSyncPort implements FitnessSyncPort {
  @override
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry) async {}

  @override
  Future<void> flush() async {}
}
