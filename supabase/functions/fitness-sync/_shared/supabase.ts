import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function userClient(authHeader: string): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
  }
  return createClient(url, anon, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Returns auth user id when Bearer JWT is a real user access token. */
export async function requireUserId(
  req: Request,
): Promise<{ userId: string } | { error: Response }> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return {
      error: jsonError("Sign in required", 401),
    };
  }
  const token = auth.slice(7).trim();
  if (!token || token === Deno.env.get("SUPABASE_ANON_KEY")) {
    return { error: jsonError("Sign in required — user JWT missing", 401) };
  }
  const client = userClient(auth);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    return { error: jsonError("Invalid or expired session", 401) };
  }
  return { userId: data.user.id };
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ ok: false, message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
