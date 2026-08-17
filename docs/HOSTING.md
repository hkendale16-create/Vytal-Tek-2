# Vytal Tek hosting

## Supabase (live)

Dedicated project **Vytal Tek** (not FirstVue):

| | |
|---|---|
| Ref | `sdeifrzdkiiexawwzfvb` |
| URL | https://sdeifrzdkiiexawwzfvb.supabase.co |
| Dashboard | https://supabase.com/dashboard/project/sdeifrzdkiiexawwzfvb |
| Verify | `POST /functions/v1/verify-entitlement` |

The verifier **fails closed** until Apple/Google secrets are set on the function. RLS is on; users can only SELECT their own rows. Writes are service-role only.

Release Flutter builds call this URL (debug still uses the sandbox mock verifier).

```bash
flutter run \
  --dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement \
  --dart-define=VYTAL_SUPABASE_PUBLISHABLE_KEY=sb_publishable_0Afaq57w4OzpNTGVVV3o4A_EvNk7COE
```

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
- Add App Store / Play products + store secrets on the Edge Function
