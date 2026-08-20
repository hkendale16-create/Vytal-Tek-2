# Vytal Tek — Monetization & Profitability Architecture

Source of truth for Free / Pro / Device / Complete placement.
Do **not** independently invent paywalls for hub features — use this document.

## Core principle

| Layer | Promise |
|---|---|
| **Vytal Free** | Helps you train. |
| **Vytal Pro** | Helps you train smarter. |
| **Vytal Device** | Helps Vytal understand how your body responds. |
| **Vytal Complete** | Training + AI + advanced analytics + wearable personalization. |

Funnel: Discover → Free → Build history → Pro → Connect/Buy Device → Complete.

## Experience states (centralized)

Screens must not scatter `if (tier == pro)`. Query:

- `canUseFeature(EntitlementKeys…)` / `EntitlementService.canUse`
- `VytalExperienceState` via `monetizationProvider`: `free` | `trial` | `pro` | `deviceOwner` | `proDevice`

| State | Meaning |
|---|---|
| `free` | Software free defaults; no paired device |
| `trial` | Time-limited Pro access (server-verified) |
| `pro` | Paid software; no device |
| `deviceOwner` | Compatible device paired; Free software |
| `proDevice` | Pro (or Complete) + paired device |

## Free (acquisition engine)

Must stay useful — never intentionally frustrating.

Includes: workout logging, Quick Start, timers/rest, basic calendar, exercise library, Gyms Near Me, basic custom workouts, **limited starter plans**, basic history/progress/PRs, basic Coach (limits), device connection, **core device readings when hardware is owned**.

## Pro (intelligence)

Sells personalization, automation, advanced analysis — not arbitrary locks.

Includes: AI Workout Builder, advanced/adaptive plans, advanced Coach, advanced Progress, advanced calendar, 3D muscle history depth, volume/comparison insights, unlimited custom programs where appropriate.

## Device ownership

Core Bluetooth, battery, sync, supported readings, basic workout sensor hooks, basic sleep/activity — **not** locked behind Pro.

## Complete

Remote-configurable packaging (device + Pro). Pricing not hard-coded.

## Conversion UX rules

- Contextual upgrades only (e.g. opening AI Builder).
- Pro **previews** visible to Free (marked PRO) — do not hide everything.
- Device education after meaningful history (e.g. ~12 workouts), dismissible, not repeated.
- No launch spam, fake urgency, locked navigation, or deceptive discounts.

## Future (architecture only — do not implement payments)

- Verified / promoted gym profiles, membership offers, Vytal Partner
- Trainer marketplace (programs / remote coaching) with platform fee
- Three revenue engines: Software · Hardware · Fitness ecosystem

## Remote configuration

Feature→tier maps may be overridden by a cached remote config blob.
**Server verification remains authoritative** for paid access. Client config never grants Pro alone.

## Analytics (privacy-respecting)

Funnel events only — never raw vitals in generic analytics:
`workout_started`, `workout_completed`, `plan_viewed`, `gym_searched`, `gym_saved`, `coach_opened`, `pro_feature_viewed`, `upgrade_viewed`, `trial_started`, `subscription_started`, `device_connect_started`, `device_connected`, `device_explore_viewed`.

## Retention before monetization

Optimize: first workout → return → history → usefulness → then premium value.
