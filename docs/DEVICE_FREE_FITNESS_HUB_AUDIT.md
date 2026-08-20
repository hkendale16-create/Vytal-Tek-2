# Device-Free Fitness Hub — Pre-Implementation Audit

Audit date: 2026-08-20  
Updated: 2026-08-20 (implementation complete on branch)  
Scope: Expand Vytal Tek so the app is valuable with or without a wearable.

## Status (post-implementation)

| Area | Status |
|---|---|
| App-Only / Connected operating modes | **Done** |
| Device-free Today + start today’s plan | **Done** |
| Fitness calendar + history sync + reminders | **Done** |
| Workout plan library + enroll → calendar | **Done** |
| Exercise browser + alternatives | **Done** |
| Gym discovery (list + relative map pins) | **Done** |
| Gym equipment → Workout Here | **Done** |
| Home gym filtering | **Done** |
| Device-free Progress + PRs + local photos | **Done** |
| AI Workout Builder | **Done** |
| Coach calendar/equipment/gap context | **Done** |
| Free → Pro → Device → Complete monetization | **Done** |
| Wearable readiness from verified metrics | **Done** |
| Offline draft autosave + local sync queue | **Done** |
| Primary nav Today \| Workout \| Body \| Coach \| Profile | **Done** |
| Future ecosystem marketplace | **Done** (browse + gym claims; no live payments) |
| Cloud sync flush | **Done** (optional HTTP POST; queue cleared only on 2xx) |
| Gym map tiles | **Done** (`flutter_map` + OSM; list-first) |

## Product principle (target)

- **No device:** Plan → Train → Track → Progress  
- **Vytal Pro:** + Analyze → AI Personalization  
- **Device + Pro:** + Measure → Recover → Adapt  

The wearable makes Vytal smarter; it is not required to love the app.

## Implementation sequence (closed)

1. Device-free architecture + entitlements + nav IA + device-free Today — **done**  
2. Fitness calendar (+ auto history sync + reminders prefs) — **done**  
3. Workout plan library + start → calendar — **done**  
4. Exercise library expansion + details + alternatives — **done**  
5. Gym discovery (list / privacy / cache) — **done**  
6. Gym equipment → Workout Here — **done**  
7. Device-free Progress + PRs + optional photos — **done**  
8. AI Workout Builder — **done**  
9. Coach integration (device-free + device-enhanced context) — **done**  
10. Subscription / upgrade UX (contextual) — **done**  
11. Wearable enhancement hooks on Today / Coach — **done**  
12. Performance + offline hardening — **done**  
13. Global QA / tests — **done** (hub + nav + timer suites)

## Notes

- Progress photos store under app documents; never upload by default.
- `LocalQueuedFitnessSyncPort` queues outbound workout mirrors and can POST to a user-configured endpoint from Settings → Fitness sync. Delivery is never claimed without HTTP 2xx.
- Gym map uses OpenStreetMap tiles via `flutter_map` only when Map view is opened (list remains default).
- Trainer marketplace and gym claims are local UX; platform fees and partner decisions are not charged/finalized in-app.
- Readiness scores only compute from verified sleep/HRV (and optional HR nudge); never invented.
- Sponsored gym placements must show a clear **Sponsored** label when `promoted` is true.
