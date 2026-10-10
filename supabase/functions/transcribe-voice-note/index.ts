import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { isSafeOutboundUrl } from "../_shared/security_guard.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const groqApiKey = Deno.env.get("GROQ_API_KEY");

    if (!groqApiKey) {
      console.error("[transcribe-voice-note] Server missing GROQ_API_KEY secret.");
      return new Response(
        JSON.stringify({ error: "Server missing GROQ_API_KEY secret" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("[transcribe-voice-note] Missing Supabase environment variables.");
      return new Response(
        JSON.stringify({ error: "Server misconfiguration" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Strict Authentication Guard
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          message: "A valid Bearer session token is required to transcribe voice notes.",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token || token === supabaseAnonKey) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          message: "Guest access not permitted. Please sign in.",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const {
      data: { user },
      error: authErr,
    } = await authClient.auth.getUser(token).catch(() => ({
      data: { user: null },
      error: new Error("Auth request failed"),
    }));

    if (authErr || !user) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          message: "Invalid or expired session token.",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 2. Parse & Validate Payload
    const body = await req.json().catch(() => null);
    if (!body || !body.audio_url) {
      return new Response(
        JSON.stringify({ error: "Missing required parameter: audio_url" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const audioUrl = String(body.audio_url).trim();
    const replyId = body.reply_id ? String(body.reply_id).trim() : null;
    const postId = body.post_id ? String(body.post_id).trim() : null;

    // 3. SSRF Protection: Prevent downloading arbitrary internal IP addresses or cloud metadata
    if (!isSafeOutboundUrl(audioUrl)) {
      console.warn(`[transcribe-voice-note] Blocked potential SSRF attempt to: ${audioUrl}`);
      return new Response(
        JSON.stringify({
          error: "INVALID_AUDIO_URL",
          message: "The provided audio URL failed security inspection.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

    // 4. Authorization: Verify caller owns the post or reply being transcribed
    if (replyId) {
      const { data: replyRecord, error: fetchReplyErr } = await serviceClient
        .from("forum_replies")
        .select("id, user_id")
        .eq("id", replyId)
        .single();

      if (fetchReplyErr || !replyRecord) {
        return new Response(
          JSON.stringify({ error: "Target forum reply not found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      if (replyRecord.user_id !== user.id) {
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "You can only transcribe voice notes for your own replies.",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    if (postId) {
      const { data: postRecord, error: fetchPostErr } = await serviceClient
        .from("forum_posts")
        .select("id, user_id")
        .eq("id", postId)
        .single();

      if (fetchPostErr || !postRecord) {
        return new Response(
          JSON.stringify({ error: "Target forum post not found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      if (postRecord.user_id !== user.id) {
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "You can only transcribe voice notes for your own posts.",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    console.log(
      `[transcribe-voice-note] Authenticated user ${user.id} transcribing: ${audioUrl}`
    );

    // 5. Fetch Audio File
    const audioRes = await fetch(audioUrl);
    if (!audioRes.ok) {
      console.error(
        `[transcribe-voice-note] Failed to download audio from ${audioUrl}: ${audioRes.status}`
      );
      return new Response(
        JSON.stringify({
          error: `Failed to download audio: ${audioRes.statusText}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const audioBlob = await audioRes.blob();
    const fileName =
      audioUrl.split("?")[0].split("/").pop() || "audio.m4a";
    const cleanFileName =
      fileName.endsWith(".m4a") ||
      fileName.endsWith(".mp3") ||
      fileName.endsWith(".wav")
        ? fileName
        : `${fileName}.m4a`;

    // 6. Forward to Groq Whisper
    const formData = new FormData();
    formData.append("file", audioBlob, cleanFileName);
    formData.append("model", "whisper-large-v3-turbo");
    formData.append("response_format", "json");

    const groqRes = await fetch(
      "https://api.groq.com/openai/v1/audio/transcriptions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${groqApiKey}`,
        },
        body: formData,
      }
    );

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      console.error(
        `[transcribe-voice-note] Groq transcription failed: ${groqRes.status} ${errText}`
      );
      return new Response(
        JSON.stringify({ error: `Groq Whisper API failed: ${errText}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const groqData = await groqRes.json();
    const transcript = (groqData.text ?? "").trim();

    // 7. Persist Transcript
    if (transcript.length > 0) {
      if (replyId) {
        await serviceClient
          .from("forum_replies")
          .update({ voice_note_transcript: transcript })
          .eq("id", replyId);
      }
      if (postId) {
        await serviceClient
          .from("forum_posts")
          .update({ voice_note_transcript: transcript })
          .eq("id", postId);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        transcript,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[transcribe-voice-note] Exception:", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
