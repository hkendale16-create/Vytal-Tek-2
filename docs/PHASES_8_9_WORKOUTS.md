# Phases 8–9 + Workouts

## Phase 8 — Battery Intelligence
- `BatteryIntelligence` evaluates verified wearable % only — never invents a reading
- Alert levels: ok / watch (≤35) / low (≤20) / critical (≤10)
- Coarse sync-window estimates from monitoring mode cost (Active/Normal/Standby)
- Charging and load tips; Demo battery stays labeled
- UI: `/battery` (Profile + Devices)

## Phase 9 — Performance + QA
- Selective Riverpod watches on battery inputs (session slice, connection battery, health battery)
- Workout timer only arms a 1s tick while a session is running
- Monitoring still respects unpaired / App-Only gates from the data-usage audit
- Tests: battery insight (no invented %), workout phase timer, App-Only smoke, built-in routines
- Checklist: offline App-Only launch, pair→sync battery path, start/pause/end workout, soft paywall for custom when locked

## Workouts / Timers
- Built-in routines + custom library (entitlement `workouts.custom`)
- Timer engine: exercise / rest / stopwatch phases; sets Active monitoring via `setWorkoutActive`
- Routes: `/workouts`, `/workouts/session` (Activity + Profile)
- Works in App-Only Mode without fabricated vitals
