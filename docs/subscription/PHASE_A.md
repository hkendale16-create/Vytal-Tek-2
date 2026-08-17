# Subscription Phase A — Design & client architecture

**Status:** Implemented on `cursor/subscription-phase-a-42e5`

This is **not** master plan Phase 5 (3D Experience). It is **Subscription Phase A** from the subscription extension (A–G).

## Goals (Phase A)

- Centralized entitlement / subscription service
- Configurable Free / Plus / Pro product catalog
- Settings → Subscription + Plans UI
- Soft paywalls keyed by entitlement IDs (not plan name strings)
- Billing platform stubs (no live StoreKit / Play purchases)
- Explicit rule: client never grants production premium alone

## Non-goals (later phases)

| Phase | Work |
|---|---|
| B–E | See `PHASES_B_E.md` — StoreKit/Play, server verify, plan changes |
| F | Full security audit |
| G | Marketplace readiness |

Master Phase 5 remains **3D Experience**. Phase 6 remains **AI Coach**.

## Entitlement keys

Screens ask `EntitlementKeys.*` only:

- `ai.basic`, `ai.advanced`
- `analytics.basic`, `analytics.advanced`
- `recovery.advanced`, `sleep.advanced`
- `digital_body.advanced`
- `workouts.custom`, `workouts.ai_generated`
- `history.extended`

## Architecture

```
lib/domain/models/entitlements.dart     # keys, tiers, lifecycle, snapshot
lib/subscription/product_catalog.dart   # Free/Plus/Pro maps
lib/subscription/entitlement_service.dart
lib/subscription/subscription_controller.dart
lib/features/subscription/              # Subscription, Plans, SoftPaywall
```

`BillingPlatform` is abstract. `UnsupportedBillingPlatform` is the Phase A default.

## Security rules

- Never trust `isPremium = true` from the client alone
- Subscribe buttons do **not** grant Plus/Pro in production
- Sandbox preview exists for UI review and is labeled — not authoritative
- Server verification is Phase D

## UI entry points

- Profile → Subscription
- Settings → Subscription
- Soft paywalls on Insights (advanced ranges / recovery), Sleep stages,
  Live Body digital insights, Coach Vital adaptive section
