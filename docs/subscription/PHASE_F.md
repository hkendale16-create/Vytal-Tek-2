# Subscription Phase F — Security audit

**Branch:** `cursor/subscription-phase-f-42e5`

## Threats addressed

| Threat | Mitigation |
|---|---|
| Edit SharedPreferences to set `tier=pro` / `serverVerified` | `EntitlementSnapshot.fromJson` sanitizes via `EntitlementSecurity.sanitizeForPersistRestore` — paid access stripped to free + `localCacheUntrusted` |
| Inject unknown entitlement keys | Disk restore intersects to free keys only when no paid claim; assignable check rejects unknown keys |
| `setEntitlements(catalogPreview/localCacheUntrusted paid)` | `EntitlementSecurity.assertAssignable` rejects; session fails closed |
| `canUse` trusting `enabled` alone | Paid keys require authoritative source (`serverVerified`, or debug `sandboxPreview`) |
| Expired lifecycle still listing paid keys | `canUse` returns false when lifecycle does not grant access |
| Release sandbox preview unlock | UI hidden in release; `applySandboxPreview` no-ops in `kReleaseMode` |
| Cold start with cached paid claim | Launch calls `refreshAfterLaunch` → restore + re-verify when product hint present |

## Trusted vs untrusted decode

- `EntitlementSnapshot.parse` — trusted verifier / server payloads only
- `EntitlementSnapshot.fromJson` — disk restore (always sanitized)

## Remaining ops items (not client-only)

- [ ] Production entitlement API URL configured for `HttpEntitlementVerifier`
- [ ] App Store Server Notifications + Play RTDN wired to backend
- [ ] Certificate pinning / auth on entitlement API
- [ ] Fraud / refund revoked lifecycle handling on server

See also Phase G marketplace checklist.
