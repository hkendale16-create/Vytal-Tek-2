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
- [ ] Point `HttpEntitlementVerifier` at production entitlement API
- [ ] Privacy policy + Terms links from Subscription / Plans
- [ ] Subscription disclosure copy (auto-renew, cancel path) for store review

## Server

- [ ] Verify App Store JWS / transaction APIs
- [ ] Verify Google Play purchase tokens
- [ ] App Store Server Notifications V2
- [ ] Google Play Real-time Developer Notifications
- [ ] Authoritative entitlement store (per user)
- [ ] Grace / billing retry / refund / revoke mapping to `SubscriptionLifecycle`

## Store review

- [ ] Demo account with active Plus (or clear sandbox instructions)
- [ ] Restore purchases works on fresh install
- [ ] No premium unlock without purchase in reviewer flow
- [ ] Guidelines 3.1.1 / Play billing policy compliance reviewed

## Sign-off

| Role | Date | Notes |
|---|---|---|
| Engineering | | |
| Backend | | |
| App Store review prep | | |
| Play review prep | | |
