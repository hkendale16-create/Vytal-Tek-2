/**
 * Vytal Tek — verify-entitlement Edge Function (Phase G stub).
 *
 * Fails closed until Apple App Store Server API / Google Play Developer API
 * credentials are configured. Never grant premium from client-shaped payloads.
 *
 * Deploy (after creating a Vytal Supabase project):
 *   supabase functions deploy verify-entitlement --project-ref <ref>
 *
 * verify_jwt: false only if you authenticate via store receipt signatures
 * instead of user JWT; prefer JWT + receipt binding in production.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ALLOWED_PRODUCTS = new Set([
  "vytal.plus.monthly",
  "vytal.pro.monthly",
]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ ok: false, message: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, message: "Invalid JSON" }, 400);
  }

  const receipt = body.receipt as Record<string, unknown> | undefined;
  if (!receipt || typeof receipt !== "object") {
    return json({ ok: false, message: "Missing receipt" }, 400);
  }

  const productId = String(receipt.productId ?? "");
  if (!ALLOWED_PRODUCTS.has(productId)) {
    return json({
      ok: false,
      message: `Unknown product: ${productId}`,
    }, 400);
  }

  const verificationData = String(receipt.verificationData ?? "");
  if (!verificationData) {
    return json({ ok: false, message: "Missing verificationData" }, 400);
  }

  // Production: verify with Apple / Google using platform secrets.
  // Stub intentionally refuses until those integrations are live.
  const appleReady = Boolean(Deno.env.get("APPLE_ISSUER_ID"));
  const googleReady = Boolean(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"));
  if (!appleReady && !googleReady) {
    return json({
      ok: false,
      message:
        "Entitlement verifier is not configured with store credentials. " +
        "Premium was not granted.",
    }, 503);
  }

  // Placeholder for store verification + authoritative snapshot write.
  return json({
    ok: false,
    message:
      "Store credential env present but Apple/Google verify handlers are not " +
      "implemented yet. Premium was not granted.",
  }, 501);
});

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Connection": "keep-alive",
    },
  });
}
