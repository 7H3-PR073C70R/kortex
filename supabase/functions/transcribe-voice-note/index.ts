import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const groqApiKey = Deno.env.get("GROQ_API_KEY");
    if (!groqApiKey) {
      console.error("GROQ_API_KEY environment variable is not configured.");
      return new Response(
        JSON.stringify({ error: "Server missing GROQ_API_KEY secret" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

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

    const audioUrl = String(body.audio_url);
    const replyId = body.reply_id ? String(body.reply_id) : null;
    const postId = body.post_id ? String(body.post_id) : null;

    console.log(`Transcribing voice note: ${audioUrl} (reply: ${replyId}, post: ${postId})`);

    // Fetch the audio file from the public storage URL (e.g. Cloudflare R2)
    const audioRes = await fetch(audioUrl);
    if (!audioRes.ok) {
      console.error(`Failed to download audio from ${audioUrl}: ${audioRes.status} ${audioRes.statusText}`);
      return new Response(
        JSON.stringify({ error: `Failed to download audio: ${audioRes.statusText}` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const audioBlob = await audioRes.blob();
    const fileName = audioUrl.split("?")[0].split("/").pop() || "audio.m4a";
    const cleanFileName = fileName.endsWith(".m4a") || fileName.endsWith(".mp3") || fileName.endsWith(".wav")
      ? fileName
      : `${fileName}.m4a`;

    // Construct multipart form data for Groq's OpenAI-compatible Whisper endpoint
    const formData = new FormData();
    formData.append("file", audioBlob, cleanFileName);
    formData.append("model", "whisper-large-v3-turbo");
    formData.append("response_format", "json");

    const groqRes = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${groqApiKey}`,
      },
      body: formData,
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      console.error(`Groq transcription failed: ${groqRes.status} ${errText}`);
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
    console.log(`Transcription result (${transcript.length} chars): "${transcript.slice(0, 80)}..."`);

    // Update database record with the resulting transcript using service role client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (supabaseUrl && supabaseServiceKey && transcript.length > 0) {
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      if (replyId) {
        const { error: replyErr } = await supabase
          .from("forum_replies")
          .update({ voice_note_transcript: transcript })
          .eq("id", replyId);

        if (replyErr) {
          console.error("Failed to update reply voice_note_transcript:", replyErr);
        } else {
          console.log(`Updated reply ${replyId} voice_note_transcript successfully.`);
        }
      }

      if (postId) {
        const { error: postErr } = await supabase
          .from("forum_posts")
          .update({ voice_note_transcript: transcript })
          .eq("id", postId);

        if (postErr) {
          console.error("Failed to update post voice_note_transcript:", postErr);
        } else {
          console.log(`Updated post ${postId} voice_note_transcript successfully.`);
        }
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
    console.error("transcribe-voice-note exception:", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
