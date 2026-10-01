import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    const customCronHeader = req.headers.get("X-Cron-Secret") ?? "";

    const isServiceRole =
      supabaseServiceKey &&
      authHeader.replace(/^Bearer\s+/i, "").trim() === supabaseServiceKey;
    const isCronMatch =
      cronSecret &&
      (customCronHeader === cronSecret ||
        authHeader.replace(/^Bearer\s+/i, "").trim() === cronSecret);

    if (!isServiceRole && !isCronMatch) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Restricted to scheduled background cron jobs" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { error: rpcError } = await supabase.rpc("aggregate_weekly_leaderboards");
    if (rpcError) {
      throw rpcError;
    }

    const { count, error: countError } = await supabase
      .from("leaderboards")
      .select("*", { count: "exact", head: true });

    if (countError) {
      console.warn("Could not fetch leaderboard count:", countError);
    }

    // Award podium notifications to the top 3 scholars of the week
    try {
      const { data: topScholars } = await supabase
        .from("leaderboards")
        .select("user_id, rank, total_xp, display_name")
        .order("rank", { ascending: true })
        .limit(3);

      if (topScholars && topScholars.length > 0) {
        const medals = ["🥇", "🥈", "🥉"];
        const inserts = topScholars.map((s, idx) => ({
          user_id: s.user_id,
          title: `${medals[idx] || "🏆"} Weekly Podium: Rank #${s.rank}!`,
          body: `Incredible work! You earned ${s.total_xp} XP this week and finished in the top 3 scholars on the global leaderboard.`,
          category: "leaderboard",
          data: {
            route: "/leaderboard",
            rank: String(s.rank),
            totalXp: String(s.total_xp),
          },
        }));

        await supabase.from("notifications").insert(inserts);

        // Immediately trigger outbox processing to deliver FCM pushes
        try {
          await fetch(`${supabaseUrl}/functions/v1/trigger-notifications`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${supabaseServiceKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ action: "process_outbox" }),
          });
        } catch (_) {}
      }
    } catch (topErr) {
      console.warn("[Leaderboard] Failed to notify top scholars:", topErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Quality-weighted weekly leaderboard rankings aggregated successfully",
        totalRankedUsers: count ?? 0,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? "Server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
