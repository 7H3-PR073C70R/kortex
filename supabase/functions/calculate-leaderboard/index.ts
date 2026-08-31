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

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Mock/Synthesized leaderboard updates across tracks (WAEC, JAMB, SAT, Engineering, Medicine)
    const mockStandings = [
      {
        user_name: "Adeola Vance",
        track: "JAMB",
        daily_xp: 320,
        weekly_xp: 2450,
        streak_days: 14,
        rank: 1,
      },
      {
        user_name: "Chukwudi Okafor",
        track: "WAEC",
        daily_xp: 290,
        weekly_xp: 2180,
        streak_days: 11,
        rank: 2,
      },
      {
        user_name: "Elena Rostova",
        track: "SAT",
        daily_xp: 260,
        weekly_xp: 1950,
        streak_days: 9,
        rank: 3,
      },
      {
        user_name: "Tariq Mansour",
        track: "Engineering",
        daily_xp: 210,
        weekly_xp: 1680,
        streak_days: 7,
        rank: 4,
      },
      {
        user_name: "Zainab Bello",
        track: "Medicine",
        daily_xp: 190,
        weekly_xp: 1540,
        streak_days: 6,
        rank: 5,
      },
    ];

    for (const standing of mockStandings) {
      await supabase.from("leaderboards").upsert(
        {
          user_name: standing.user_name,
          track: standing.track,
          daily_xp: standing.daily_xp,
          weekly_xp: standing.weekly_xp,
          streak_days: standing.streak_days,
          rank: standing.rank,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_name" }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Leaderboard rankings updated successfully",
        count: mockStandings.length,
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
