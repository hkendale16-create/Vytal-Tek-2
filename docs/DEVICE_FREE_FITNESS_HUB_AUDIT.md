# Device-Free Fitness Hub — Pre-Implementation Audit

Audit date: 2026-08-20  
Scope: Expand Vytal Tek so the app is valuable with or without a wearable.

## 1. What functionality already exists

| Area | Status |
|---|---|
| App-Only / Connected operating modes | Exists (`OperatingMode`) |
| First-launch device arrival choices | Exists (3 choices) |
| Workout hub (cardio / strength / calisthenics) | Exists |
| Quick Start, routines, set/rep logging, rest timers | Exists |
| Workout history + volume + set logs | Exists |
| Personal records (duration / volume / distance / sets) | Exists in `TrainingGuidance` |
| Weekly scorecard + streaks | Exists |
| Exercise library (~54 definitions) | Exists (in-code) |
| Standalone timers | Exists |
| Outdoor GPS + route sketch | Exists |
| Local AI Coach (rule engine, grounded) | Exists |
| Soft paywalls + entitlement keys | Exists |
| Wearable adapters (Unpaired / Demo / QRing) | Exists |
| Profile equipment / goals fields | Exists on `PersonalProfile` |
| Fitness calendar / scheduled workouts | **Missing** |
| Workout plan programs + calendar fill | **Missing** |
| Gym discovery / maps / equipment profiles | **Missing** |
| Device-free Progress dashboard | **Partial** (history only) |
| Progress photos | **Missing** |
| Primary nav Today \| Workout \| Body \| Coach \| Profile | **Not current** (Today \| Vitals \| Workouts \| Plans \| More) |

## 2. Current workout architecture

- Models: `apps/mobile/lib/domain/models/workout_models.dart`
- Controllers: `apps/mobile/lib/workouts/workout_controllers.dart` (Riverpod notifiers, SharedPreferences)
- UI: `features/workouts/*` (hub, active, summary, history, muscle picker, builder)
- Persistence keys: `vytal.workouts.routines.v1`, `vytal.workouts.history.v1`
- Session survives navigation via wall-clock timers; no cloud sync queue yet

**Reuse:** extend routines/history; do not fork a second workout engine.

## 3. Current calendar functionality

None. Closest: weekly scorecard + streak math in `training_guidance.dart`, date pickers on notes/reminders.

**New:** fitness calendar domain + local repository + week/month UI under Workout → Plan.

## 4. Current location / maps

- `phone_gps.dart` / `workout_gps.dart` for outdoor cardio tracks
- `geolocator` dependency present
- No place search, no map tiles, no gym finder

**New:** gym discovery repository with caching/debounce; location only on demand; manual city search fallback. Prefer provider abstraction (OSM Overpass or future Places) over UI coupling.

## 5. Current exercise data

- `ExerciseLibrary` + `ExerciseCatalog` (names only)
- Fields: muscle, equipment string, defaults for sets/reps/rest
- No alternatives graph, no instructions media, no secondary muscles structured

**Reuse:** expand catalog in place; add alternatives + detail screen; link to Body highlight when possible.

## 6. Current AI Coach architecture

- UI: `features/ai/ai_coach_screen.dart`
- Chat persistence: `coach_chat_controller.dart`
- Engine: `CoachVitalEngine` (local keyword/rules, can `buildStructuredWorkout`)
- Gated by `ai.basic` / `ai.advanced`
- No LLM backend

**Reuse:** extend prompts for calendar/equipment/progress; keep non-diagnostic rules.

## 7. Current subscription architecture

- Keys in `entitlements.dart`, catalog Free / Plus / Pro
- Free already includes custom workouts + basic AI + basic analytics
- SoftPaywall / EntitlementGate
- Supabase: entitlements + purchase events only

**Extend:** add hub keys (calendar.advanced, plans.library_advanced, progress.advanced, ai.workout_builder) without scattering plan-name checks. Introduce Complete as Pro + device experience packaging concept (pricing not final).

## 8. Current wearable architecture

```
WearableDevice → Unpaired | Demo | QRing adapters
OperatingMode.appOnly | connected
```

Hardware features must remain capability-gated, not Pro-locked for basic live readings when a device is owned.

## 9. Existing models that can be reused

- `WorkoutRoutine`, `WorkoutExercise`, `WorkoutHistoryEntry`, `WorkoutSetLog`
- `PersonalProfile.availableEquipment` / goals / experience
- `EntitlementSnapshot` + `EntitlementKeys`
- `OperatingMode` / `DeviceArrivalChoice`
- Notes / reminders for optional reminder UX patterns

## 10. New models actually required

| Model | Purpose |
|---|---|
| `FitnessCalendarEvent` | Scheduled / completed / rest / weigh-in / custom |
| `WorkoutPlan` + `PlanWeekDay` | Multi-week programs |
| `PlanEnrollment` | Start date, training days, reminders |
| `GymPlace` / `SavedGym` / `GymEquipmentProfile` | Discovery + user equipment |
| `HomeGymEquipment` | Owned gear (may extend profile list) |
| `ProgressPhoto` | Private local photos metadata |
| `PersonalRecord` (strength-focused) | Lift PRs beyond session metrics |
| Entitlement key additions | Hub Pro features |

No duplicate tables for sets/history — calendar completed entries link to `WorkoutHistoryEntry.id`.

## 11. APIs / services for gym discovery

| Layer | Choice |
|---|---|
| Abstraction | `GymDiscoveryRepository` |
| Default provider | Cached Overpass (OSM) amenity queries — no API key |
| Fallback | Manual city search + seeded demo places when denied location |
| Directions | `url_launcher` → platform maps |
| Map UI | List-first; lightweight map viewport without continuous refetch |

## 12. Offline architecture

- Continue SharedPreferences / local JSON for hub data
- Persist active workout (already session-based); harden draft autosave key
- Calendar / plans / gyms / photos local-first
- Sync queue stub for future AWS/backend — repository interface only; no migration now

## 13. Performance risks

- Large exercise catalog in memory → keep lazy filters, paginate UI lists
- Gym Overpass spam → radius + viewport debounce + TTL cache
- Bottom-nav tab rebuilds → keep lazy tab mounting (current AppShell)
- Image progress photos → store paths, thumbnails later; never upload by default

## 14. Proposed implementation sequence

1. Device-free architecture + entitlements + nav IA + device-free Today  
2. Fitness calendar (+ auto history sync + reminders prefs)  
3. Workout plan library + start → calendar  
4. Exercise library expansion + details + alternatives  
5. Gym discovery (list / privacy / cache)  
6. Gym equipment → Workout Here  
7. Device-free Progress + PRs + optional photos  
8. AI Workout Builder  
9. Coach integration (device-free + device-enhanced context)  
10. Subscription / upgrade UX (contextual)  
11. Wearable enhancement hooks on Today / Coach  
12. Performance + offline hardening  
13. Global QA / tests  

## Product principle (target)

- **No device:** Plan → Train → Track → Progress  
- **Vytal Pro:** + Analyze → AI Personalization  
- **Device + Pro:** + Measure → Recover → Adapt  

The wearable makes Vytal smarter; it is not required to love the app.
