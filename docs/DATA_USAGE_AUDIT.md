# Data & usage audit (Phases 1–F)

Audit of radio, timer, and network cost across shipped phases. Goal: App-Only
and idle Connected must not burn BLE/cellular, and UI churn must not re-fetch.

## Verdict

| Area | Risk before | Status |
|---|---|---|
| Today health reads | Re-ran on **any** session change (incl. monitoring mode) | **Fixed** — selective `select()` watches |
| App-Only empty Home | Still called 6 adapter getters | **Fixed** — fast empty path, zero adapter I/O |
| Monitoring sensor timer | Ran at Active 1s even when unpaired | **Fixed** — timer off when unpaired |
| Monitoring eval timer | 15s always | **Fixed** — 2 min when unpaired / App-Only |
| Sensor timer BLE | Comment-only ticks (no radio) | **OK** — still no radio on tick |
| Device sync | Manual / connect path only | **OK** |
| Subscription launch | `refreshAfterLaunch` | **OK** — only if `localCacheUntrusted` + productId |
| Entitlement HTTP | Default fail-closed, no URL | **OK** — no network until configured |
| QRing metric getters | Mostly last-sync cache; battery may read live | **OK** — cache-first |
| Demo adapter | Local labeled values | **OK** — no network |

## Phase-by-phase notes

### Phase 1–2 — Foundation / connection
- Scan/connect/sync are **user-initiated** (Devices screen).
- No continuous BLE scan loop in the shell.

### Phase 3 — Monitoring
- Policies document intended cadences (Active 1s / Normal 30s / Standby 10m).
- Sensor timer increments intent ticks only — **does not** call `getHeartRate` etc.
- Eval loop decides Active/Normal/Standby; persists mode only when it changes.

### Phase 4 — Health UI
- Home / Activity / Sleep / Insights / Body share one `todayHealthProvider`.
- Reads are cache-first on QRing; Demo is local; App-Only skips reads after fix.

### Subscription A–F
- No periodic purchase polling.
- Store restore on cold start only when a paid cache hint needs re-verify.
- Soft paywalls are local entitlement checks (no network).

## Still intentional (not bugs)

- Active mode **policy** still says 1s sensor interval for when live workout sampling is wired — ticks remain no-op until a workout/live path attaches.
- Manual **Sync** on Devices may talk to the ring once per user action.
- Future entitlement API traffic happens only on purchase/restore/verify.

## How to re-check

```bash
cd apps/mobile
flutter test test/phase3_monitoring_test.dart test/phase4_health_ui_test.dart
flutter analyze lib
```
