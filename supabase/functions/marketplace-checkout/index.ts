/**
 * Trainer marketplace checkout + interest.
 *
 * POST actions:
 * - interest: { action: "interest", programId }
 * - checkout: { action: "checkout", programId, receipt? }
 *
 * Free/preview programs (price_cents=0) settle immediately with fee ledger = 0.
 * Paid programs require sandbox.token.* or store receipt; Apple/Google store
 * verification for trainer SKUs reuses the same fail-closed store credential gate.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import { requireUserId, serviceClient } from "./_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method === "GET") {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("trainer_programs")
      .select("*")
      .eq("active", true)
      .order("title");
    if (error) return jsonResponse({ ok: false, message: error.message }, 500);
    return jsonResponse({ ok: true, programs: data ?? [] });
  }
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, message: "Method not allowed" }, 405);
  }

  const auth = await requireUserId(req);
  if ("error" in auth) return auth.error;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ ok: false, message: "Invalid JSON" }, 400);
  }

  const action = String(body.action ?? "checkout");
  const programId = String(body.programId ?? "");
  if (!programId) {
    return jsonResponse({ ok: false, message: "Missing programId" }, 400);
  }

  const admin = serviceClient();
  const { data: program, error: programError } = await admin
    .from("trainer_programs")
    .select("*")
    .eq("id", programId)
    .eq("active", true)
    .maybeSingle();

  if (programError || !program) {
    return jsonResponse({ ok: false, message: "Program not found" }, 404);
  }

  if (action === "interest") {
    const { error } = await admin.from("trainer_program_interest").upsert({
      user_id: auth.userId,
      program_id: programId,
    });
    if (error) return jsonResponse({ ok: false, message: error.message }, 500);
    return jsonResponse({
      ok: true,
      message: "Interest recorded",
      programId,
    });
  }

  if (action !== "checkout") {
    return jsonResponse({ ok: false, message: `Unknown action: ${action}` }, 400);
  }

  const priceCents = Number(program.price_cents ?? 0);
  const feeBps = Number(program.platform_fee_bps ?? 1000);
  const receipt = body.receipt as Record<string, unknown> | undefined;
  const platform = String(receipt?.platform ?? body.platform ?? "sandbox");
  const token = String(
    receipt?.verificationData ?? body.purchaseToken ?? `preview.${programId}`,
  );

  if (priceCents > 0) {
    const okStore = await assertPaidReceipt(platform, token);
    if (!okStore.ok) {
      return jsonResponse({ ok: false, message: okStore.message }, okStore.status ?? 403);
    }
  }

  const feeCents = Math.round((priceCents * feeBps) / 10000);
  const trainerNet = Math.max(0, priceCents - feeCents);

  const { data: purchase, error: purchaseError } = await admin
    .from("trainer_purchases")
    .upsert({
      user_id: auth.userId,
      program_id: programId,
      store_product_id: program.store_product_id,
      platform,
      purchase_token: token,
      status: "paid",
      gross_cents: priceCents,
      platform_fee_bps: feeBps,
      platform_fee_cents: feeCents,
      trainer_net_cents: trainerNet,
      currency: program.currency ?? "usd",
      verified_at: new Date().toISOString(),
    }, { onConflict: "user_id,program_id,purchase_token" })
    .select("id")
    .single();

  if (purchaseError || !purchase) {
    return jsonResponse({
      ok: false,
      message: purchaseError?.message ?? "Purchase persist failed",
    }, 500);
  }

  if (feeCents > 0) {
    await admin.from("platform_fee_ledger").insert({
      purchase_id: purchase.id,
      user_id: auth.userId,
      program_id: programId,
      fee_cents: feeCents,
      currency: program.currency ?? "usd",
      settled: false,
    });
  }

  return jsonResponse({
    ok: true,
    message: priceCents === 0
      ? "Preview unlocked — no charge"
      : "Purchase recorded — platform fee ledgered",
    purchaseId: purchase.id,
    programId,
    grossCents: priceCents,
    platformFeeBps: feeBps,
    platformFeeCents: feeCents,
    trainerNetCents: trainerNet,
    charged: priceCents > 0,
  });
});

async function assertPaidReceipt(
  platform: string,
  token: string,
): Promise<{ ok: boolean; message: string; status?: number }> {
  if (platform.toLowerCase().includes("sandbox") && token.startsWith("sandbox.token.")) {
    return { ok: true, message: "sandbox" };
  }
  const appleReady = Boolean(Deno.env.get("APPLE_ISSUER_ID"));
  const googleReady = Boolean(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"));
  if (!appleReady && !googleReady) {
    return {
      ok: false,
      status: 503,
      message:
        "Paid trainer checkout requires store credentials or an authenticated sandbox receipt.",
    };
  }
  // Store-specific trainer SKU verification lands with the same Apple/Google
  // handlers used by verify-entitlement once products exist in the consoles.
  return {
    ok: false,
    status: 501,
    message:
      "Store credentials present but trainer SKU verification is not wired yet. Use sandbox.token.* for drills.",
  };
}
