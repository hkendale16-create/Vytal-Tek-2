/**
 * Google Play Real-time Developer Notifications.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import { serviceClient } from "./_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, message: "Method not allowed" }, 405);
  }

  if (!Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")) {
    return jsonResponse({
      ok: false,
      message: "Google Play credentials not configured",
    }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ ok: false, message: "Invalid JSON" }, 400);
  }

  const admin = serviceClient();
  await admin.from("vytal_purchase_events").insert({
    user_id: null,
    platform: "google",
    product_id: null,
    event_type: "google_rtdn_received",
    payload: body,
  });

  return jsonResponse({
    ok: true,
    message:
      "RTDN accepted for audit. Pub/Sub message verification + entitlement mapping pending full Play wiring.",
  });
});
