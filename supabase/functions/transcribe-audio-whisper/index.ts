import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

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
    const groqApiKey = Deno.env.get("GROQ_API_KEY");

    if (!groqApiKey) {
      console.error("[transcribe-audio-whisper] Missing GROQ_API_KEY secret.");
      return new Response(
        JSON.stringify({ error: "Server missing GROQ_API_KEY configuration" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Authenticate Caller
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          message: "User session token required for audio transcription.",
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
      error: new Error("Auth check failed"),
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

    // 2. Parse Multipart File Upload
    const incomingFormData = await req.formData().catch(() => null);
    if (!incomingFormData) {
      return new Response(
        JSON.stringify({ error: "Invalid multipart form data" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const file = incomingFormData.get("file");
    if (!file || !(file instanceof File || file instanceof Blob)) {
      return new Response(
        JSON.stringify({ error: "Missing required 'file' part in form data" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(
      `[transcribe-audio-whisper] User ${user.id} uploading audio file (${file.size} bytes)...`
    );

    // 3. Forward to Groq Whisper v3 Turbo
    const whisperFormData = new FormData();
    const fileName =
      file instanceof File && file.name ? file.name : "lecture_audio.m4a";
    whisperFormData.append("file", file, fileName);
    whisperFormData.append("model", "whisper-large-v3-turbo");
    whisperFormData.append("response_format", "json");

    const groqRes = await fetch(
      "https://api.groq.com/openai/v1/audio/transcriptions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${groqApiKey}`,
        },
        body: whisperFormData,
      }
    );

    if (!groqRes.ok) {
      const errBody = await groqRes.text();
      console.error(
        `[transcribe-audio-whisper] Groq Whisper failed (${groqRes.status}): ${errBody}`
      );
      return new Response(
        JSON.stringify({
          error: `Groq Whisper transcription failed: ${errBody}`,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const groqData = await groqRes.json();
    const transcriptText = (groqData.text ?? "").trim();

    console.log(
      `[transcribe-audio-whisper] Successfully transcribed ${transcriptText.length} characters.`
    );

    return new Response(
      JSON.stringify({
        success: true,
        text: transcriptText,
        transcription: transcriptText,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[transcribe-audio-whisper] Exception:", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
