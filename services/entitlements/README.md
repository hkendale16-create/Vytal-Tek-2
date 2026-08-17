# Vytal entitlements service (Phase G server stub)

Deploy this when you create a **dedicated Vytal Tek** Supabase (or other) project.
Do **not** apply these migrations to unrelated apps.

## Endpoints

| Path | Purpose |
|---|---|
| `POST /verify-entitlement` | Client receipt → verified entitlements JSON |
| `POST /apple-asn` | App Store Server Notifications V2 |
| `POST /google-rtdn` | Google Play Real-time Developer Notifications |

## Client wiring

```bash
flutter run --dart-define=VYTAL_ENTITLEMENT_API=https://<project>.supabase.co/functions/v1/verify-entitlement
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

- `APPLE_BUNDLE_ID`, App Store Connect API key / ASN shared secret
- `GOOGLE_PLAY_PACKAGE_NAME`, Play service-account JSON
- Service role key only inside the function — never in the Flutter app

## Status

This stub **fails closed** until Apple/Google verification is implemented with live credentials.
Schema + function scaffold are ready for that wiring.
