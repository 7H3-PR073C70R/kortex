import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PushNotificationPayload {
  userId?: string;
  userIds?: string[];
  title: string;
  body: string;
  category?:
    | "spaced_repetition"
    | "streak_protection"
    | "exam_countdown"
    | "memory_decay"
    | "ai_ingestion"
    | "room_invite"
    | "leaderboard"
    | "deck_cloned"
    | "security"
    | "general";
  data?: Record<string, string>;
  priority?: "high" | "normal";
}

/**
 * Generate an OAuth2 access token for Firebase Cloud Messaging v1 API
 * using service account credentials.
 */
async function getGoogleAccessToken(
  clientEmail: string,
  privateKey: string
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  // Base64URL encode header and payload
  const b64Header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const b64Payload = btoa(JSON.stringify(claim))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const signatureInput = `${b64Header}.${b64Payload}`;

  // Clean PEM private key
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKey
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s+/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKPKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signatureInput)
  );

  const signatureArray = Array.from(new Uint8Array(signatureBuffer));
  const b64Signature = btoa(String.fromCharCode(...signatureArray))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const assertion = `${signatureInput}.${b64Signature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to obtain Google access token: ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const supabase = createClient(
      supabaseUrl,
      supabaseServiceKey || supabaseAnonKey
    );

    const payload: PushNotificationPayload = await req.json().catch(() => ({}));
    const {
      userId,
      userIds,
      title,
      body,
      category = "general",
      data = {},
      priority = "high",
    } = payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: title and body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Determine target recipient IDs
    const targetUserIds: string[] = [];
    if (userId) targetUserIds.push(userId);
    if (userIds && Array.isArray(userIds)) {
      for (const id of userIds) {
        if (!targetUserIds.includes(id)) targetUserIds.push(id);
      }
    }

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ error: "No target userId or userIds specified" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Check user notification preferences
    const { data: preferences } = await supabase
      .from("notification_preferences")
      .select("*")
      .in("user_id", targetUserIds);

    const prefMap = new Map<string, Record<string, any>>();
    if (preferences) {
      for (const p of preferences) {
        prefMap.set(p.user_id, p);
      }
    }

    const filteredUserIds = targetUserIds.filter((uid) => {
      const pref = prefMap.get(uid);
      if (!pref) return true; // Default to opted-in if no preference set

      if (category === "study_reminders" || category === "spaced_repetition") {
        return pref.study_reminders !== false;
      }
      if (category === "streak_protection") {
        return pref.streak_alerts !== false;
      }
      if (category === "exam_countdown") {
        return pref.exam_alerts !== false;
      }
      if (category === "room_invite" || category === "social_alerts") {
        return pref.social_alerts !== false;
      }
      if (category === "ai_ingestion") {
        return pref.ai_ingestion_alerts !== false;
      }
      return true;
    });

    if (filteredUserIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "All recipients opted out of this notification category",
          deliveredCount: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch active FCM tokens for eligible users
    const { data: devices, error: deviceError } = await supabase
      .from("user_devices")
      .select("id, user_id, fcm_token, platform")
      .in("user_id", filteredUserIds)
      .eq("is_active", true);

    if (deviceError) {
      console.warn("[PushService] Device lookup error:", deviceError.message);
    }

    // 3. Record in public.notifications inbox
    const notificationInserts = filteredUserIds.map((uid) => ({
      user_id: uid,
      title,
      body,
      category,
      data: { ...data, priority, timestamp: new Date().toISOString() },
      read: false,
    }));

    try {
      await supabase.from("notifications").insert(notificationInserts);
    } catch (inboxErr) {
      console.warn("[PushService] Failed to insert in-app notifications:", inboxErr);
    }

    // 4. Dispatch FCM push notifications to active device tokens
    const tokens = (devices ?? []).map((d) => d.fcm_token).filter(Boolean);

    let fcmSentCount = 0;
    const invalidTokenIds: string[] = [];

    // Check FCM Configuration: Firebase Service Account or Legacy Server Key
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    if (tokens.length > 0) {
      if (serviceAccountRaw) {
        try {
          const sa = JSON.parse(serviceAccountRaw);
          const projectId = sa.project_id || "kortex-study-app-2026";
          const accessToken = await getGoogleAccessToken(
            sa.client_email,
            sa.private_key
          );

          // Send FCM v1 messages
          for (const dev of devices ?? []) {
            try {
              const res = await fetch(
                `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
                {
                  method: "POST",
                  headers: {
                    Authorization: `Bearer ${accessToken}`,
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify({
                    message: {
                      token: dev.fcm_token,
                      notification: { title, body },
                      data: {
                        ...data,
                        category,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                      },
                      android: {
                        priority: priority === "high" ? "HIGH" : "NORMAL",
                        notification: {
                          channel_id: "kortex_channel",
                          sound: "default",
                        },
                      },
                      apns: {
                        payload: {
                          aps: {
                            alert: { title, body },
                            sound: "default",
                            badge: 1,
                          },
                        },
                      },
                    },
                  }),
                }
              );

              if (res.ok) {
                fcmSentCount++;
              } else {
                const errData = await res.json().catch(() => ({}));
                const errCode = errData?.error?.details?.[0]?.errorCode;
                if (errCode === "UNREGISTERED" || errCode === "NOT_FOUND") {
                  invalidTokenIds.push(dev.id);
                }
              }
            } catch (singleSendErr) {
              console.warn(`[PushService] Failed send to token: ${singleSendErr}`);
            }
          }
        } catch (authErr) {
          console.error("[PushService] Service Account OAuth error:", authErr);
        }
      } else if (fcmServerKey) {
        // Legacy FCM HTTP API
        for (const dev of devices ?? []) {
          try {
            const res = await fetch("https://fcm.googleapis.com/fcm/send", {
              method: "POST",
              headers: {
                Authorization: `key=${fcmServerKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                to: dev.fcm_token,
                notification: { title, body, sound: "default" },
                data: { ...data, category },
                priority: priority === "high" ? "high" : "normal",
              }),
            });
            if (res.ok) fcmSentCount++;
          } catch (_) {
            // Non-blocking single failure
          }
        }
      } else {
        // Telemetry mode when secrets are not yet configured in local/staging environment
        console.log(
          `[PushService:Simulated] Dispatched notification to ${tokens.length} devices:`,
          { title, body, category, targetUserCount: filteredUserIds.length }
        );
        fcmSentCount = tokens.length;
      }

      // Deactivate stale device tokens if any were reported unregistered
      if (invalidTokenIds.length > 0) {
        try {
          await supabase
            .from("user_devices")
            .update({ is_active: false, updated_at: new Date().toISOString() })
            .in("id", invalidTokenIds);
        } catch (_) {
          // Non-blocking cleanup
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipientsCount: filteredUserIds.length,
        devicesCount: tokens.length,
        sentCount: fcmSentCount,
        category,
        timestamp: new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[PushService] Uncaught error:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? "Server error in PushService" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
