import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export interface SemanticCacheResult {
  hit: boolean;
  data: any | null;
  similarity?: number;
  hitCount?: number;
}

export class SemanticCacheProvider {
  /**
   * Computes SHA-256 hash string for fast exact-match lookup.
   */
  static async computeHash(input: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(input.trim().toLowerCase());
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
  }

  /**
   * Retrieves cached response using exact SHA-256 hash or vector cosine similarity.
   */
  static async getCachedResponse(
    supabase: SupabaseClient,
    prompt: string,
    options: {
      courseCode?: string;
      promptVector?: number[];
      similarityThreshold?: number;
    } = {}
  ): Promise<SemanticCacheResult> {
    const { courseCode, promptVector, similarityThreshold = 0.95 } = options;
    const promptHash = await this.computeHash(prompt);

    // 1. Fast exact-match hash query
    try {
      let query = supabase
        .from("semantic_response_cache")
        .select("id, response_json, hit_count")
        .eq("prompt_hash", promptHash)
        .gt("expires_at", new Date().toISOString())
        .order("created_at", { ascending: false })
        .limit(1);

      if (courseCode) {
        query = query.eq("course_code", courseCode);
      }

      const { data: exactMatch, error: exactErr } = await query.maybeSingle();

      if (!exactErr && exactMatch && exactMatch.response_json) {
        // Increment hit count asynchronously
        supabase
          .from("semantic_response_cache")
          .update({ hit_count: (exactMatch.hit_count ?? 1) + 1 })
          .eq("id", exactMatch.id)
          .then(() => {});

        return {
          hit: true,
          data: exactMatch.response_json,
          similarity: 1.0,
          hitCount: (exactMatch.hit_count ?? 1) + 1,
        };
      }
    } catch (e) {
      console.error("Exact cache lookup error:", e);
    }

    // 2. Vector cosine similarity lookup if vector is available
    if (promptVector && promptVector.length > 0) {
      try {
        const { data: vectorMatches, error: vecErr } = await supabase.rpc(
          "find_cached_response",
          {
            query_vector: promptVector,
            similarity_threshold: similarityThreshold,
            p_course_code: courseCode ?? null,
          }
        );

        if (!vecErr && vectorMatches && vectorMatches.length > 0) {
          const match = vectorMatches[0];
          return {
            hit: true,
            data: match.response_json,
            similarity: match.similarity,
            hitCount: match.hit_count,
          };
        }
      } catch (e) {
        console.error("Vector semantic cache lookup error:", e);
      }
    }

    return { hit: false, data: null };
  }

  /**
   * Persists response payload to semantic cache with TTL.
   */
  static async setCachedResponse(
    supabase: SupabaseClient,
    prompt: string,
    responseJson: any,
    options: {
      courseCode?: string;
      promptVector?: number[];
      ttlDays?: number;
    } = {}
  ): Promise<void> {
    const { courseCode, promptVector, ttlDays = 7 } = options;
    const promptHash = await this.computeHash(prompt);

    try {
      await supabase.rpc("store_cached_response", {
        p_prompt_hash: promptHash,
        p_response_json: responseJson,
        p_prompt_vector: promptVector ?? null,
        p_course_code: courseCode ?? null,
        p_ttl_days: ttlDays,
      });
    } catch (e) {
      console.error("Storing semantic response cache error:", e);
    }
  }
}
