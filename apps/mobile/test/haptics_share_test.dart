import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/today/training_guidance.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completeSet advances into rest without throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = container.read(workoutSessionProvider.notifier);
    session.startRoutine(
      WorkoutRoutine(
        id: 'haptic',
        name: 'Haptic',
        exercises: const [
          WorkoutExercise(
            id: 'ex1',
            name: 'Squat',
            sets: 2,
            durationSeconds: 20,
            restSeconds: 5,
          ),
        ],
      ),
    );
    session.completeSet();
    expect(container.read(workoutSessionProvider).isResting, isTrue);
    session.skipRest();
    expect(container.read(workoutSessionProvider).isResting, isFalse);
    session.stop();
  });

  test('empty week scorecard suggests Quick Start', () {
    final card = TrainingGuidance.weekScorecard(const []);
    expect(card.suggestion, contains('Quick Start'));
    expect(card.sessions, 0);
  });
}
