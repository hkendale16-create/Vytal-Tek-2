# Subscription Phases B–E

**Branch:** `cursor/subscription-phases-b-e-42e5`

Builds on Phase A (catalog, soft paywalls, entitlement keys).

## Phase B — StoreKit

- `InAppPurchaseBillingPlatform` wraps `in_app_purchase` on iOS/macOS
- Purchase / restore streams produce `PurchaseReceipt` only
- Manage Subscription opens the App Store subscriptions page
- Sandbox drills use `SandboxBillingPlatform` in tests

## Phase C — Google Play Billing

- Same IAP adapter reports `googlePlayBilling` on Android
- Plan changes try `ChangeSubscriptionParam` with past purchases, then fall back
- Manage Subscription opens the Play subscriptions page

## Phase D — Server verification

- `EntitlementVerifier` is the only path that may produce `serverVerified` snapshots
- `MockEntitlementVerifier` accepts `sandbox.token.*` only (tests)
- `HttpEntitlementVerifier` posts receipts to the entitlement API; **fails closed** if unset
- Client never grants premium because the store sheet said success

## Phase E — Upgrade / downgrade / cancel / restore

- Plans UI confirms upgrade vs downgrade copy
- `changePlan` uses platform change APIs when available
- Cancel opens platform manage sheet; access continues until lifecycle expiry
- Restore re-verifies the latest store/sandbox receipt
- Lifecycle notifications (grace, expired, billing retry) update entitlements without deleting user data

## Security checklist (Phase F lite)

- [x] No client-only `isPremium = true` grant path
- [x] Receipts required before paid entitlements
- [x] HTTP verifier fails closed without backend
- [x] Expired lifecycle locks premium, keeps free core + data
- [ ] Production App Store / Play server notifications wired to backend (ops)
- [ ] App Store Connect + Play Console product IDs live in sandbox

## Product IDs (catalog)

- `vytal.core.free`
- `vytal.plus.monthly`
- `vytal.pro.monthly`

Configure matching IAP products before device sandbox testing.
