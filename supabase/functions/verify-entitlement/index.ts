/**
 * Vytal Tek — verify-entitlement Edge Function.
 * Fails closed until Apple / Google store credentials are configured.
 * Never grants premium from client-shaped payloads.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ALLOWED_PRODUCTS = new Set([
  "vytal.plus.monthly",
  "vytal.pro.monthly",
]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors() });
  }
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
    return json({ ok: false, message: `Unknown product: ${productId}` }, 400);
  }

  const verificationData = String(receipt.verificationData ?? "");
  if (!verificationData) {
    return json({ ok: false, message: "Missing verificationData" }, 400);
  }

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

  return json({
    ok: false,
    message:
      "Store credential env present but Apple/Google verify handlers are not " +
      "implemented yet. Premium was not granted.",
  }, 501);
});

function cors(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...cors(),
      "Content-Type": "application/json",
      "Connection": "keep-alive",
    },
  });
}
