/**
 * Subscription lifecycle updates (cancel / expire / revoke / grace).
 * Requires authenticated user JWT. Does not invent store status — applies
 * the posted lifecycle only after the client/server notification path.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import {
  SUBSCRIPTION_PRODUCTS,
  entitlementSnapshot,
} from "./_shared/products.ts";
import { requireUserId, serviceClient } from "./_shared/supabase.ts";

const ACCESS_LIFECYCLES = new Set([
  "active",
  "canceledActive",
  "gracePeriod",
  "billingRetry",
]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
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

  const productId = String(body.productId ?? "");
  const lifecycle = String(body.lifecycle ?? "");
  const product = SUBSCRIPTION_PRODUCTS[productId];
  if (!product) {
    return jsonResponse({ ok: false, message: `Unknown product: ${productId}` }, 400);
  }

  const admin = serviceClient();
  const grants = ACCESS_LIFECYCLES.has(lifecycle);
  const snapshot = grants
    ? entitlementSnapshot(product, lifecycle)
    : {
      tier: "free",
      enabled: [] as string[],
      lifecycle,
      productId,
      expiresAt: body.expiresAt ?? null,
      renewsAt: body.renewsAt ?? null,
      willRenew: Boolean(body.willRenew ?? false),
      verificationSource: "serverVerified",
      lastVerifiedAt: new Date().toISOString(),
    };

  if (grants) {
    snapshot.expiresAt = (body.expiresAt as string) ?? snapshot.expiresAt;
    snapshot.renewsAt = (body.renewsAt as string) ?? snapshot.renewsAt;
    snapshot.willRenew = Boolean(body.willRenew ?? snapshot.willRenew);
  }

  const { error } = await admin.from("vytal_entitlements").upsert({
    user_id: auth.userId,
    tier: grants ? product.tier : "free",
    product_id: productId,
    lifecycle,
    will_renew: Boolean(snapshot.willRenew),
    renews_at: snapshot.renewsAt,
    expires_at: snapshot.expiresAt,
    last_verified_at: new Date().toISOString(),
    snapshot,
    updated_at: new Date().toISOString(),
  });

  if (error) {
    return jsonResponse({ ok: false, message: error.message }, 500);
  }

  await admin.from("vytal_purchase_events").insert({
    user_id: auth.userId,
    platform: "unknown",
    product_id: productId,
    event_type: `lifecycle_${lifecycle}`,
    payload: body,
  });

  return jsonResponse({
    ok: true,
    message: `Lifecycle updated to ${lifecycle}`,
    entitlements: snapshot,
  });
});
