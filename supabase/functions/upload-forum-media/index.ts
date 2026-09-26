import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { S3Client, PutObjectCommand, GetObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.525.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-file-name, x-media-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "70d5976cda85543f749219264f8391f0";
const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "45baa62136f37a008f6bb338d27ca708";
const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "cf4d750fbf1ff5ee3b7037e87e8f92540794260fdcdc4d82931244b2fd320246";
const bucketName = Deno.env.get("R2_BUCKET_NAME") ?? "kortex-forum-media";
const publicDomain = Deno.env.get("R2_PUBLIC_DOMAIN") ?? "https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev";
const endpoint = Deno.env.get("R2_S3_ENDPOINT") ?? `https://${accountId}.r2.cloudflarestorage.com`;

const s3Client = new S3Client({
  region: "auto",
  endpoint: endpoint,
  credentials: {
    accessKeyId,
    secretAccessKey,
  },
});

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // GET Mode: Media Proxy Streaming from R2 Bucket
  if (req.method === "GET") {
    const key = url.searchParams.get("key");
    if (!key) {
      return new Response(JSON.stringify({ error: "Missing key parameter" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    try {
      const getCmd = new GetObjectCommand({
        Bucket: bucketName,
        Key: key,
      });
      const s3Res = await s3Client.send(getCmd);
      if (!s3Res.Body) {
        return new Response("Object not found", { status: 404, headers: corsHeaders });
      }

      const bodyStream = s3Res.Body.transformToWebStream();
      return new Response(bodyStream, {
        headers: {
          ...corsHeaders,
          "Content-Type": s3Res.ContentType || "application/octet-stream",
          "Cache-Control": "public, max-age=31536000, immutable",
          "Content-Length": s3Res.ContentLength ? String(s3Res.ContentLength) : "",
        },
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return new Response(JSON.stringify({ error: `Proxy Error: ${msg}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  // POST Mode: Authenticated File Upload to R2 Bucket
  if (req.method === "POST") {
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
      const authHeader = req.headers.get("Authorization") ?? "";

      let authenticatedUserId = "anonymous";
      if (authHeader.toLowerCase().startsWith("bearer ")) {
        const token = authHeader.replace(/^Bearer\s+/i, "").trim();
        const authClient = createClient(supabaseUrl, supabaseAnonKey);
        const { data: { user } } = await authClient.auth.getUser(token);
        if (user) {
          authenticatedUserId = user.id;
        }
      }

      const contentType = req.headers.get("Content-Type") || "";
      let fileBytes: Uint8Array;
      let mediaType = req.headers.get("x-media-type") || "image";
      let originalName = req.headers.get("x-file-name") || `upload_${Date.now()}`;
      let mimeType = "application/octet-stream";

      if (contentType.includes("multipart/form-data")) {
        const formData = await req.formData();
        const file = formData.get("file") as File | null;
        if (!file) {
          return new Response(JSON.stringify({ error: "Missing 'file' in multipart form data" }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        fileBytes = new Uint8Array(await file.arrayBuffer());
        originalName = file.name || originalName;
        mimeType = file.type || mimeType;
        if (formData.has("mediaType")) {
          mediaType = String(formData.get("mediaType"));
        }
      } else {
        fileBytes = new Uint8Array(await req.arrayBuffer());
        mimeType = contentType.split(";")[0] || mimeType;
      }

      if (fileBytes.length === 0) {
        return new Response(JSON.stringify({ error: "File content is empty" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Infer extension & folder path
      let ext = "bin";
      if (mimeType.includes("jpeg") || mimeType.includes("jpg")) ext = "jpg";
      else if (mimeType.includes("png")) ext = "png";
      else if (mimeType.includes("webp")) ext = "webp";
      else if (mimeType.includes("wav")) ext = "wav";
      else if (mimeType.includes("mp4") || mimeType.includes("m4a") || mimeType.includes("aac")) ext = "m4a";
      else if (mimeType.includes("mpeg") || mimeType.includes("mp3")) ext = "mp3";

      const cleanFileName = originalName.replace(/[^a-zA-Z0-9_\.-]/g, "_");
      const objectKey = `forum/${mediaType}/${authenticatedUserId}/${Date.now()}_${cleanFileName}.${ext}`;

      // Upload binary stream to R2
      const putCmd = new PutObjectCommand({
        Bucket: bucketName,
        Key: objectKey,
        Body: fileBytes,
        ContentType: mimeType,
      });

      await s3Client.send(putCmd);

      // Return canonical public R2 URL and Supabase Proxy URL
      const publicUrl = `${publicDomain}/${objectKey}`;
      const proxyUrl = `${url.origin}${url.pathname}?key=${encodeURIComponent(objectKey)}`;

      return new Response(
        JSON.stringify({
          success: true,
          url: publicUrl,
          proxyUrl: proxyUrl,
          key: objectKey,
          sizeBytes: fileBytes.length,
          mimeType: mimeType,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return new Response(JSON.stringify({ error: `Upload Error: ${msg}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
