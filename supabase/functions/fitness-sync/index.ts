/**
 * Cloud sync receiver — accepts queued workout POSTs from the mobile client.
 * Requires user JWT. Idempotent on (user_id, client_event_id).
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, optionsResponse } from "./_shared/http.ts";
import { requireUserId, serviceClient } from "./_shared/supabase.ts";

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

  const events = body.events;
  if (!Array.isArray(events)) {
    return jsonResponse({ ok: false, message: "Missing events array" }, 400);
  }
  if (events.length > 100) {
    return jsonResponse({ ok: false, message: "Batch too large (max 100)" }, 400);
  }

  const admin = serviceClient();
  const { data: batch, error: batchError } = await admin
    .from("fitness_sync_batches")
    .insert({
      user_id: auth.userId,
      source: String(body.source ?? "vytal_tek_mobile"),
      event_count: events.length,
      raw: body,
    })
    .select("id")
    .single();

  if (batchError || !batch) {
    return jsonResponse({
      ok: false,
      message: batchError?.message ?? "Failed to create batch",
    }, 500);
  }

  let accepted = 0;
  let duplicates = 0;
  for (const raw of events) {
    const event = raw as Record<string, unknown>;
    const clientEventId = String(event.id ?? "");
    const kind = String(event.kind ?? "unknown");
    if (!clientEventId) continue;
    const payload = (event.payload as Record<string, unknown>) ?? event;
    const { error } = await admin.from("fitness_sync_events").insert({
      batch_id: batch.id,
      user_id: auth.userId,
      client_event_id: clientEventId,
      kind,
      queued_at: event.queuedAt ?? null,
      payload,
    });
    if (error) {
      if (String(error.message).includes("duplicate") || error.code === "23505") {
        duplicates += 1;
      } else {
        return jsonResponse({
          ok: false,
          message: `Event insert failed: ${error.message}`,
          accepted,
          duplicates,
        }, 500);
      }
    } else {
      accepted += 1;
    }
  }

  return jsonResponse({
    ok: true,
    message: `Accepted ${accepted} event(s)`,
    batchId: batch.id,
    accepted,
    duplicates,
    remainingCount: 0,
  });
});
