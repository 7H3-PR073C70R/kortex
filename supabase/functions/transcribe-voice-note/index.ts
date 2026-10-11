import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { isSafeOutboundUrl } from "../_shared/security_guard.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Maximum allowed audio file size: 25MB (Groq Whisper ceiling)
const MAX_AUDIO_SIZE = 25 * 1024 * 1024;

/**
 * Validates that the audio URL originates exclusively from authorized
 * Kortex storage buckets (Supabase Storage or Cloudflare R2).
 */
function isAuthorizedStorageHost(audioUrl: string, supabaseUrl: string): boolean {
  try {
    const parsed = new URL(audioUrl);
    if (parsed.protocol !== "https:") return false;

    const hostname = parsed.hostname.toLowerCase();

    // 1. Supabase Storage
    if (supabaseUrl) {
      try {
        const expectedSupabaseHost = new URL(supabaseUrl).hostname.toLowerCase();
        if (hostname === expectedSupabaseHost) return true;
      } catch (_) {}
    }
    if (hostname.endsWith(".supabase.co") || hostname.endsWith(".supabase.in")) {
      return true;
    }

    // 2. Cloudflare R2
    const r2PublicDomain = Deno.env.get("R2_PUBLIC_DOMAIN");
    if (r2PublicDomain) {
      try {
        const expectedR2Host = new URL(r2PublicDomain).hostname.toLowerCase();
        if (hostname === expectedR2Host) return true;
      } catch (_) {}
    }

    if (
      hostname.endsWith(".r2.dev") ||
      hostname.endsWith(".r2.cloudflarestorage.com")
    ) {
      return true;
    }

    return false;
  } catch {
    return false;
  }
}

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
      console.error("[transcribe-voice-note] Missing GROQ_API_KEY secret.");
      return new Response(
        JSON.stringify({ error: "Server misconfiguration: Groq credentials missing" }),
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

    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Per-User Rate Limiting (Prevents Groq credit exhaustion)
    const { data: withinLimit, error: rateLimitErr } = await serviceClient.rpc(
      "check_and_record_rate_limit",
      {
        p_ip_hash: user.id,
        p_endpoint: "transcribe-voice-note",
        p_max_requests: 30,
        p_window_minutes: 60,
      }
    );

    if (!rateLimitErr && withinLimit === false) {
      return new Response(
        JSON.stringify({
          error: "RATE_LIMIT_EXCEEDED",
          message: "Hourly voice note transcription limit exceeded. Please try again later.",
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Parse & Validate Payload
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

    // 4. SSRF & Storage Origin Protection
    if (!isSafeOutboundUrl(audioUrl) || !isAuthorizedStorageHost(audioUrl, supabaseUrl)) {
      console.warn(`[transcribe-voice-note] Rejected unauthorized audio URL: ${audioUrl}`);
      return new Response(
        JSON.stringify({
          error: "INVALID_AUDIO_URL",
          message: "The provided audio URL failed security inspection or does not originate from authorized Kortex storage.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    // 5. Ownership Verification & Existing Transcript Cache Lookup
    if (replyId) {
      if (!uuidRegex.test(replyId)) {
        return new Response(JSON.stringify({ error: "Invalid reply_id format" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: replyRecord, error: fetchReplyErr } = await serviceClient
        .from("forum_replies")
        .select("id, user_id, voice_note_url, voice_note_transcript")
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

      // Fast cache return: if already transcribed, return without calling Groq
      if (replyRecord.voice_note_transcript && replyRecord.voice_note_transcript.trim().length > 0) {
        return new Response(
          JSON.stringify({
            success: true,
            transcript: replyRecord.voice_note_transcript.trim(),
            cached: true,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // If not owner, verify audio URL matches the recorded voice note
      const isOwner = replyRecord.user_id === user.id;
      const isAttachedAudio = replyRecord.voice_note_url && replyRecord.voice_note_url === audioUrl;

      if (!isOwner && !isAttachedAudio) {
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "You can only transcribe voice notes attached to this reply or your own replies.",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    if (postId) {
      if (!uuidRegex.test(postId)) {
        return new Response(JSON.stringify({ error: "Invalid post_id format" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: postRecord, error: fetchPostErr } = await serviceClient
        .from("forum_posts")
        .select("id, user_id, voice_note_url, voice_note_transcript")
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

      // Fast cache return: if already transcribed, return without calling Groq
      if (postRecord.voice_note_transcript && postRecord.voice_note_transcript.trim().length > 0) {
        return new Response(
          JSON.stringify({
            success: true,
            transcript: postRecord.voice_note_transcript.trim(),
            cached: true,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // If not owner, verify audio URL matches the recorded voice note
      const isOwner = postRecord.user_id === user.id;
      const isAttachedAudio = postRecord.voice_note_url && postRecord.voice_note_url === audioUrl;

      if (!isOwner && !isAttachedAudio) {
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "You can only transcribe voice notes attached to this post or your own posts.",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    // If neither replyId nor postId is passed, caller must own the storage path
    if (!replyId && !postId) {
      const isUserAudioFolder =
        audioUrl.includes(`/forum/voice/${user.id}/`) ||
        audioUrl.includes(`/${user.id}/`);

      if (!isUserAudioFolder) {
        return new Response(
          JSON.stringify({
            error: "Forbidden",
            message: "Standalone voice notes must reside in your own user storage directory.",
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

    // 6. Download Audio File with Timeout & Size Ceiling
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 20000); // 20s timeout

    let audioRes: Response;
    try {
      audioRes = await fetch(audioUrl, { signal: controller.signal });
    } catch (fetchErr: unknown) {
      clearTimeout(timeoutId);
      const isAbort = (fetchErr as Error)?.name === "AbortError";
      return new Response(
        JSON.stringify({
          error: isAbort ? "AUDIO_DOWNLOAD_TIMEOUT" : "AUDIO_DOWNLOAD_FAILED",
          message: isAbort
            ? "Downloading audio file timed out (20s limit)."
            : "Failed to connect to audio storage source.",
        }),
        {
          status: isAbort ? 504 : 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } finally {
      clearTimeout(timeoutId);
    }

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

    // Check Content-Length header if present
    const contentLength = audioRes.headers.get("content-length");
    if (contentLength && parseInt(contentLength, 10) > MAX_AUDIO_SIZE) {
      return new Response(
        JSON.stringify({
          error: "PAYLOAD_TOO_LARGE",
          message: `Audio file (${(parseInt(contentLength, 10) / (1024 * 1024)).toFixed(2)} MB) exceeds 25MB transcription limit.`,
        }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const audioBytes = new Uint8Array(await audioRes.arrayBuffer());
    if (audioBytes.length > MAX_AUDIO_SIZE) {
      return new Response(
        JSON.stringify({
          error: "PAYLOAD_TOO_LARGE",
          message: `Audio file (${(audioBytes.length / (1024 * 1024)).toFixed(2)} MB) exceeds 25MB transcription limit.`,
        }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const fileName = audioUrl.split("?")[0].split("/").pop() || "audio.m4a";
    const cleanFileName =
      fileName.endsWith(".m4a") ||
      fileName.endsWith(".mp3") ||
      fileName.endsWith(".wav")
        ? fileName
        : `${fileName}.m4a`;

    // 7. Forward to Groq Whisper
    const audioBlob = new Blob([audioBytes]);
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
        `[transcribe-voice-note] Groq transcription failed: ${groqRes.status}`
      );
      return new Response(
        JSON.stringify({
          error: "TRANSCRIPTION_FAILED",
          message: "Groq speech-to-text service encountered an error.",
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const groqData = await groqRes.json();
    const transcript = (groqData.text ?? "").trim();

    // 8. Persist Transcript
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
