import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

export type QuotaActionType =
  | "document_ingestion"
  | "syllabot_query"
  | "flashcard_generation";

export interface QuotaGuardResult {
  allowed: boolean;
  tier: "free" | "pro";
  currentUsage: number;
  maxLimit: number;
  response?: Response;
}

export const FREE_TIER_LIMITS = {
  document_ingestion: 3, // 3 Ingestions per day
  syllabot_query: 20, // 20 Queries per day (MON-04)
  flashcard_generation: 10, // 10 Deck syntheses per day for free tier
} as const;

export const UPGRADE_URL = "https://kortexify.app/pay";

/**
 * Hard Quota & Paywall Enforcement Middleware.
 * Synchronized with PostgreSQL UTC day boundaries (matching RPC functions).
 * Tracks usage authoritatively in `public.usage_logs`.
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
  const { data: profile } = await supabaseClient
    .from("profiles")
    .select("subscription_tier, is_pro, pro_until")
    .eq("id", userId)
    .single();

  const isProActive =
    profile?.is_pro === true ||
    profile?.subscription_tier === "pro" ||
    (profile?.pro_until && new Date(profile.pro_until).getTime() > Date.now());

  const tier: "free" | "pro" = isProActive ? "pro" : "free";

  const now = new Date();
  // Standardized UTC calendar day boundary (00:00:00 UTC) matching Postgres RPC date_trunc('day', now())
  const startOfUtcDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0)
  ).toISOString();

  if (tier === "pro") {
    try {
      await supabaseClient.from("usage_logs").insert({
        user_id: userId,
        action_type: actionType,
        token_count: tokenCount,
        tier: "pro",
        created_at: now.toISOString(),
      });
    } catch (err) {
      console.warn("[QuotaGuard] Failed to record pro usage log:", err);
    }

    const { count: proUsageCount } = await supabaseClient
      .from("usage_logs")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("action_type", actionType)
      .gte("created_at", startOfUtcDay);

    return {
      allowed: true,
      tier: "pro",
      currentUsage: proUsageCount ?? 1,
      maxLimit: Infinity,
    };
  }

  const maxLimit = FREE_TIER_LIMITS[actionType];

  const { count: usageCount } = await supabaseClient
    .from("usage_logs")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action_type", actionType)
    .gte("created_at", startOfUtcDay);

  const currentCount = usageCount ?? 0;

  if (currentCount >= maxLimit) {
    console.warn(
      `[QuotaGuard] User ${userId} exceeded daily UTC ${actionType} limit (${currentCount}/${maxLimit}).`
    );

    const endOfUtcDay = new Date(
      Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate() + 1,
        0,
        0,
        0
      )
    );
    const resetSeconds = Math.max(
      1,
      Math.floor((endOfUtcDay.getTime() - now.getTime()) / 1000)
    );

    const errorPayload = {
      error: "QUOTA_EXCEEDED",
      message: `Daily limit of ${maxLimit} ${actionType.replace("_", " ")} reached for free tier.`,
      upgrade_url: UPGRADE_URL,
      action: actionType,
      current_usage: currentCount,
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
      tier: "free",
      currentUsage: currentCount,
      maxLimit,
      response,
    };
  }

  await supabaseClient.from("usage_logs").insert({
    user_id: userId,
    action_type: actionType,
    token_count: tokenCount,
    tier: "free",
    created_at: now.toISOString(),
  });

  return {
    allowed: true,
    tier: "free",
    currentUsage: currentCount + 1,
    maxLimit,
  };
}
