import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

export type QuotaActionType =
  | "document_ingestion"
  | "syllabot_query"
  | "flashcard_generation"
  | "quiz_generation"
  | "ai_smart_gen";

export interface QuotaGuardResult {
  allowed: boolean;
  tier: "free" | "pro";
  currentUsage: number;
  maxLimit: number;
  response?: Response;
}

export const FREE_TIER_LIMITS: Record<QuotaActionType, number> = {
  document_ingestion: 3, // 3 Ingestions per day
  syllabot_query: 20, // 20 Queries per day (MON-04)
  flashcard_generation: 10, // 10 Deck syntheses per day
  quiz_generation: 10, // 10 Quizzes per day
  ai_smart_gen: 0, // 0 for free tier (Fast Local synthesis is uncapped)
};

export const UPGRADE_URL = "https://kortexify.app/pay";

/**
 * Hard Atomic Quota & Paywall Enforcement Middleware.
 * Synchronized with PostgreSQL UTC day boundaries via `public.check_and_consume_ai_quota`.
 * Enforces atomic FOR UPDATE row locking in PostgreSQL to eliminate TOCTOU race conditions.
 * Fails closed on database communication errors.
 */
export async function checkAndEnforceQuota(
  supabaseClient: SupabaseClient,
  userId: string,
  actionType: QuotaActionType,
  tokenCount: number = 0,
  corsHeaders: Record<string, string> = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  }
): Promise<QuotaGuardResult> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const client =
      supabaseUrl && serviceRoleKey
        ? createClient(supabaseUrl, serviceRoleKey)
        : supabaseClient;

    const { data, error } = await client.rpc(
      "check_and_consume_ai_quota",
      {
        p_user_id: userId,
        p_action_type: actionType,
        p_token_count: tokenCount,
      }
    );

    if (error) {
      console.error(
        `[QuotaGuard] check_and_consume_ai_quota RPC failed for user ${userId}:`,
        error
      );
      // Fail closed: reject request rather than allowing unlimited API abuse
      const errorPayload = {
        error: "QUOTA_VERIFICATION_ERROR",
        message:
          "Unable to verify AI usage quota at this time. Please try again shortly.",
      };
      return {
        allowed: false,
        tier: "free",
        currentUsage: 0,
        maxLimit: 0,
        response: new Response(JSON.stringify(errorPayload), {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }),
      };
    }

    const isAllowed = Boolean(data?.allowed);
    const tier: "free" | "pro" = data?.tier === "pro" ? "pro" : "free";
    const currentUsage: number = data?.current_usage ?? 0;
    const maxLimit: number = data?.max_limit ?? (tier === "pro" ? Infinity : FREE_TIER_LIMITS[actionType]);
    const resetSeconds: number = data?.reset_seconds ?? 3600;

    if (!isAllowed) {
      console.warn(
        `[QuotaGuard] User ${userId} exceeded daily UTC ${actionType} limit (${currentUsage}/${maxLimit}) on tier ${tier}.`
      );

      const errorPayload = {
        error: "QUOTA_EXCEEDED",
        message: `Daily limit of ${maxLimit} ${actionType.replace(/_/g, " ")} reached for ${tier} tier.`,
        upgrade_url: UPGRADE_URL,
        action: actionType,
        current_usage: currentUsage,
        limit: maxLimit,
        reset_seconds: resetSeconds,
      };

      const response = new Response(JSON.stringify(errorPayload), {
        status: 402, // Payment Required
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Retry-After": resetSeconds.toString(),
        },
      });

      return {
        allowed: false,
        tier,
        currentUsage,
        maxLimit,
        response,
      };
    }

    return {
      allowed: true,
      tier,
      currentUsage,
      maxLimit,
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[QuotaGuard] Exception enforcing quota for user ${userId}:`, message);

    // Fail closed
    return {
      allowed: false,
      tier: "free",
      currentUsage: 0,
      maxLimit: 0,
      response: new Response(
        JSON.stringify({
          error: "QUOTA_SERVICE_UNAVAILABLE",
          message: "Internal error enforcing usage limits. Please retry.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      ),
    };
  }
}
