import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { AccessToken } from "npm:livekit-server-sdk@^2.6.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TokenRequestPayload {
  room_id?: string;
  roomId?: string;
  user_id?: string;
  userId?: string;
  username?: string;
  isVoicePodEnabled?: boolean;
  is_voice_pod?: boolean;
  canPublish?: boolean;
}

interface RoomAccessResult {
  allowed: boolean;
  error?: string;
  room_type?: string;
  can_publish?: boolean;
  display_name?: string;
  role?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Bearer token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired session token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authenticatedUserId = user.id;

    const body: TokenRequestPayload = await req.json().catch(() => ({}));
    const roomId = (body.room_id || body.roomId || "").trim();
    const requestedUserId = (body.user_id || body.userId || "").trim();

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return new Response(
        JSON.stringify({ error: "Forbidden: Cannot generate token for another user identity" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!roomId) {
      return new Response(
        JSON.stringify({ error: "roomId is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Server-authoritative room membership and permission check
    const dbClient = supabaseServiceKey
      ? createClient(supabaseUrl, supabaseServiceKey)
      : authClient;

    const { data: accessData, error: rpcError } = await dbClient.rpc(
      "check_livekit_room_access",
      {
        p_room_id: roomId,
        p_user_id: authenticatedUserId,
      }
    );

    if (rpcError) {
      console.error("[generate-livekit-token] Access check RPC error:", rpcError);
      return new Response(
        JSON.stringify({ error: "Failed to verify room permissions" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessResult = accessData as RoomAccessResult | null;
    if (!accessResult || !accessResult.allowed) {
      return new Response(
        JSON.stringify({
          error: accessResult?.error || "Forbidden: You are not authorized to access this room",
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Determine authoritative display name and publishing privileges server-side
    const displayName = accessResult.display_name || "Scholar";
    const serverCanPublish = Boolean(accessResult.can_publish);
    // Client can opt-in to listen-only (canPublish === false), but cannot override server restrictions
    const canPublishAudio = serverCanPublish && (body.canPublish !== false);

    const apiKey =
      Deno.env.get("LIVEKIT_API_KEY") ||
      Deno.env.get("LIVEKIT_KEY");
    const apiSecret =
      Deno.env.get("LIVEKIT_API_SECRET") ||
      Deno.env.get("LIVEKIT_SECRET");

    if (!apiKey || !apiSecret) {
      return new Response(
        JSON.stringify({
          error: "LiveKit server credentials are not configured on the backend.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const at = new AccessToken(apiKey, apiSecret, {
      identity: authenticatedUserId,
      name: displayName,
      ttl: "6h",
    });

    at.addGrant({
      roomJoin: true,
      room: roomId,
      canPublish: canPublishAudio,
      canSubscribe: true,
      canPublishData: true,
    });

    const livekitToken = await at.toJwt();

    return new Response(
      JSON.stringify({
        token: livekitToken,
        roomId,
        userId: authenticatedUserId,
        displayName,
        canPublish: canPublishAudio,
        role: accessResult.role || "participant",
        roomType: accessResult.room_type,
        expiresIn: 21600,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message ?? "Failed to generate LiveKit token" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
