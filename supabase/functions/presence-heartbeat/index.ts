import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface PresenceHeartbeatPayload {
  action?: "heartbeat" | "query" | "leave";
  userId?: string;
  roomId: string;
  username?: string;
  avatarUrl?: string;
  focusStatus?: string;
  activeCursor?: Record<string, unknown>;
  timerState?: Record<string, unknown>;
}

// In-memory Redis simulation fallback if Upstash credentials are not set
const memoryPresenceStore = new Map<
  string,
  { payload: Record<string, unknown>; expiresAt: number }
>();

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const body: PresenceHeartbeatPayload =
      req.method === "POST" ? await req.json().catch(() => ({})) : ({} as any);

    const action = body.action || (req.method === "GET" ? "query" : "heartbeat");
    const roomId = body.roomId || url.searchParams.get("roomId") || "";
    const userId = body.userId || url.searchParams.get("userId") || "";

    if (!roomId) {
      return new Response(
        JSON.stringify({ error: "roomId is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const upstashUrl = Deno.env.get("UPSTASH_REDIS_REST_URL");
    const upstashToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");

    if (action === "heartbeat") {
      if (!userId) {
        return new Response(
          JSON.stringify({ error: "userId is required for heartbeat" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const presenceData = {
        userId,
        roomId,
        username: body.username || "Scholar",
        avatarUrl: body.avatarUrl,
        focusStatus: body.focusStatus || "active",
        activeCursor: body.activeCursor,
        timerState: body.timerState,
        lastHeartbeat: new Date().toISOString(),
      };

      const key = `user:${userId}:presence:room:${roomId}`;

      if (upstashUrl && upstashToken) {
        // Set key with 30s sliding TTL in Upstash Redis
        await fetch(`${upstashUrl}/pipeline`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${upstashToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify([
            ["SET", key, JSON.stringify(presenceData), "EX", 30],
            ["SADD", `room:${roomId}:members`, userId],
          ]),
        });
      } else {
        // Local in-memory sliding TTL (30 seconds)
        memoryPresenceStore.set(key, {
          payload: presenceData,
          expiresAt: Date.now() + 30000,
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          status: "active",
          ttlSeconds: 30,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (action === "leave") {
      const key = `user:${userId}:presence:room:${roomId}`;
      if (upstashUrl && upstashToken) {
        await fetch(`${upstashUrl}/pipeline`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${upstashToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify([
            ["DEL", key],
            ["SREM", `room:${roomId}:members`, userId],
          ]),
        });
      } else {
        memoryPresenceStore.delete(key);
      }

      return new Response(
        JSON.stringify({ success: true, status: "left" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Query active room presence
    const activeMembers: Record<string, unknown>[] = [];

    if (upstashUrl && upstashToken) {
      const membersRes = await fetch(
        `${upstashUrl}/smembers/room:${roomId}:members`,
        {
          headers: { Authorization: `Bearer ${upstashToken}` },
        }
      );
      if (membersRes.ok) {
        const membersData = await membersRes.json();
        const userIds: string[] = membersData.result || [];

        if (userIds.length > 0) {
          const keys = userIds.map((id) => `user:${id}:presence:room:${roomId}`);
          const mgetRes = await fetch(`${upstashUrl}/mget/${keys.join("/")}`, {
            headers: { Authorization: `Bearer ${upstashToken}` },
          });

          if (mgetRes.ok) {
            const mgetData = await mgetRes.json();
            const results: (string | null)[] = mgetData.result || [];
            results.forEach((item) => {
              if (item) {
                try {
                  activeMembers.push(JSON.parse(item));
                } catch (_) {}
              }
            });
          }
        }
      }
    } else {
      const now = Date.now();
      for (const [key, val] of memoryPresenceStore.entries()) {
        if (key.includes(`:room:${roomId}`)) {
          if (val.expiresAt > now) {
            activeMembers.push(val.payload);
          } else {
            memoryPresenceStore.delete(key);
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        roomId,
        activeMembers,
        count: activeMembers.length,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message ?? "Presence heartbeat error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
