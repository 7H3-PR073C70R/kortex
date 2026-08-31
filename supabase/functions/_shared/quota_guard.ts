import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

export type QuotaActionType = "document_ingestion" | "syllabot_query";

export interface QuotaGuardResult {
  allowed: boolean;
  tier: "free" | "pro";
  currentUsage: number;
  maxLimit: number;
  response?: Response;
}

export const FREE_TIER_LIMITS = {
  document_ingestion: 3, // 3 Ingestions per 24 hours
  syllabot_query: 30, // 30 Queries per 24 hours
} as const;

export const UPGRADE_URL = "https://kortex.app/pay";

/**
 * Hard Quota & Paywall Enforcement Middleware.
 * Enforces 3 document ingestions and 30 AI queries per 24h on free tier.
 * Bypasses caps for Pro tier and audits token usage to `usage_logs`.
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
  // 1. Fetch user subscription tier from profiles
  const { data: profile, error: profileErr } = await supabaseClient
    .from("profiles")
    .select("subscription_tier")
    .eq("id", userId)
    .single();

  const tier: "free" | "pro" =
    profile?.subscription_tier === "pro" ? "pro" : "free";

  const now = new Date();
  const twentyFourHoursAgo = new Date(
    now.getTime() - 24 * 60 * 60 * 1000
  ).toISOString();

  // 2. Pro Tier: Bypass caps & record audit metric
  if (tier === "pro") {
    // Record to usage_logs asynchronously
    supabaseClient
      .from("usage_logs")
      .insert({
        user_id: userId,
        action_type: actionType,
        token_count: tokenCount,
        tier: "pro",
        created_at: now.toISOString(),
      })
      .then(() => {})
      .catch((err) => {
        console.warn("[QuotaGuard] Failed to record pro usage log:", err);
      });

    return {
      allowed: true,
      tier: "pro",
      currentUsage: 0,
      maxLimit: Infinity,
    };
  }

  // 3. Free Tier: Query 24-hour rolling usage
  const maxLimit = FREE_TIER_LIMITS[actionType];

  const { count: usageCount, error: countErr } = await supabaseClient
    .from("usage_logs")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action_type", actionType)
    .gte("created_at", twentyFourHoursAgo);

  const currentCount = usageCount ?? 0;

  if (currentCount >= maxLimit) {
    console.warn(
      `[QuotaGuard] User ${userId} exceeded 24h ${actionType} limit (${currentCount}/${maxLimit}).`
    );

    const errorPayload = {
      error: "QUOTA_EXCEEDED",
      upgrade_url: UPGRADE_URL,
      action: actionType,
      current_usage: currentCount,
      limit: maxLimit,
      resets_in_hours: 24,
    };

    const response = new Response(JSON.stringify(errorPayload), {
      status: 402, // Payment Required
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
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

  // Record allowed usage event
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
