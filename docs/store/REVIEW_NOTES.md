# Store review notes

Use this packet when creating App Store / Play listings and subscription products.

## Product IDs

| Product | Store ID | Period |
|---|---|---|
| Vytal Plus | `vytal.plus.monthly` | Monthly auto-renew |
| Vytal Pro | `vytal.pro.monthly` | Monthly auto-renew |

Free is not a store product. Entitlement keys (`ai.advanced`, etc.) are never plan-name strings.

## Reviewer instructions

1. First launch: choose **Continue without a wearable** (App-Only). Do not force pairing.
2. Demo mode (Settings) shows labeled Demo metrics only — never as live hardware.
3. Subscription: **View plans**. Purchases go through the sandbox store. Premium does **not** unlock from a client flag.
4. Restore purchases on a fresh install after a sandbox buy.
5. Cancel / manage opens the platform subscription sheet.

## Legal URLs (GitHub Pages)

After enabling Pages (Actions source):

- Privacy: `https://hkendale16-create.github.io/VytalTek/privacy/`
- Terms: `https://hkendale16-create.github.io/VytalTek/terms/`

Override in release builds if a custom domain is ready:

```
--dart-define=VYTAL_PRIVACY_URL=https://…
--dart-define=VYTAL_TERMS_URL=https://…
```

## Console steps still required

### App Store Connect
1. Create auto-renewable subscriptions in a subscription group (e.g. `Vytal Membership`).
2. Product IDs must match the table above.
3. Localization, pricing, review screenshot, and paid-apps agreement.
4. Sandbox testers for Plus and Pro.

### Google Play Console
1. Create the same product IDs under subscriptions.
2. License testers.
3. Real-time developer notifications URL (after entitlements service is deployed).

## What this repo already enforces
- Purchase → server verify → apply
- Release builds fail closed without `VYTAL_ENTITLEMENT_API`
- Soft paywalls keep data; no fake vitals
