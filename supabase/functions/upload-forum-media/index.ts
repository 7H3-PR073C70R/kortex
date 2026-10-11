import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} from "https://esm.sh/@aws-sdk/client-s3@3.525.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-file-name, x-media-type, x-document-id",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// Maximum allowed payload: 15MB
const MAX_FILE_SIZE = 15 * 1024 * 1024;

// Whitelisted MIME types mapped to safe extensions
const ALLOWED_MIME_MAP: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/jpg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "audio/m4a": "m4a",
  "audio/mp4": "m4a",
  "audio/x-m4a": "m4a",
  "audio/mpeg": "mp3",
  "audio/mp3": "mp3",
  "audio/wav": "wav",
  "audio/x-wav": "wav",
};

function getR2Config() {
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  const bucketName = Deno.env.get("R2_BUCKET_NAME") ?? "kortex-forum-media";
  const publicDomain = (
    Deno.env.get("R2_PUBLIC_DOMAIN") ?? ""
  ).replace(/\/+$/, "");
  const endpoint =
    Deno.env.get("R2_S3_ENDPOINT") ??
    (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : "");

  if (!accountId || !accessKeyId || !secretAccessKey || !endpoint) {
    return null;
  }

  return {
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    publicDomain,
    endpoint,
  };
}

function createR2Client(config: NonNullable<ReturnType<typeof getR2Config>>) {
  return new S3Client({
    region: "auto",
    endpoint: config.endpoint,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const r2Config = getR2Config();
  if (!r2Config) {
    console.error(
      "[upload-forum-media] R2 credentials missing from environment (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY)."
    );
    return new Response(
      JSON.stringify({
        error: "Server Configuration Error",
        message: "R2 storage service credentials are not configured on the server.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  const s3Client = createR2Client(r2Config);
  const url = new URL(req.url);

  // -------------------------------------------------------------------------
  // GET Mode: Hardened Media Proxy Streaming from R2 Bucket
  // -------------------------------------------------------------------------
  if (req.method === "GET") {
    const rawKey = url.searchParams.get("key");
    if (!rawKey) {
      return new Response(
        JSON.stringify({ error: "Missing required 'key' parameter" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const key = rawKey.trim();

    // Prevent directory traversal or leading slash attempts
    if (
      key.includes("..") ||
      key.startsWith("/") ||
      key.includes("\\") ||
      key.includes("\0")
    ) {
      return new Response(
        JSON.stringify({ error: "Invalid object key path" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Whitelist allowed storage prefixes to prevent accessing arbitrary internal objects
    const hasAllowedPrefix =
      key.startsWith("forum/") ||
      key.startsWith("documents/") ||
      key.startsWith("downloads/");

    if (!hasAllowedPrefix) {
      return new Response(
        JSON.stringify({
          error: "Forbidden",
          message: "Access to the requested object path prefix is restricted.",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    try {
      const getCmd = new GetObjectCommand({
        Bucket: r2Config.bucketName,
        Key: key,
      });
      const s3Res = await s3Client.send(getCmd);
      if (!s3Res.Body) {
        return new Response("Object not found", {
          status: 404,
          headers: corsHeaders,
        });
      }

      const bodyStream = s3Res.Body.transformToWebStream();
      return new Response(bodyStream, {
        headers: {
          ...corsHeaders,
          "Content-Type": s3Res.ContentType || "application/octet-stream",
          "Cache-Control": "public, max-age=31536000, immutable",
          "Content-Length": s3Res.ContentLength ? String(s3Res.ContentLength) : "",
          "X-Content-Type-Options": "nosniff",
          "Content-Security-Policy": "default-src 'none'; sandbox",
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

  // -------------------------------------------------------------------------
  // POST Mode: Strictly Authenticated File Upload to R2 Bucket
  // -------------------------------------------------------------------------
  if (req.method === "POST") {
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

      // 1. Mandatory User Authentication
      const authHeader = req.headers.get("Authorization") ?? "";
      if (!authHeader.toLowerCase().startsWith("bearer ")) {
        return new Response(
          JSON.stringify({
            error: "Unauthorized",
            message: "A valid Bearer session token is required to upload media.",
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
            message: "User authentication required; anonymous key cannot upload media.",
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

      const authenticatedUserId = user.id;

      // 2. Parse Payload & Headers
      const contentType = req.headers.get("Content-Type") || "";
      let fileBytes: Uint8Array;
      let mediaType = (req.headers.get("x-media-type") || "image").toLowerCase();
      let originalName =
        req.headers.get("x-file-name") || `upload_${Date.now()}`;
      const rawDocId =
        req.headers.get("x-document-id") || req.headers.get("documentId");
      let mimeType = "application/octet-stream";

      if (contentType.includes("multipart/form-data")) {
        const formData = await req.formData();
        const file = formData.get("file") as File | null;
        if (!file) {
          return new Response(
            JSON.stringify({ error: "Missing 'file' in multipart form data" }),
            {
              status: 400,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
        fileBytes = new Uint8Array(await file.arrayBuffer());
        originalName = file.name || originalName;
        mimeType = file.type || mimeType;
        if (formData.has("mediaType")) {
          mediaType = String(formData.get("mediaType")).toLowerCase();
        }
      } else {
        fileBytes = new Uint8Array(await req.arrayBuffer());
        mimeType = contentType.split(";")[0].trim().toLowerCase() || mimeType;
      }

      // 3. Payload Size Constraints
      if (fileBytes.length === 0) {
        return new Response(
          JSON.stringify({ error: "File content is empty" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      if (fileBytes.length > MAX_FILE_SIZE) {
        return new Response(
          JSON.stringify({
            error: "PAYLOAD_TOO_LARGE",
            message: `File size (${(fileBytes.length / (1024 * 1024)).toFixed(2)} MB) exceeds the maximum permitted 15MB limit.`,
          }),
          {
            status: 413,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // 4. MIME Type & Extension Whitelisting
      let ext = ALLOWED_MIME_MAP[mimeType];

      // Fallback: check file extension if MIME was generic octet-stream
      if (!ext && mimeType === "application/octet-stream") {
        const nameExt = originalName.split(".").pop()?.toLowerCase() ?? "";
        if (["jpg", "jpeg"].includes(nameExt)) {
          ext = "jpg";
          mimeType = "image/jpeg";
        } else if (nameExt === "png") {
          ext = "png";
          mimeType = "image/png";
        } else if (nameExt === "webp") {
          ext = "webp";
          mimeType = "image/webp";
        } else if (nameExt === "m4a") {
          ext = "m4a";
          mimeType = "audio/m4a";
        } else if (nameExt === "mp3") {
          ext = "mp3";
          mimeType = "audio/mpeg";
        } else if (nameExt === "wav") {
          ext = "wav";
          mimeType = "audio/wav";
        }
      }

      if (!ext) {
        return new Response(
          JSON.stringify({
            error: "UNSUPPORTED_MEDIA_TYPE",
            message:
              "Unsupported file type. Permitted formats are JPEG, PNG, WebP, M4A, MP3, and WAV.",
          }),
          {
            status: 415,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // 5. Document Ownership Verification (if documentId is specified)
      let documentId: string | null = null;
      if (rawDocId) {
        const trimmedDocId = String(rawDocId).trim();
        // UUID format validation
        const uuidRegex =
          /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(trimmedDocId)) {
          return new Response(
            JSON.stringify({ error: "Invalid documentId format (UUID expected)" }),
            {
              status: 400,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }

        const serviceClient = createClient(supabaseUrl, supabaseServiceKey);
        const { data: docRecord, error: docErr } = await serviceClient
          .from("documents")
          .select("id, user_id")
          .eq("id", trimmedDocId)
          .single();

        if (docErr || !docRecord) {
          return new Response(
            JSON.stringify({ error: "Target document not found" }),
            {
              status: 404,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }

        if (docRecord.user_id !== authenticatedUserId) {
          return new Response(
            JSON.stringify({
              error: "Forbidden",
              message: "You can only upload assets to documents you own.",
            }),
            {
              status: 403,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }

        documentId = trimmedDocId;
      }

      // 6. Secure Randomized Key Construction (Prevent file overwrites)
      const fileUuid = crypto.randomUUID();
      const cleanFileName = originalName
        .replace(/[^a-zA-Z0-9_\.-]/g, "_")
        .slice(0, 60);

      const safeMediaType = ["image", "voice"].includes(mediaType)
        ? mediaType
        : "image";

      const objectKey = documentId
        ? `documents/${documentId}/images/${fileUuid}_${cleanFileName}.${ext}`
        : `forum/${safeMediaType}/${authenticatedUserId}/${Date.now()}_${fileUuid}.${ext}`;

      // 7. S3/R2 PutObject Upload
      const putCmd = new PutObjectCommand({
        Bucket: r2Config.bucketName,
        Key: objectKey,
        Body: fileBytes,
        ContentType: mimeType,
        CacheControl: "public, max-age=31536000, immutable",
      });

      await s3Client.send(putCmd);

      // 8. Return Canonical Public URL & Secure Proxy URL
      const publicUrl = r2Config.publicDomain
        ? `${r2Config.publicDomain}/${objectKey}`
        : "";
      const proxyUrl = `${url.origin}${url.pathname}?key=${encodeURIComponent(objectKey)}`;

      return new Response(
        JSON.stringify({
          success: true,
          url: publicUrl || proxyUrl,
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
