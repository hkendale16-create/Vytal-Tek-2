import '../domain/models/fitness_hub_models.dart';

/// Built-in workout plan catalog — no weight-loss guarantees.
///
/// Monetization: Free users get quality **starter** plans.
/// Premium programs remain visible with `advanced: true` (PRO badge) so Free
/// users understand what Pro adds — enrollment requires plans.advanced.
abstract final class WorkoutPlanLibrary {
  static List<WorkoutPlan> get all => const [
        // ── Free starters ────────────────────────────────────────────────
        WorkoutPlan(
          id: 'plan-beginner-strength',
          name: 'Beginner Strength',
          tagline: 'Learn the big patterns safely',
          goal: PlanGoal.strength,
          difficulty: PlanDifficulty.beginner,
          weeks: 4,
          daysPerWeek: '3',
          durationMin: 35,
          durationMax: 50,
          equipment: ['Dumbbells', 'Bench optional'],
          muscleGroups: ['Full Body'],
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Full Body A'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Full Body B'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Full Body C'),
            PlanDayTemplate(weekday: 6, title: 'Optional Walk', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-3day-full-body',
          name: '3-Day Full Body',
          tagline: 'Balanced weekly rhythm',
          goal: PlanGoal.generalFitness,
          difficulty: PlanDifficulty.beginner,
          weeks: 4,
          daysPerWeek: '3',
          durationMin: 30,
          durationMax: 45,
          equipment: ['Bodyweight', 'Dumbbells'],
          muscleGroups: ['Full Body'],
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Full Body A'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Full Body B'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Full Body C'),
            PlanDayTemplate(weekday: 6, title: 'Optional Cardio', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-home-starter',
          name: 'Home Starter',
          tagline: 'Train with what you own',
          goal: PlanGoal.homeWorkouts,
          difficulty: PlanDifficulty.beginner,
          weeks: 4,
          daysPerWeek: '3–4',
          durationMin: 20,
          durationMax: 40,
          equipment: ['Dumbbells', 'Bands', 'Bodyweight'],
          muscleGroups: ['Full Body'],
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Upper'),
            PlanDayTemplate(weekday: 2, title: 'Lower'),
            PlanDayTemplate(weekday: 3, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 4, title: 'Full Body'),
            PlanDayTemplate(weekday: 5, title: 'Core + Cardio'),
            PlanDayTemplate(weekday: 6, title: 'Optional', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-beginner-cardio',
          name: 'Beginner Cardio',
          tagline: 'Easy consistency first',
          goal: PlanGoal.running,
          difficulty: PlanDifficulty.beginner,
          weeks: 4,
          daysPerWeek: '3',
          durationMin: 20,
          durationMax: 35,
          equipment: ['None'],
          muscleGroups: ['Cardio', 'Legs'],
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Easy Cardio'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Intervals Lite'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Easy Cardio'),
            PlanDayTemplate(weekday: 6, title: 'Optional Walk', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-basic-calisthenics',
          name: 'Basic Calisthenics',
          tagline: 'Push · Pull · Core foundations',
          goal: PlanGoal.calisthenics,
          difficulty: PlanDifficulty.beginner,
          weeks: 4,
          daysPerWeek: '3',
          durationMin: 25,
          durationMax: 40,
          equipment: ['Pull-up bar optional', 'Bodyweight'],
          muscleGroups: ['Chest', 'Back', 'Core', 'Legs'],
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Push'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Pull'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Legs + Core'),
            PlanDayTemplate(weekday: 6, title: 'Optional Mobility', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),

        // ── Pro library (visible with PRO badge) ─────────────────────────
        WorkoutPlan(
          id: 'plan-ppl',
          name: 'Push / Pull / Legs',
          tagline: 'Classic hypertrophy split',
          goal: PlanGoal.buildMuscle,
          difficulty: PlanDifficulty.intermediate,
          weeks: 6,
          daysPerWeek: '4–6',
          durationMin: 45,
          durationMax: 70,
          equipment: ['Barbell', 'Dumbbells', 'Bench', 'Cable'],
          muscleGroups: ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Push', focus: 'Chest · Shoulders · Triceps'),
            PlanDayTemplate(weekday: 2, title: 'Pull', focus: 'Back · Biceps'),
            PlanDayTemplate(weekday: 3, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 4, title: 'Legs', focus: 'Quads · Glutes · Hamstrings'),
            PlanDayTemplate(weekday: 5, title: 'Upper', focus: 'Push + Pull'),
            PlanDayTemplate(weekday: 6, title: 'Optional Cardio', optional: true, focus: 'Conditioning'),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-strength-3',
          name: 'Strength Foundations',
          tagline: 'Squat · Bench · Hinge focus',
          goal: PlanGoal.strength,
          difficulty: PlanDifficulty.intermediate,
          weeks: 8,
          daysPerWeek: '3',
          durationMin: 50,
          durationMax: 75,
          equipment: ['Barbell', 'Squat rack', 'Bench'],
          muscleGroups: ['Full Body'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Squat Day', focus: 'Lower strength'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Bench Day', focus: 'Press strength'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Hinge Day', focus: 'Deadlift pattern'),
            PlanDayTemplate(weekday: 6, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-conditioning-pro',
          name: 'Engine Builder',
          tagline: 'Conditioning without outcome guarantees',
          goal: PlanGoal.fatLossConditioning,
          difficulty: PlanDifficulty.intermediate,
          weeks: 6,
          daysPerWeek: '4',
          durationMin: 30,
          durationMax: 45,
          equipment: ['Bodyweight', 'Optional dumbbells'],
          muscleGroups: ['Full Body', 'Cardio'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Intervals', focus: 'Work / rest'),
            PlanDayTemplate(weekday: 2, title: 'Strength Circuit'),
            PlanDayTemplate(weekday: 3, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 4, title: 'Steady Cardio'),
            PlanDayTemplate(weekday: 5, title: 'Full Body Circuit'),
            PlanDayTemplate(weekday: 6, title: 'Optional Walk', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-calisthenics-adv',
          name: 'Bodyweight Progressions',
          tagline: 'Skill + strength calisthenics',
          goal: PlanGoal.calisthenics,
          difficulty: PlanDifficulty.intermediate,
          weeks: 6,
          daysPerWeek: '4',
          durationMin: 35,
          durationMax: 55,
          equipment: ['Pull-up bar', 'Bodyweight'],
          muscleGroups: ['Chest', 'Back', 'Core', 'Legs'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Push'),
            PlanDayTemplate(weekday: 2, title: 'Pull'),
            PlanDayTemplate(weekday: 3, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 4, title: 'Legs + Core'),
            PlanDayTemplate(weekday: 5, title: 'Skill / Mobility'),
            PlanDayTemplate(weekday: 6, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-running-pro',
          name: 'Run Consistency',
          tagline: 'Easy miles + one quality session',
          goal: PlanGoal.running,
          difficulty: PlanDifficulty.intermediate,
          weeks: 8,
          daysPerWeek: '3–4',
          durationMin: 25,
          durationMax: 55,
          equipment: ['None'],
          muscleGroups: ['Cardio', 'Legs'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Easy Run'),
            PlanDayTemplate(weekday: 2, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 3, title: 'Intervals'),
            PlanDayTemplate(weekday: 4, title: 'Rest', isRest: true),
            PlanDayTemplate(weekday: 5, title: 'Easy Run'),
            PlanDayTemplate(weekday: 6, title: 'Optional Long', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
        WorkoutPlan(
          id: 'plan-advanced-hypertrophy',
          name: 'Advanced Hypertrophy',
          tagline: 'Higher volume, adaptive structure',
          goal: PlanGoal.buildMuscle,
          difficulty: PlanDifficulty.advanced,
          weeks: 8,
          daysPerWeek: '5–6',
          durationMin: 55,
          durationMax: 90,
          equipment: ['Full gym'],
          muscleGroups: ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms'],
          advanced: true,
          weeklyStructure: [
            PlanDayTemplate(weekday: 1, title: 'Chest + Triceps'),
            PlanDayTemplate(weekday: 2, title: 'Back + Biceps'),
            PlanDayTemplate(weekday: 3, title: 'Legs'),
            PlanDayTemplate(weekday: 4, title: 'Shoulders + Arms'),
            PlanDayTemplate(weekday: 5, title: 'Posterior Chain'),
            PlanDayTemplate(weekday: 6, title: 'Optional Weak Point', optional: true),
            PlanDayTemplate(weekday: 7, title: 'Rest', isRest: true),
          ],
        ),
      ];

  static List<WorkoutPlan> get freeStarters =>
      all.where((p) => !p.advanced).toList();

  static List<WorkoutPlan> get proPlans =>
      all.where((p) => p.advanced).toList();

  static WorkoutPlan? byId(String id) {
    for (final plan in all) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  static List<WorkoutPlan> forGoal(PlanGoal goal) =>
      all.where((p) => p.goal == goal).toList();

  static List<WorkoutPlan> forDifficulty(PlanDifficulty difficulty) =>
      all.where((p) => p.difficulty == difficulty).toList();

  /// Whether starting this plan requires Pro (`plans.advanced`).
  static bool requiresPro(WorkoutPlan plan) => plan.advanced;
}
