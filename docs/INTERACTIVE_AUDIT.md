# Vytal Tek — Interactive Sections Audit

Inspected `apps/mobile` on `main` before wiring real navigable flows. Working systems (devices, monitoring, subscription, Coach Vital grounding, demo provenance) are preserved. No production vitals are invented.

## 1. Existing navigation structure

**Bottom navigation** (`lib/features/shell/app_shell.dart`):

| Tab | Route | Screen |
|---|---|---|
| Home | `/today` | TodayScreen |
| Activity | `/activity` | ActivityScreen |
| Sleep | `/sleep` | SleepScreen |
| Insights | `/analytics` | AnalyticsScreen |
| Profile | `/profile` | ProfileScreen |

Home FAB → `/devices`.

**Overlay routes** (`lib/core/routing/app_router.dart`): `/welcome`, `/body`, `/ask`, `/notes`, `/reminders`, `/battery`, `/workouts`, `/workouts/session`, `/devices`, `/settings`, `/settings/subscription`, `/settings/subscription/plans`, `/settings/permissions`, `/settings/monitoring`.

Profile already links Settings, Subscription, Devices, Battery, Workouts, Coach, Notes, Reminders, Live Body.

## 2. Missing screens

| Needed | Status before this work |
|---|---|
| Vitals list + metric detail | Missing (HR/SpO₂/HRV only as untappable Today tiles) |
| Recovery / Readiness detail | Missing (gauge on Today only) |
| Dedicated Timer / Stopwatch / Interval | Missing (stopwatch+countdown lived only inside workout session) |
| Workout activity picker + active workout + history + summary | Missing |
| Custom routine builder | Missing (only a hardcoded two-exercise “quick custom”) |
| Routine player skip / complete-set | Missing |
| Structured AI workout generate / save | Missing |
| Sleep date navigation | Missing |
| Analytics metric + range that changes data | Partial (chips change label; series hardcoded) |
| Notes search / filter / attach; reminder date-time / category / snooze | Partial |
| Body region tap → metric | Missing (drag/rotate works) |

## 3. Existing but non-functional (display-only)

- Today: `ReadinessGauge`, four `MetricHudTile`s — no `onTap`
- Activity rings / calorie tiles
- Sleep gauge
- Analytics sparkline (demo series ignored range)
- Body overlay `MetricHudTile`s
- Settings **Privacy & Data** `EmptyMetricCard` — no action
- Today error copy says “Pull to retry” with no `RefreshIndicator`

## 4. Dead buttons / cards

`MetricHudTile` had no `onTap`. Dashboard cards looked interactive but were decorative. Workout “Create quick custom routine” saved a hardcoded routine (functional save, not a builder). Reminder add always used “now + 2 hours” with no date/time picker.

## 5. Current workout logic (reuse)

`lib/workouts/workout_controllers.dart`:

- Built-in + custom routines persist `vytal.workouts.routines.v1`
- `buildPhases` → exercise/rest from sets
- Session pause / resume / stop + `setWorkoutActive`
- Stopwatch ticks `stopwatchElapsed` inside the same session controller
- No skip, complete-set, free activity session, history, or summary save/discard

## 6. Current timer / stopwatch logic

No dedicated countdown, lap stopwatch, or interval timer. Session timer does not survive as an independent feature when leaving workouts. New timers must live in Riverpod notifiers (wall-clock based) so navigation does not reset them.

## 7. Current Vitals implementation

`todayHealthProvider` / `TodayHealthSnapshot` already loads HR, HRV, SpO₂, temperature, sleep, battery, steps, calories from the wearable adapter. Unused keys exist (`restingHeartRate`, `respiratoryRate`, …). UI never opened a Vitals section or detail. Demo adapter HR was a static `72`.

## 8. Current AI Coach implementation

Keyword engine in `coach_vital_engine.dart`. Persists chat. Never invents missing vitals. Workout requests return paragraphs, not `WorkoutRoutine`. No suggested-question chips.

## 9. Current device / monitoring implementation

Pair / sync / reconnect / disconnect / rename / remove + Demo adapter work. Monitoring Active / Normal / Standby, automatic, background, and battery intelligence (`/battery`) work. Home already shows monitoring mode. Missing: battery tap from Home, 20% notification dedupe, region-level body interaction.

## 10. Files / modules to modify

- `app_router.dart`, `today_screen.dart`, `health_ui.dart`, `profile_screen.dart`
- `activity_screen.dart`, `sleep_screen.dart`, `analytics_screen.dart`, `body_screen.dart`, `live_body_stage.dart`
- `workout_controllers.dart`, `workout_models.dart`, `workouts_screen.dart`, `workout_session_screen.dart`
- `coach_vital_engine.dart`, `ai_coach_screen.dart`, `coach_chat_controller.dart`
- `notes_models.dart`, `notes_controller.dart`, `notes_screen.dart`, `reminders_screen.dart`
- `battery_intelligence.dart`, `demo_adapter.dart`, `settings_screen.dart`

## 11. Components that can be reused

`SectionScaffold`, `GlassPanel`, `EmptyMetricCard`, `StatusPill`, `EntitlementGate`, `SoftPaywall`, `todayHealthProvider`, `workoutLibraryProvider`, `workoutSessionProvider`, `monitoringControllerProvider`, `deviceConnectionProvider`, `notesProvider`, `coachChatProvider`, Demo adapter.

## 12. Recommended implementation order

1. Navigation + Home quick actions + tappable cards → real routes  
2. Vitals list + detail (empty/unsupported copy; live pulse tied to readings)  
3. Persistent Timer / Stopwatch / Interval  
4. Activity picker + active workout + pause/resume/finish/summary/history  
5. Routine builder + player (complete set, skip, rest)  
6. Recovery, Sleep date, Analytics range/metric  
7. Coach chips + structured AI workout  
8. Notes search/tags; reminders date/time/category/snooze  
9. Battery tap + monitoring indicator + 20% dedupe  
10. Body region taps + floating metric taps  

**Rule:** never fabricate production sensor readings. Demo values stay labeled Demo.
