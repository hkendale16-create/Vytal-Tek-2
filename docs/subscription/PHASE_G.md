# Subscription Phase G — Marketplace readiness checklist

Client architecture for B–F is in place. This checklist is the go-live gate for App Store / Play subscription launch.

## Products

- [ ] Create `vytal.plus.monthly` in App Store Connect (auto-renewable)
- [ ] Create `vytal.pro.monthly` in App Store Connect
- [ ] Create matching subscription products in Google Play Console
- [ ] Localized prices approved (replace catalog placeholders)
- [ ] Sandbox / license testers can purchase both tiers

## Client

- [x] StoreKit + Play Billing adapter (`InAppPurchaseBillingPlatform`)
- [x] Purchase → server verify → apply (no client-only grant)
- [x] Restore purchases
- [x] Manage / cancel opens platform subscription sheets
- [x] Upgrade / downgrade confirmation copy
- [x] Soft paywalls on paid features
- [x] Phase F local tamper protections
- [x] Point `HttpEntitlementVerifier` at production entitlement API via `VYTAL_ENTITLEMENT_API` dart-define (release fails closed if unset)
- [x] Privacy policy + Terms links from Subscription / Plans (`VytalLegalLinks`)
- [x] Subscription disclosure copy (auto-renew, cancel path) for store review

## Server

- [x] Schema + Edge Function stub deployed on dedicated **Vytal Tek** project `sdeifrzdkiiexawwzfvb`
- [ ] Verify App Store JWS / transaction APIs
- [ ] Verify Google Play purchase tokens
- [ ] App Store Server Notifications V2
- [ ] Google Play Real-time Developer Notifications
- [ ] Authoritative entitlement store (per user) wired from live verifies
- [ ] Grace / billing retry / refund / revoke mapping to `SubscriptionLifecycle`

## Store review

- [ ] Demo account with active Plus (or clear sandbox instructions) — `docs/store/REVIEW_NOTES.md`
- [ ] Restore purchases works on fresh install
- [ ] No premium unlock without purchase in reviewer flow
- [ ] Guidelines 3.1.1 / Play billing policy compliance reviewed
- [x] Privacy / Terms hosted from `site/` (GitHub Pages workflow) — enable Pages in repo settings

## Build flags

```bash
flutter build ipa \
  --dart-define=VYTAL_ENTITLEMENT_API=https://<host>/functions/v1/verify-entitlement \
  --dart-define=VYTAL_PRIVACY_URL=https://hkendale16-create.github.io/VytalTek/privacy/ \
  --dart-define=VYTAL_TERMS_URL=https://hkendale16-create.github.io/VytalTek/terms/
```

## Sign-off

| Role | Date | Notes |
|---|---|---|
| Engineering | 2026-08-17 | Client G items + entitlement stub landed |
| Backend | | Deploy stub + Apple/Google verify |
| App Store review prep | | Console products + legal URLs |
| Play review prep | | Console products + license testers |
