# Vytal Tek

Personal health and performance platform. The app is valuable before hardware arrives (App-Only Mode) and becomes richer when a Vytal wearable is paired (Connected Mode).

## Repository layout

```
apps/mobile/     Flutter app (iOS, Android, web shell)
```

## Phase status

| Phase | Status |
|---|---|
| 0 Audit | Complete — repo was greenfield |
| 1 Foundation | Complete on branch history |
| 2 Wearable connection | Complete — lifecycle + demo adapter; QRing SDK pending |
| 3 Monitoring engine | In progress — Active/Normal/Standby + auto-switch + background gate |
| 4+ Health UI / 3D / AI / billing | Not started |

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
- `WearableDevice` adapter interface + unpaired / QRing stub (no fabricated sensors)
- Permissions center catalog with request + system settings deep link
- First-launch device arrival choices without forcing pairing

## Important rules

- Never present manual or demo values as wearable readings
- QRing capabilities stay unknown until official SDK docs/binaries are integrated
- Subscription entitlement checks use keys (`ai.advanced`), not plan name strings
- Client-side premium flags are not authoritative — server verification comes later
