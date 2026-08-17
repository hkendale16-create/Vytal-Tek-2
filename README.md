# Vytal Tek

Personal health and performance platform. The app is valuable before hardware arrives (App-Only Mode) and becomes richer when a Vytal wearable is paired (Connected Mode).

## Repository layout

```
apps/mobile/     Flutter app (iOS, Android, web shell)
site/            Public landing + Privacy / Terms (Netlify publish dir)
```

## Phase status

| Phase | Status |
|---|---|
| 0 Audit | Complete — repo was greenfield |
| 1 Foundation | Complete on branch history |
| 2 Wearable connection | Complete — lifecycle + demo adapter |
| 3 Monitoring engine | Complete — Active/Normal/Standby + auto-switch + background gate |
| QRing SDK packages | Vendored under `third_party/qring/` (Android AAR + iOS framework) |
| QRing native bridge | Android + iOS MethodChannels wired into `QRingWearableAdapter` |
| 4 Core Health UI | Complete on branch history — Home/Activity/Sleep/Insights/Profile |
| Subscription A | Complete — entitlement service, catalog, soft paywalls |
| Subscription B–E | Complete — StoreKit/Play adapters, server verify, plan changes |
| Subscription F | Complete — persist tamper protections + canUse hardening |
| Subscription G | Complete on main — client go-live; console products still human |
| Hosting | Supabase Vytal Tek project live; Netlify legal site pending Git connect |
| Store review | CI + legal Pages + review packet (`docs/store/REVIEW_NOTES.md`) |
| Data usage audit | Hardened — selective health watches, no unpaired sensor ticks |
| 5 3D Experience | Complete on branch — interactive Live Body stage |
| 6 AI Coach | Complete on branch — grounded Coach Vital chat |
| 7 Notes & Reminders | Complete on branch — local notes/reminders + AI context |
| 8 Battery Intelligence | Complete on branch — alerts, estimates, tips (no invented %) |
| 9 Performance + QA | Complete on branch — selective watches + regression tests |
| Workouts / Timers | Complete on branch — routines + timer engine (App-Only safe) |

## Run (mobile)

```bash
cd apps/mobile
flutter pub get
flutter test
flutter run
```

## Phase 1 foundations

- Light / Dark / System theme (shared brand tokens)
- Navigation: Today, Analytics, Activity, Body, Ask Vytal + Devices / Settings
- App session state: App-Only ↔ Connected, monitoring modes, demo flag, profile, entitlements keys
- `WearableDevice` adapter interface + unpaired / QRing native bridge (no fabricated sensors)
- Permissions center catalog with request + system settings deep link
- First-launch device arrival choices without forcing pairing

## Important rules

- Never present manual or demo values as wearable readings
- QRing capabilities stay unknown until the live device reports them after pairing
- Subscription entitlement checks use keys (`ai.advanced`), not plan name strings
- Client-side premium flags are not authoritative — server verification comes later
