import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: TokenRequestPayload = await req.json().catch(() => ({}));
    const roomId = body.room_id || body.roomId;
    const userId = body.user_id || body.userId;
    const username = body.username || userId || "Scholar";

    if (!roomId || !userId) {
      return new Response(
        JSON.stringify({ error: "room_id and user_id are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const apiKey =
      Deno.env.get("LIVEKIT_API_KEY") ||
      Deno.env.get("LIVEKIT_KEY") ||
      "API4koii3DrgtqG";
    const apiSecret =
      Deno.env.get("LIVEKIT_API_SECRET") ||
      Deno.env.get("LIVEKIT_SECRET") ||
      "R6eBpJNJqD4nnCzDxAJyn7fFQPAb2Hw0MkemmBHgDreD";

    const at = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      name: username,
      ttl: "6h",
    });

    at.addGrant({
      roomJoin: true,
      room: roomId,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();

    return new Response(
      JSON.stringify({
        token,
        roomId,
        userId,
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
