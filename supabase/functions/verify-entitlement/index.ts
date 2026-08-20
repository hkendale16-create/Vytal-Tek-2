/**
 * Vytal Tek — verify-entitlement Edge Function.
 *
 * Auth: prefers user JWT. Sandbox receipts (platform=sandbox + sandbox.token.*)
 * can grant when the caller is signed in. Real Apple/Google receipts require
 * store credentials and still fail closed without them.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import {
  SUBSCRIPTION_PRODUCTS,
  entitlementSnapshot,
} from "./_shared/products.ts";
import { requireUserId, serviceClient } from "./_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, message: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ ok: false, message: "Invalid JSON" }, 400);
  }

  const receipt = body.receipt as Record<string, unknown> | undefined;
  if (!receipt || typeof receipt !== "object") {
    return jsonResponse({ ok: false, message: "Missing receipt" }, 400);
  }

  const productId = String(receipt.productId ?? "");
  const product = SUBSCRIPTION_PRODUCTS[productId];
  if (!product) {
    return jsonResponse({ ok: false, message: `Unknown product: ${productId}` }, 400);
  }

  const verificationData = String(receipt.verificationData ?? "");
  if (!verificationData) {
    return jsonResponse({ ok: false, message: "Missing verificationData" }, 400);
  }

  const platformRaw = String(receipt.platform ?? "unknown").toLowerCase();
  const platform = normalizePlatform(platformRaw);

  const auth = await requireUserId(req);
  if ("error" in auth) {
    // Keep verify_jwt=false for store clients, but refuse anonymous premium grants.
    return auth.error;
  }
  const userId = auth.userId;

  let verified = false;
  let verifyMessage = "";

  if (platform === "sandbox" && verificationData.startsWith("sandbox.token.")) {
    verified = true;
    verifyMessage = `Verified ${product.displayName} (authenticated sandbox).`;
  } else if (platform === "apple" || platformRaw.includes("apple")) {
    const apple = await verifyApple(verificationData);
    verified = apple.ok;
    verifyMessage = apple.message;
    if (!apple.ok && apple.status) {
      return jsonResponse({ ok: false, message: apple.message }, apple.status);
    }
  } else if (platform === "google" || platformRaw.includes("google")) {
    const google = await verifyGoogle(productId, verificationData);
    verified = google.ok;
    verifyMessage = google.message;
    if (!google.ok && google.status) {
      return jsonResponse({ ok: false, message: google.message }, google.status);
    }
  } else {
    return jsonResponse({
      ok: false,
      message: `Unsupported platform for verify: ${platformRaw}`,
    }, 400);
  }

  if (!verified) {
    return jsonResponse({
      ok: false,
      message: verifyMessage || "Purchase could not be verified. Premium was not granted.",
    }, 403);
  }

  const snapshot = entitlementSnapshot(product, "active");
  const admin = serviceClient();

  const { error: upsertError } = await admin.from("vytal_entitlements").upsert({
    user_id: userId,
    tier: product.tier,
    product_id: product.id,
    lifecycle: "active",
    will_renew: true,
    renews_at: snapshot.renewsAt,
    expires_at: snapshot.expiresAt,
    platform,
    original_transaction_id: String(receipt.purchaseId ?? verificationData).slice(0, 200),
    last_verified_at: new Date().toISOString(),
    snapshot,
    updated_at: new Date().toISOString(),
  });

  if (upsertError) {
    return jsonResponse({
      ok: false,
      message: `Verified but failed to persist: ${upsertError.message}`,
    }, 500);
  }

  await admin.from("vytal_purchase_events").insert({
    user_id: userId,
    platform,
    product_id: product.id,
    event_type: "verify_ok",
    payload: { receipt, snapshot },
  });

  return jsonResponse({
    ok: true,
    message: verifyMessage,
    entitlements: snapshot,
  });
});

function normalizePlatform(raw: string): string {
  if (raw.includes("apple") || raw.includes("storekit")) return "apple";
  if (raw.includes("google") || raw.includes("play")) return "google";
  if (raw.includes("sandbox")) return "sandbox";
  return "unknown";
}

async function verifyApple(
  signedTransaction: string,
): Promise<{ ok: boolean; message: string; status?: number }> {
  const issuer = Deno.env.get("APPLE_ISSUER_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.vytaltek.mobile";
  if (!issuer || !keyId || !privateKey) {
    return {
      ok: false,
      status: 503,
      message:
        "Apple App Store credentials are not configured. Premium was not granted.",
    };
  }

  try {
    const token = await appleApiToken(issuer, keyId, privateKey, bundleId);
    const txId = extractAppleTransactionId(signedTransaction);
    if (!txId) {
      return {
        ok: false,
        status: 400,
        message: "Could not resolve Apple transaction id from verificationData",
      };
    }
    const env = Deno.env.get("APPLE_API_ENV") === "production"
      ? "https://api.storekit.itunes.apple.com"
      : "https://api.storekit-sandbox.itunes.apple.com";
    const res = await fetch(`${env}/inApps/v1/transactions/${txId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      return {
        ok: false,
        status: 403,
        message: `Apple verify failed (${res.status})`,
      };
    }
    return { ok: true, message: "Verified with App Store Server API" };
  } catch (e) {
    return {
      ok: false,
      status: 501,
      message: `Apple verify handler error: ${e}`,
    };
  }
}

async function verifyGoogle(
  productId: string,
  purchaseToken: string,
): Promise<{ ok: boolean; message: string; status?: number }> {
  const saJson = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME") ??
    "com.vytaltek.mobile";
  if (!saJson) {
    return {
      ok: false,
      status: 503,
      message:
        "Google Play credentials are not configured. Premium was not granted.",
    };
  }
  try {
    const accessToken = await googleAccessToken(saJson);
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
      return {
        ok: false,
        status: 403,
        message: `Google verify failed (${res.status})`,
      };
    }
    return { ok: true, message: "Verified with Google Play Developer API" };
  } catch (e) {
    return {
      ok: false,
      status: 501,
      message: `Google verify handler error: ${e}`,
    };
  }
}

function extractAppleTransactionId(verificationData: string): string | null {
  // StoreKit 2 often sends JWS; use middle payload transactionId when possible.
  const parts = verificationData.split(".");
  if (parts.length >= 2) {
    try {
      const json = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
      if (typeof json.transactionId === "string") return json.transactionId;
      if (typeof json.originalTransactionId === "string") {
        return json.originalTransactionId;
      }
    } catch {
      // fall through
    }
  }
  if (/^[0-9]+$/.test(verificationData)) return verificationData;
  return null;
}

async function appleApiToken(
  issuer: string,
  keyId: string,
  privateKeyPem: string,
  bundleId: string,
): Promise<string> {
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: issuer,
    iat: now,
    exp: now + 1500,
    aud: "appstoreconnect-v1",
    bid: bundleId,
  };
  return await signJwtEs256(header, payload, privateKeyPem);
}

async function googleAccessToken(saJson: string): Promise<string> {
  const sa = JSON.parse(saJson) as {
    client_email: string;
    private_key: string;
    token_uri?: string;
  };
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signJwtRs256(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: sa.token_uri ?? "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    sa.private_key,
  );
  const res = await fetch(sa.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`Google token exchange ${res.status}`);
  const json = await res.json();
  return String(json.access_token);
}

async function signJwtEs256(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  pem: string,
): Promise<string> {
  const enc = new TextEncoder();
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuf(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    enc.encode(data),
  );
  return `${data}.${b64url(sig)}`;
}

async function signJwtRs256(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  pem: string,
): Promise<string> {
  const enc = new TextEncoder();
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuf(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(data));
  return `${data}.${b64url(sig)}`;
}

function pemToBuf(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

function b64url(input: string | ArrayBuffer): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
