import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, DELETE, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST" && req.method !== "DELETE") {
    return new Response(
      JSON.stringify({ error: "Method Not Allowed. Use POST or DELETE." }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: Missing Supabase keys" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Bearer token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    // 1. Authenticate Caller using standard client
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

    const userId = user.id;
    console.log(`[delete-account] Initiating store-compliant account purge for user: ${userId}`);

    // 2. Initialize Elevated Admin Client with Service Role Key
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Purge User Storage Objects (Documents & Avatars)
    try {
      const { data: docFiles } = await adminClient.storage
        .from("study-documents")
        .list(userId);

      if (docFiles && docFiles.length > 0) {
        const paths = docFiles.map((f) => `${userId}/${f.name}`);
        await adminClient.storage.from("study-documents").remove(paths);
        console.log(`[delete-account] Purged ${paths.length} storage documents for user ${userId}`);
      }
    } catch (storageErr) {
      console.warn(`[delete-account] Notice purging study-documents: ${storageErr}`);
    }

    try {
      const { data: avatarFiles } = await adminClient.storage
        .from("avatars")
        .list(userId);

      if (avatarFiles && avatarFiles.length > 0) {
        const paths = avatarFiles.map((f) => `${userId}/${f.name}`);
        await adminClient.storage.from("avatars").remove(paths);
      }
    } catch (_) {}

    // 4. Delete User from GoTrue (auth.users)
    // Cascades automatically across profiles, analytics, decks, flashcards, devices, etc.
    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(userId);

    if (deleteUserError) {
      console.error(`[delete-account] Failed to delete user from auth.users: ${deleteUserError.message}`);
      return new Response(
        JSON.stringify({ error: `Failed to delete account: ${deleteUserError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[delete-account] Successfully purged account and cascaded data for user: ${userId}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Account and all associated personal data have been permanently deleted.",
        userId,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[delete-account] Unhandled exception: ${message}`);
    return new Response(
      JSON.stringify({ error: "Internal Server Error during account deletion" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
