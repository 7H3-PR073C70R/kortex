import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "./_shared/cors.ts";
import {
  timingSafeEqualString,
  verifyTimestampFreshness,
} from "../_shared/security_guard.ts";

interface RevenueCatEvent {
  event: {
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
  api_version: string;
}

Deno.serve(async (req: Request) => {
  // 1. CORS Preflight
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
    // 2. Cryptographic Constant-Time Authentication of RevenueCat Webhook Secret
    const authHeader = req.headers.get("Authorization") ?? "";
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

    if (webhookSecret) {
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
    }

    // 3. Parse Inbound RevenueCat Event
    const body: RevenueCatEvent = await req.json();
    const event = body?.event;

    if (!event || !event.type || !event.app_user_id) {
      console.warn("[RevenueCat Webhook] Malformed webhook body:", body);
      return new Response(
        JSON.stringify({ error: "Invalid webhook payload" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 4. Replay Attack Defense (Check timestamp within 300 seconds if provided)
    const timestampToCheck =
      event.event_timestamp_ms ?? event.purchased_at_ms;

    if (
      timestampToCheck &&
      !verifyTimestampFreshness(timestampToCheck, 300)
    ) {
      console.warn(
        `[RevenueCat Webhook] Replay attack guard triggered: Event timestamp ${timestampToCheck} exceeds allowable drift.`
      );
      return new Response(
        JSON.stringify({
          error: "STALE_TIMESTAMP",
          message: "Event timestamp exceeds acceptable window.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(
      `[RevenueCat Webhook] Authenticated ${event.type} for user: ${event.app_user_id}`
    );

    // 5. Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(
        "[RevenueCat Webhook] Missing Supabase environment variables"
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

    // 6. Subscription Lifecycle State Machine
    let targetTier: "pro" | "free" | null = null;

    switch (event.type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE":
      case "UNCANCELLATION":
        targetTier = "pro";
        break;

      case "EXPIRATION":
      case "REVOCATION":
      case "CANCELLATION":
        targetTier = "free";
        break;

      default:
        console.log(
          `[RevenueCat Webhook] Unhandled event type: ${event.type}. Acknowledged.`
        );
        return new Response(
          JSON.stringify({ received: true, status: "ignored" }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
    }

    // 7. Update user profile in Supabase Postgres via Service Role
    if (targetTier !== null) {
      const { error: updateErr } = await supabase
        .from("profiles")
        .update({
          subscription_tier: targetTier,
          updated_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (updateErr) {
        console.error(
          `[RevenueCat Webhook] Failed to update user ${userId} to ${targetTier}:`,
          updateErr
        );
        return new Response(
          JSON.stringify({
            received: true,
            warning: "Database update failed",
            details: updateErr.message,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      console.log(
        `[RevenueCat Webhook] Successfully updated user ${userId} to tier: ${targetTier}`
      );
    }

    return new Response(
      JSON.stringify({ received: true, tier: targetTier }),
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
