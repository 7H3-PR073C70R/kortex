import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "./_shared/cors.ts";
import {
  timingSafeEqualString,
} from "../_shared/security_guard.ts";

interface RevenueCatEvent {
  event: {
    id?: string;
    type:
      | "INITIAL_PURCHASE"
      | "RENEWAL"
      | "PRODUCT_CHANGE"
      | "CANCELLATION"
      | "UNCANCELLATION"
      | "EXPIRATION"
      | "REVOCATION"
      | "BILLING_ISSUE"
      | "SUBSCRIBER_ALIAS"
      | string;
    app_user_id: string;
    original_app_user_id?: string;
    product_id?: string;
    entitlement_id?: string;
    entitlement_ids?: string[];
    purchased_at_ms?: number;
    event_timestamp_ms?: number;
    expiration_at_ms?: number;
    environment?: "SANDBOX" | "PRODUCTION";
  };
  api_version?: string;
}

Deno.serve(async (req: Request) => {
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
    const authHeader = req.headers.get("Authorization") ?? "";
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

    if (!webhookSecret) {
      console.error(
        "[RevenueCat Webhook] Server Misconfiguration: REVENUECAT_WEBHOOK_SECRET is not configured."
      );
      return new Response(
        JSON.stringify({ error: "Server Misconfiguration: Webhook secret not set" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const expectedAuth = `Bearer ${webhookSecret}`;
    const isMatch = await timingSafeEqualString(authHeader, expectedAuth);

    if (!isMatch) {
      console.warn(
        "[RevenueCat Webhook] Cryptographic authentication failure."
      );
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: RevenueCatEvent = await req.json().catch(() => ({}));
    const event = body?.event;

    if (!event || !event.type || !event.app_user_id) {
      console.warn("[RevenueCat Webhook] Malformed webhook body:", body);
      return new Response(
        JSON.stringify({ error: "Invalid webhook payload: missing event, type, or app_user_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Store Environment Segregation Guard
    const isSandbox = event.environment === "SANDBOX";
    const allowSandbox = Deno.env.get("ALLOW_REVENUECAT_SANDBOX") === "true";
    const appEnv = Deno.env.get("ENVIRONMENT") || Deno.env.get("DENO_ENV") || "production";
    const isProduction = appEnv.toLowerCase() === "production";

    if (isSandbox && isProduction && !allowSandbox) {
      console.warn(
        `[RevenueCat Webhook] Rejected SANDBOX event in production environment for user: ${event.app_user_id}`
      );
      return new Response(
        JSON.stringify({
          error: "SANDBOX_NOT_ALLOWED",
          message: "Sandbox events are rejected in production environment without explicit opt-in.",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 2. Resolve Event Timestamp & Unique Event ID
    const timestampToCheck =
      event.event_timestamp_ms ?? event.purchased_at_ms ?? Date.now();

    const eventId =
      event.id ||
      `${event.app_user_id}_${event.type}_${timestampToCheck}`;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(
        "[RevenueCat Webhook] Missing Supabase service credentials in environment"
      );
      return new Response(
        JSON.stringify({ error: "Internal Server Configuration" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const userId = event.app_user_id;

    // 3. Expiration Safety & Tier Mapping
    let targetTier: "pro" | "free" = "free";
    let isPro = false;
    let proUntil: string | null = null;
    let shouldNotify = false;

    switch (event.type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE":
      case "UNCANCELLATION":
        targetTier = "pro";
        isPro = true;
        proUntil = event.expiration_at_ms
          ? new Date(event.expiration_at_ms).toISOString()
          : null;
        shouldNotify = true;
        break;

      case "CANCELLATION": {
        // Expiration Safety: User turned off auto-renew or cancelled renewal.
        // MUST NOT revoke Pro if paid period has not yet elapsed!
        const nowMs = Date.now();
        if (event.expiration_at_ms && event.expiration_at_ms > nowMs) {
          console.log(
            `[RevenueCat Webhook] Cancellation received for user ${userId}. Retaining Pro access until expiration: ${new Date(event.expiration_at_ms).toISOString()}`
          );
          targetTier = "pro";
          isPro = true;
          proUntil = new Date(event.expiration_at_ms).toISOString();
        } else {
          targetTier = "free";
          isPro = false;
          proUntil = null;
          shouldNotify = true;
        }
        break;
      }

      case "EXPIRATION":
      case "REVOCATION":
        targetTier = "free";
        isPro = false;
        proUntil = null;
        shouldNotify = true;
        break;

      case "BILLING_ISSUE": {
        // If still in grace period, maintain access
        const nowMs = Date.now();
        if (event.expiration_at_ms && event.expiration_at_ms > nowMs) {
          targetTier = "pro";
          isPro = true;
          proUntil = new Date(event.expiration_at_ms).toISOString();
        } else {
          targetTier = "free";
          isPro = false;
          proUntil = null;
          shouldNotify = true;
        }
        break;
      }

      default:
        console.log(
          `[RevenueCat Webhook] Unhandled event type: ${event.type}. Acknowledged without tier modification.`
        );
        return new Response(
          JSON.stringify({ received: true, status: "ignored", event_type: event.type }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
    }

    // 4. Atomic Database Stored Procedure (Idempotency + Monotonic Event Ordering)
    const eventIsoDate = new Date(timestampToCheck).toISOString();

    const { data: result, error: rpcErr } = await supabase.rpc(
      "process_revenuecat_billing_event",
      {
        p_event_id: eventId,
        p_user_id: userId,
        p_event_type: event.type,
        p_event_timestamp: eventIsoDate,
        p_target_tier: targetTier,
        p_is_pro: isPro,
        p_pro_until: proUntil,
        p_environment: event.environment || "PRODUCTION",
      }
    );

    if (rpcErr) {
      console.error(
        `[RevenueCat Webhook] RPC process_revenuecat_billing_event failed for user ${userId}:`,
        rpcErr
      );
      return new Response(
        JSON.stringify({
          error: "DATABASE_RPC_ERROR",
          details: rpcErr.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const status = result?.status ?? "unknown";
    console.log(
      `[RevenueCat Webhook] Event ${eventId} processed. Outcome: ${status} for user ${userId}`
    );

    if (status === "duplicate_ignored") {
      return new Response(
        JSON.stringify({
          received: true,
          status: "duplicate",
          message: "Event already processed previously.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (status === "out_of_order_discarded") {
      return new Response(
        JSON.stringify({
          received: true,
          status: "out_of_order",
          message: "Event timestamp is older than last recorded billing state. Discarded.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 5. Send In-App Lifecycle Notifications on Applied State Changes
    if (status === "applied" && shouldNotify) {
      try {
        if (targetTier === "pro") {
          await supabase.from("notifications").insert({
            user_id: userId,
            title: "⭐ Welcome to Kortex Pro!",
            body: "Your Pro subscription is active. Enjoy unlimited AI flashcard synthesis, Socratic tutoring, and priority sync.",
            category: "general",
            data: {
              route: "/dashboard",
              type: "subscription_activated",
              event: event.type,
            },
          });
        } else if (targetTier === "free") {
          await supabase.from("notifications").insert({
            user_id: userId,
            title: "📅 Kortex Pro Plan Ended",
            body: "Your Pro access has expired. You can renew at any time to unlock all AI tools and unlimited cloud storage.",
            category: "general",
            data: {
              route: "/subscription",
              type: "subscription_ended",
              event: event.type,
            },
          });
        }
      } catch (subNotifErr) {
        console.warn(
          "[RevenueCat Webhook] Failed to enqueue subscription notification:",
          subNotifErr
        );
      }
    }

    return new Response(
      JSON.stringify({
        received: true,
        status,
        tier: targetTier,
        is_pro: isPro,
        pro_until: proUntil,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[RevenueCat Webhook] Exception occurred:", err);
    return new Response(
      JSON.stringify({ error: "Internal Server Error", message: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
