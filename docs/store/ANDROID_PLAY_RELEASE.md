# Android Play release

## Build

```bash
cd apps/mobile
cp android/key.properties.example android/key.properties
# fill storeFile / passwords, then:
flutter build appbundle --release \
  --dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement
```

Output: `build/app/outputs/bundle/release/app-release.aab`

For sideload testing:

```bash
flutter build apk --release \
  --dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement
```

## Signing

- Never commit `android/key.properties` or `*.jks` / `*.keystore`.
- Release signing is loaded from `android/key.properties` when present; otherwise falls back to debug (not for Play).

## Wearable stack

Android uses HBand / Veepoo (`third_party/hband/`, `HBandSdkHost`). Default device password in the host is `0000`.
