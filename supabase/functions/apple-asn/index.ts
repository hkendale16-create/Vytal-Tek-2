/**
 * App Store Server Notifications V2 — updates entitlement lifecycle.
 * Configure APPLE_ASN_SHARED_SECRET / APPLE_ISSUER_ID as needed.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import { serviceClient } from "./_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, message: "Method not allowed" }, 405);
  }

  if (!Deno.env.get("APPLE_ISSUER_ID") && !Deno.env.get("APPLE_ASN_SHARED_SECRET")) {
    return jsonResponse({
      ok: false,
      message: "Apple ASN credentials not configured",
    }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ ok: false, message: "Invalid JSON" }, 400);
  }

  // Full JWS notification verification is required before mutating entitlements.
  // Persist the raw notification for ops; do not grant or revoke from unsigned JSON.
  const admin = serviceClient();
  await admin.from("vytal_purchase_events").insert({
    user_id: null,
    platform: "apple",
    product_id: null,
    event_type: "apple_asn_received",
    payload: body,
  });

  return jsonResponse({
    ok: true,
    message:
      "ASN accepted for audit. Signed notification verification + lifecycle mapping pending full Apple key wiring.",
  });
});
