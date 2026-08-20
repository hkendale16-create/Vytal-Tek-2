# Vytal entitlements + platform backend

Deploy from `/workspace/supabase/` to the dedicated **Vytal Tek** project `sdeifrzdkiiexawwzfvb`.

## Endpoints

| Path | Purpose |
|---|---|
| `POST /verify-entitlement` | Client receipt → verified entitlements JSON + DB upsert |
| `POST /entitlement-lifecycle` | Lifecycle updates for signed-in users |
| `POST /fitness-sync` | Workout sync queue of record |
| `GET/POST /marketplace-checkout` | Catalog, interest, checkout + platform fee ledger |
| `GET/POST /gym-partner` | Claims, offers, sponsored placements |
| `POST /apple-asn` | App Store Server Notifications V2 (audit ingest) |
| `POST /google-rtdn` | Google Play RTDN (audit ingest) |

## Client wiring

```bash
flutter run \
  --dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement
```

Response shape expected by `HttpEntitlementVerifier`:

```json
{
  "ok": true,
  "message": "Verified Vytal Plus",
  "entitlements": { "...": "EntitlementSnapshot.parse fields" }
}
```

## Secrets (Edge Function)

- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_BUNDLE_ID`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `GOOGLE_PLAY_PACKAGE_NAME`
- `VYTAL_PARTNER_REVIEW_KEY` for gym partner review / sponsor actions
- Service role key only inside the function — never in the Flutter app

## Status

- Schema + Auth trigger + Edge Functions deployed for verify, sync, marketplace, gym partner
- Real StoreKit / Play receipts fail closed until store secrets are set
- Authenticated sandbox receipts can grant for development drills
- ASN / RTDN currently audit-ingest only until signed notification verification is finished
