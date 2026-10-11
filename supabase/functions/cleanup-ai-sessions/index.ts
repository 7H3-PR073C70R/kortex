import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { timingSafeEqualString } from "../_shared/security_guard.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
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

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    // Constant-time check for privileged service role or cron secret
    const isServiceRole = Boolean(
      supabaseServiceKey &&
      token &&
      (await timingSafeEqualString(token, supabaseServiceKey))
    );

    const isCronSecret = Boolean(
      cronSecret &&
      ((customCronHeader &&
        (await timingSafeEqualString(customCronHeader, cronSecret))) ||
        (token && (await timingSafeEqualString(token, cronSecret))))
    );

    if (!isServiceRole && !isCronSecret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Restricted to scheduled background cron jobs" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { error } = await supabase.rpc("cleanup_expired_chat_sessions");

    if (error) throw error;

    return new Response(JSON.stringify({ success: true, message: "AI sessions cleanup completed." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
