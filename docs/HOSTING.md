# Vytal Tek hosting

## Supabase (live)

Dedicated project **Vytal Tek** (not FirstVue):

| | |
|---|---|
| Ref | `sdeifrzdkiiexawwzfvb` |
| URL | https://sdeifrzdkiiexawwzfvb.supabase.co |
| Dashboard | https://supabase.com/dashboard/project/sdeifrzdkiiexawwzfvb |

### Edge Functions

| Function | Auth | Purpose |
|---|---|---|
| `POST /functions/v1/verify-entitlement` | User JWT | Receipt → entitlements; persists `vytal_entitlements` |
| `POST /functions/v1/entitlement-lifecycle` | User JWT | Lifecycle updates (cancel / grace / revoke) |
| `POST /functions/v1/fitness-sync` | User JWT | Workout queue of record |
| `GET/POST /functions/v1/marketplace-checkout` | User JWT (POST) | Trainer interest + checkout + fee ledger |
| `GET/POST /functions/v1/gym-partner` | User JWT / partner key | Claims, offers, sponsored inventory |
| `POST /functions/v1/apple-asn` | ASN credentials | App Store Server Notifications (audit ingest) |
| `POST /functions/v1/google-rtdn` | Play credentials | Play RTDN (audit ingest) |

### Client dart-defines

```bash
flutter run \
  --dart-define=VYTAL_SUPABASE_URL=https://sdeifrzdkiiexawwzfvb.supabase.co \
  --dart-define=VYTAL_SUPABASE_ANON_KEY=<anon-jwt> \
  --dart-define=VYTAL_SUPABASE_PUBLISHABLE_KEY=sb_publishable_0Afaq57w4OzpNTGVVV3o4A_EvNk7COE \
  --dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement
```

Defaults for the Vytal Tek project are baked into `VytalSupabaseConfig` for development.

### Secrets (Edge Function dashboard)

- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_BUNDLE_ID`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `GOOGLE_PLAY_PACKAGE_NAME`
- `VYTAL_PARTNER_REVIEW_KEY` — gym claim approve / sponsor mutations

Without Apple/Google secrets, **real store receipts fail closed**. Authenticated **sandbox** receipts (`platform=sandbox`, `verificationData` starts with `sandbox.token.`) can grant for drills.

RLS is on; users SELECT their own rows. Entitlement / sync / purchase **writes** use the service role inside Edge Functions only.

## Account

Settings → Account (`/account`) — email/password via Supabase Auth. Required for Pro/Complete verify, fitness sync flush, marketplace checkout, and gym claim submission.

## Netlify

Static legal site lives in `site/` (`netlify.toml` publish dir).

1. [Import the GitHub repo](https://app.netlify.com/start) → `hkendale16-create/VytalTek`
2. Publish directory: `site` (already in `netlify.toml`)
3. After the first deploy, set custom domain or use the `*.netlify.app` URL:

```
--dart-define=VYTAL_PRIVACY_URL=https://<site>.netlify.app/privacy/
--dart-define=VYTAL_TERMS_URL=https://<site>.netlify.app/terms/
```

Until Netlify is connected, GitHub Pages URLs from PR #16 remain the app defaults.

## Still later (when the ring arrives)

- Pair QRing in Connected Mode
- Finish ASN/RTDN signed-payload verification → lifecycle mapping
- Create App Store / Play subscription + trainer products matching catalog SKUs
