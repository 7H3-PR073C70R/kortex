export type ActionType = "ingestion" | "ai_question";
export type UserTier = "free" | "pro" | "unlimited";

export interface QuotaCheckResult {
  allowed: boolean;
  currentUsage: number;
  limit: number;
  remaining: number;
  resetSeconds: number;
  errorResponse?: Response;
}

const DAILY_LIMITS: Record<UserTier, Record<ActionType, number>> = {
  free: {
    ingestion: 3,
    ai_question: 50,
  },
  pro: {
    ingestion: 50,
    ai_question: 1000,
  },
  unlimited: {
    ingestion: 99999,
    ai_question: 99999,
  },
};

const memoryQuotaStore = new Map<string, { count: number; resetAt: number }>();

/**
 * Checks and increments the daily token and action usage for a user.
 * Enforces hard-caps:
 * - Free users: 3 document ingestions/day, 50 AI questions/day.
 * Rejects overages with HTTP 429 (`Quota Exceeded`).
 */
export async function enforceDailyQuota(
  userId: string,
  actionType: ActionType,
  tier: UserTier = "free",
  corsHeaders: Record<string, string> = {}
): Promise<QuotaCheckResult> {
  const limit = DAILY_LIMITS[tier]?.[actionType] ?? DAILY_LIMITS.free[actionType];

  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10); // YYYY-MM-DD
  const endOfDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1, 0, 0, 0)
  );
  const resetSeconds = Math.max(
    1,
    Math.floor((endOfDay.getTime() - now.getTime()) / 1000)
  );

  const quotaKey = `quota:${userId}:${dateStr}:${actionType}`;
  const upstashUrl = Deno.env.get("UPSTASH_REDIS_REST_URL");
  const upstashToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");

  let currentUsage = 0;

  if (upstashUrl && upstashToken) {
    try {
      // INCR and EXPIRE in pipeline
      const pipelineRes = await fetch(`${upstashUrl}/pipeline`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${upstashToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify([
          ["INCR", quotaKey],
          ["EXPIRE", quotaKey, resetSeconds],
        ]),
      });

      if (pipelineRes.ok) {
        const pipelineData = await pipelineRes.json();
        currentUsage = Number(pipelineData?.[0]?.result ?? 1);
      } else {
        currentUsage = incrementMemoryQuota(quotaKey, resetSeconds);
      }
    } catch {
      currentUsage = incrementMemoryQuota(quotaKey, resetSeconds);
    }
  } else {
    currentUsage = incrementMemoryQuota(quotaKey, resetSeconds);
  }

  const remaining = Math.max(0, limit - currentUsage);
  const allowed = currentUsage <= limit;

  if (!allowed) {
    const errorBody = {
      error: "QUOTA_EXCEEDED",
      message: `Daily limit of ${limit} ${actionType === "ingestion" ? "document ingestions" : "AI queries"} reached for free tier.`,
      currentUsage,
      limit,
      tier,
      resetSeconds,
      upgradeUrl: "https://kortexify.app/upgrade",
    };

    const errorResponse = new Response(JSON.stringify(errorBody), {
      status: 429,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Retry-After": resetSeconds.toString(),
        "X-RateLimit-Limit": limit.toString(),
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": resetSeconds.toString(),
      },
    });

    return {
      allowed: false,
      currentUsage,
      limit,
      remaining: 0,
      resetSeconds,
      errorResponse,
    };
  }

  return {
    allowed: true,
    currentUsage,
    limit,
    remaining,
    resetSeconds,
  };
}

function incrementMemoryQuota(key: string, resetSeconds: number): number {
  const now = Date.now();
  const existing = memoryQuotaStore.get(key);

  if (existing && existing.resetAt > now) {
    existing.count += 1;
    return existing.count;
  }

  const record = { count: 1, resetAt: now + resetSeconds * 1000 };
  memoryQuotaStore.set(key, record);
  return 1;
}
