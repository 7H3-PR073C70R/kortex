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

    // Execute true PostgreSQL weighted weekly leaderboard aggregation RPC
    const { error: rpcError } = await supabase.rpc("aggregate_weekly_leaderboards");
    if (rpcError) {
      throw rpcError;
    }

    // Retrieve summary of updated leaderboards
    const { count, error: countError } = await supabase
      .from("leaderboards")
      .select("*", { count: "exact", head: true });

    if (countError) {
      console.warn("Could not fetch leaderboard count:", countError);
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
