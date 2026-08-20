/**
 * Gym partner pipeline — claims, membership offers, sponsored inventory.
 *
 * POST actions (user JWT):
 * - claim: { action: "claim", placeId, businessName, contactEmail? }
 * - my_claims: { action: "my_claims" }
 *
 * POST actions (partner key header x-vytal-partner-key):
 * - review: { action: "review", claimId, status: approved|rejected, partner?, promoted?, offer? }
 * - sponsor: { action: "sponsor", placeId, active?, label? }
 *
 * GET: public offers + sponsored placements for placeIds=? comma list
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import { requireUserId, serviceClient } from "./_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();

  const admin = serviceClient();

  if (req.method === "GET") {
    const url = new URL(req.url);
    const placeIds = (url.searchParams.get("placeIds") ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    let offersQuery = admin
      .from("gym_membership_offers")
      .select("*")
      .eq("active", true);
    let sponsoredQuery = admin
      .from("gym_sponsored_placements")
      .select("*")
      .eq("active", true);

    if (placeIds.length > 0) {
      offersQuery = offersQuery.in("place_id", placeIds);
      sponsoredQuery = sponsoredQuery.in("place_id", placeIds);
    }

    const [offers, sponsored] = await Promise.all([offersQuery, sponsoredQuery]);
    if (offers.error) {
      return jsonResponse({ ok: false, message: offers.error.message }, 500);
    }
    if (sponsored.error) {
      return jsonResponse({ ok: false, message: sponsored.error.message }, 500);
    }
    return jsonResponse({
      ok: true,
      offers: offers.data ?? [],
      sponsored: sponsored.data ?? [],
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ ok: false, message: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ ok: false, message: "Invalid JSON" }, 400);
  }

  const action = String(body.action ?? "");
  const partnerKey = req.headers.get("x-vytal-partner-key") ?? "";
  const expectedPartner = Deno.env.get("VYTAL_PARTNER_REVIEW_KEY") ?? "";

  if (action === "review" || action === "sponsor") {
    if (!expectedPartner || partnerKey !== expectedPartner) {
      return jsonResponse({ ok: false, message: "Partner key required" }, 401);
    }
    if (action === "sponsor") {
      const placeId = String(body.placeId ?? "");
      if (!placeId) {
        return jsonResponse({ ok: false, message: "Missing placeId" }, 400);
      }
      const { error } = await admin.from("gym_sponsored_placements").upsert({
        place_id: placeId,
        label: String(body.label ?? "Sponsored"),
        active: body.active !== false,
      }, { onConflict: "place_id" });
      if (error) return jsonResponse({ ok: false, message: error.message }, 500);
      return jsonResponse({
        ok: true,
        message: "Sponsored placement upserted",
        placeId,
        labeled: "Sponsored",
      });
    }

    const claimId = String(body.claimId ?? "");
    const status = String(body.status ?? "");
    if (!claimId || !["approved", "rejected"].includes(status)) {
      return jsonResponse({
        ok: false,
        message: "claimId and status=approved|rejected required",
      }, 400);
    }
    const partner = body.partner !== false;
    const promoted = Boolean(body.promoted);
    const { data: claim, error } = await admin
      .from("gym_claims")
      .update({
        status,
        verified: status === "approved",
        partner: status === "approved" ? partner : false,
        promoted: status === "approved" ? promoted : false,
        reviewed_at: new Date().toISOString(),
        reviewed_by: "partner_pipeline",
        review_notes: body.notes ? String(body.notes) : null,
      })
      .eq("id", claimId)
      .select("*")
      .single();
    if (error || !claim) {
      return jsonResponse({
        ok: false,
        message: error?.message ?? "Claim not found",
      }, 404);
    }

    if (status === "approved" && body.offer && typeof body.offer === "object") {
      const offer = body.offer as Record<string, unknown>;
      await admin.from("gym_membership_offers").insert({
        place_id: claim.place_id,
        claim_id: claim.id,
        title: String(offer.title ?? "Member offer"),
        description: String(offer.description ?? ""),
        price_label: offer.priceLabel ? String(offer.priceLabel) : null,
        active: true,
      });
    }

    if (status === "approved" && promoted) {
      await admin.from("gym_sponsored_placements").upsert({
        place_id: claim.place_id,
        label: "Sponsored",
        active: true,
      }, { onConflict: "place_id" });
    }

    return jsonResponse({ ok: true, message: `Claim ${status}`, claim });
  }

  const auth = await requireUserId(req);
  if ("error" in auth) return auth.error;

  if (action === "my_claims") {
    const { data, error } = await admin
      .from("gym_claims")
      .select("*")
      .eq("user_id", auth.userId)
      .order("requested_at", { ascending: false });
    if (error) return jsonResponse({ ok: false, message: error.message }, 500);
    return jsonResponse({ ok: true, claims: data ?? [] });
  }

  if (action === "claim") {
    const placeId = String(body.placeId ?? "");
    const businessName = String(body.businessName ?? "").trim();
    if (!placeId || !businessName) {
      return jsonResponse({
        ok: false,
        message: "placeId and businessName required",
      }, 400);
    }
    const { data, error } = await admin.from("gym_claims").upsert({
      place_id: placeId,
      user_id: auth.userId,
      business_name: businessName,
      contact_email: body.contactEmail ? String(body.contactEmail) : null,
      status: "pending",
      verified: false,
      partner: false,
      promoted: false,
      requested_at: new Date().toISOString(),
    }, { onConflict: "place_id,user_id" }).select("*").single();
    if (error || !data) {
      return jsonResponse({
        ok: false,
        message: error?.message ?? "Claim failed",
      }, 500);
    }
    return jsonResponse({
      ok: true,
      message: "Claim submitted for partner review",
      claim: data,
    });
  }

  return jsonResponse({ ok: false, message: `Unknown action: ${action}` }, 400);
});
