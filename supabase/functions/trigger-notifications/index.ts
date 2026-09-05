import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TriggerNotificationRequest {
  action:
    | "daily_streak_reminder"
    | "spaced_repetition_due"
    | "exam_milestones"
    | "memory_decay_alert"
    | "room_started"
    | "document_completed";
  documentId?: string;
  roomId?: string;
  deckId?: string;
  userId?: string;
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

    const body: TriggerNotificationRequest = await req.json().catch(() => ({}));
    const { action, documentId, roomId, deckId, userId } = body;

    if (!action) {
      return new Response(
        JSON.stringify({ error: "Action parameter is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let notificationsDispatched = 0;
    const sendPushUrl = `${supabaseUrl}/functions/v1/send-push-notification`;
    const headers = {
      Authorization: `Bearer ${supabaseServiceKey || supabaseAnonKey}`,
      "Content-Type": "application/json",
    };

    switch (action) {
      // 1. Daily Study Streak Loss Prevention
      case "daily_streak_reminder": {
        const { data: usersAtRisk } = await supabase
          .from("profiles")
          .select("id, streak_days, display_name")
          .gte("streak_days", 2);

        if (usersAtRisk && usersAtRisk.length > 0) {
          const today = new Date().toISOString().split("T")[0];

          // Check who has already studied today
          const { data: activeToday } = await supabase
            .from("heatmap_activity")
            .select("user_id")
            .eq("activity_date", today)
            .or("cards_reviewed.gt.0,minutes_studied.gt.0");

          const activeSet = new Set((activeToday ?? []).map((a) => a.user_id));

          for (const user of usersAtRisk) {
            if (!activeSet.has(user.id)) {
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userId: user.id,
                  title: "🔥 Protect your study streak!",
                  body: `You have a ${user.streak_days}-day streak at risk today. A quick 3-minute review keeps your streak alive!`,
                  category: "streak_protection",
                  data: {
                    route: "/study-session",
                    streakDays: String(user.streak_days),
                  },
                }),
              });
              notificationsDispatched++;
            }
          }
        }
        break;
      }

      // 2. Spaced Repetition Due Queue
      case "spaced_repetition_due": {
        const nowIso = new Date().toISOString();
        const { data: dueCards } = await supabase
          .from("flashcards")
          .select("user_id, deck_id, decks(title)")
          .lte("next_due_date", nowIso);

        if (dueCards && dueCards.length > 0) {
          // Group by user and deck
          const deckMap = new Map<string, { userId: string; title: string; count: number; deckId: string }>();

          for (const card of dueCards) {
            const key = `${card.user_id}:${card.deck_id}`;
            const title = (card.decks as any)?.title ?? "your deck";
            if (!deckMap.has(key)) {
              deckMap.set(key, { userId: card.user_id, title, count: 1, deckId: card.deck_id });
            } else {
              deckMap.get(key)!.count++;
            }
          }

          for (const item of deckMap.values()) {
            if (item.count >= 3) {
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userId: item.userId,
                  title: `🧠 ${item.count} cards due for review in ${item.title}`,
                  body: "Review now to reinforce your memory retention before the decay curve takes over.",
                  category: "spaced_repetition",
                  data: {
                    route: "/study-session",
                    deckId: item.deckId,
                    dueCount: String(item.count),
                  },
                }),
              });
              notificationsDispatched++;
            }
          }
        }
        break;
      }

      // 3. Exam Countdown Milestones
      case "exam_milestones": {
        const { data: upcomingExams } = await supabase
          .from("exam_events")
          .select("id, user_id, exam_name, target_date, daily_target");

        if (upcomingExams && upcomingExams.length > 0) {
          const now = new Date();
          const targetMilestones = [30, 14, 7, 3, 1];

          for (const exam of upcomingExams) {
            const targetDate = new Date(exam.target_date);
            const diffDays = Math.ceil(
              (targetDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
            );

            if (targetMilestones.includes(diffDays)) {
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userId: exam.user_id,
                  title: `⏳ ${diffDays} ${diffDays === 1 ? "day" : "days"} until ${exam.exam_name}!`,
                  body: `Stay on track to hit your mastery goal. Today's target is ${exam.daily_target} cards.`,
                  category: "exam_countdown",
                  data: {
                    route: "/planner",
                    examId: exam.id,
                    daysRemaining: String(diffDays),
                  },
                }),
              });
              notificationsDispatched++;
            }
          }
        }
        break;
      }

      // 4. Document Ingestion Completed Hook
      case "document_completed": {
        if (documentId) {
          const { data: doc } = await supabase
            .from("documents")
            .select("id, user_id, filename")
            .eq("id", documentId)
            .single();

          if (doc) {
            await fetch(sendPushUrl, {
              method: "POST",
              headers,
              body: JSON.stringify({
                userId: doc.user_id,
                title: "✨ Your flashcards are ready!",
                body: `Syllabot synthesized flashcards from "${doc.filename}". Tap to begin studying.`,
                category: "ai_ingestion",
                data: {
                  route: "/deck-detail",
                  documentId: doc.id,
                },
              }),
            });
            notificationsDispatched++;
          }
        }
        break;
      }

      // 5. Live Study Room Started Hook
      case "room_started": {
        if (roomId) {
          const { data: room } = await supabase
            .from("study_rooms")
            .select("id, title, category, subject, created_by")
            .eq("id", roomId)
            .single();

          if (room) {
            // Find peers interested in this category
            const { data: peers } = await supabase
              .from("profiles")
              .select("id")
              .neq("id", room.created_by)
              .limit(20);

            const peerIds = (peers ?? []).map((p) => p.id);
            if (peerIds.length > 0) {
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userIds: peerIds,
                  title: `👥 Live Study Room: ${room.title}`,
                  body: `A new study session in ${room.subject} just started. Join your peers now!`,
                  category: "room_invite",
                  data: {
                    route: "/study-room",
                    roomId: room.id,
                  },
                }),
              });
              notificationsDispatched += peerIds.length;
            }
          }
        }
        break;
      }

      // 6. Memory Decay Alert
      case "memory_decay_alert": {
        const { data: decayingDecks } = await supabase
          .from("decks")
          .select("id, user_id, title, retention_rate")
          .lt("retention_rate", 0.80)
          .gt("total_cards", 0);

        if (decayingDecks && decayingDecks.length > 0) {
          for (const deck of decayingDecks) {
            const retentionPct = Math.round(deck.retention_rate * 100);
            await fetch(sendPushUrl, {
              method: "POST",
              headers,
              body: JSON.stringify({
                userId: deck.user_id,
                title: `📉 Memory retention dropping in ${deck.title}`,
                body: `Calculated retention is down to ${retentionPct}%. A quick review will restore it to 95%+.`,
                category: "memory_decay",
                data: {
                  route: "/study-session",
                  deckId: deck.id,
                },
              }),
            });
            notificationsDispatched++;
          }
        }
        break;
      }

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    return new Response(
      JSON.stringify({
        success: true,
        action,
        notificationsDispatched,
        timestamp: new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[TriggerNotifications] Error:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? "Server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
