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
    | "document_completed"
    | "welcome_user"
    | "forum_solution_verified"
    | "quiz_duel_challenge"
    | "quiz_duel_result"
    | "streak_milestone"
    | "subscription_expiry"
    | "process_outbox";
  documentId?: string;
  roomId?: string;
  deckId?: string;
  userId?: string;
  challengerId?: string;
  challengerName?: string;
  duelId?: string;
  duelWinnerId?: string;
  streakDays?: number;
  topicTitle?: string;
  batchSize?: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    const customCronHeader = req.headers.get("X-Cron-Secret") ?? "";

    const isServiceRole =
      supabaseServiceKey &&
      authHeader.replace(/^Bearer\s+/i, "").trim() === supabaseServiceKey;
    const isCronSecretMatch =
      cronSecret &&
      (customCronHeader === cronSecret ||
        authHeader.replace(/^Bearer\s+/i, "").trim() === cronSecret);

    if (!isServiceRole && !isCronSecretMatch) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Endpoint restricted to internal server triggers" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

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
      Authorization: `Bearer ${supabaseServiceKey}`,
      "Content-Type": "application/json",
    };

    switch (action) {
      case "daily_streak_reminder": {
        const { data: usersAtRisk } = await supabase
          .from("profiles")
          .select("id, streak_days, display_name")
          .gte("streak_days", 2);

        if (usersAtRisk && usersAtRisk.length > 0) {
          const today = new Date().toISOString().split("T")[0];

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

      case "spaced_repetition_due": {
        const nowIso = new Date().toISOString();
        const { data: dueCards } = await supabase
          .from("flashcards")
          .select("user_id, deck_id, decks(title)")
          .lte("next_due_date", nowIso);

        if (dueCards && dueCards.length > 0) {
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

      case "room_started": {
        if (roomId) {
          const { data: room } = await supabase
            .from("study_rooms")
            .select("id, title, category, subject, created_by")
            .eq("id", roomId)
            .single();

          if (room) {
            const categoryFilter = room.category || room.subject;
            let peerIds: string[] = [];

            const { data: community } = await supabase
              .from("study_communities")
              .select("id")
              .or(`course_code.eq.${room.subject},department.eq.${categoryFilter}`)
              .limit(1)
              .maybeSingle();

            if (community?.id) {
              const { data: members } = await supabase
                .from("community_members")
                .select("user_id")
                .eq("community_id", community.id)
                .neq("user_id", room.created_by)
                .limit(25);
              peerIds = (members ?? []).map((m: any) => m.user_id);
            }

            if (peerIds.length < 15 && categoryFilter) {
              const { data: trackPeers } = await supabase
                .from("profiles")
                .select("id")
                .or(`target_track.eq.${categoryFilter},target_track.eq.${room.subject}`)
                .neq("id", room.created_by)
                .limit(25);

              const additionalIds = (trackPeers ?? []).map((p: any) => p.id);
              peerIds = Array.from(new Set([...peerIds, ...additionalIds])).slice(0, 25);
            }

            if (peerIds.length > 0) {
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userIds: peerIds,
                  title: `👥 Live Study Room: ${room.title}`,
                  body: `A synchronized focus session in ${room.subject} just started. Join your peers now!`,
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

      case "welcome_user": {
        if (userId) {
          const { data: profile } = await supabase
            .from("profiles")
            .select("display_name")
            .eq("id", userId)
            .single();

          const displayName = profile?.display_name || "Scholar";
          await fetch(sendPushUrl, {
            method: "POST",
            headers,
            body: JSON.stringify({
              userId,
              title: `👋 Welcome to Kortex, ${displayName}!`,
              body: "Your AI study companion is ready. Upload study materials or explore curated exam tracks to start mastering your courses.",
              category: "general",
              data: {
                route: "/dashboard",
                type: "welcome",
              },
            }),
          });
          notificationsDispatched++;
        }
        break;
      }

      case "forum_solution_verified": {
        if (userId) {
          await fetch(sendPushUrl, {
            method: "POST",
            headers,
            body: JSON.stringify({
              userId,
              title: "⭐ Solution Verified!",
              body: body.topicTitle
                ? `Your answer in "${body.topicTitle}" was accepted as the verified solution! You earned +100 XP.`
                : "Your answer was accepted as the verified solution! You earned +100 XP.",
              category: "leaderboard",
              data: {
                route: "/community",
                type: "verified_solution",
              },
            }),
          });
          notificationsDispatched++;
        }
        break;
      }

      case "process_outbox": {
        const batchSize = Math.min(body.batchSize ?? 100, 500);
        const { data: outboxItems, error: outboxErr } = await supabase.rpc(
          "dequeue_notification_outbox",
          { p_batch_size: batchSize }
        );

        if (outboxErr) {
          console.error("Error dequeuing notification outbox:", outboxErr);
          break;
        }

        if (outboxItems && outboxItems.length > 0) {
          const successIds: string[] = [];
          const failedIds: string[] = [];
          const errorMap: Record<string, string> = {};

          for (const item of outboxItems) {
            try {
              const res = await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userId: item.target_user_id,
                  title: item.title,
                  body: item.body,
                  category: item.notification_type,
                  data: item.payload ?? {},
                }),
              });

              if (res.ok) {
                successIds.push(item.outbox_id);
                notificationsDispatched++;
              } else {
                const errText = await res.text();
                failedIds.push(item.outbox_id);
                errorMap[item.outbox_id] = errText;
              }
            } catch (itemErr: any) {
              failedIds.push(item.outbox_id);
              errorMap[item.outbox_id] = itemErr?.message ?? "Network error";
            }
          }

          await supabase.rpc("complete_notification_outbox_batch", {
            p_success_ids: successIds,
            p_failed_ids: failedIds,
            p_error_map: errorMap,
          });
        }
        break;
      }

      case "quiz_duel_challenge": {
        if (body.userId && body.challengerId) {
          const { data: challenger } = await supabase
            .from("profiles")
            .select("display_name")
            .eq("id", body.challengerId)
            .single();

          const challengerName = challenger?.display_name
            ?? body.challengerName
            ?? "A peer";

          await fetch(sendPushUrl, {
            method: "POST",
            headers,
            body: JSON.stringify({
              userId: body.userId,
              title: `⚔️ Quiz Duel Challenge!`,
              body: `${challengerName} challenged you to a quiz duel! Tap to accept and prove your mastery.`,
              category: "quiz_duel",
              data: {
                route: "/quiz-duel",
                duelId: body.duelId ?? "",
                challengerId: body.challengerId,
                action: "quiz_duel_challenge",
              },
            }),
          });
          notificationsDispatched++;
        }
        break;
      }

      case "quiz_duel_result": {
        if (body.duelId) {
          const { data: duel } = await supabase
            .from("quiz_duels")
            .select("player1_id, player2_id, winner_id, player1_score, player2_score")
            .eq("id", body.duelId)
            .single();

          if (duel) {
            const players = [duel.player1_id, duel.player2_id].filter(Boolean);
            for (const playerId of players) {
              const isWinner = duel.winner_id === playerId;
              await fetch(sendPushUrl, {
                method: "POST",
                headers,
                body: JSON.stringify({
                  userId: playerId,
                  title: isWinner ? "🏆 You won the Quiz Duel!" : "📚 Duel Complete",
                  body: isWinner
                    ? "You dominated! Your knowledge proved superior. Collect your XP reward."
                    : "Close match! Review the deck and challenge again to reclaim your rank.",
                  category: "quiz_duel",
                  data: {
                    route: "/quiz-duel",
                    duelId: body.duelId ?? "",
                    result: isWinner ? "win" : "loss",
                    action: "quiz_duel_result",
                  },
                }),
              });
              notificationsDispatched++;
            }
          }
        }
        break;
      }

      case "streak_milestone": {
        if (body.userId && body.streakDays) {
          const streakEmoji = body.streakDays >= 100 ? "🏆"
            : body.streakDays >= 30 ? "⚡"
            : body.streakDays >= 7 ? "🔥"
            : "📈";

          await fetch(sendPushUrl, {
            method: "POST",
            headers,
            body: JSON.stringify({
              userId: body.userId,
              title: `${streakEmoji} ${body.streakDays}-Day Streak Milestone!`,
              body: `You've studied ${body.streakDays} days in a row. Your dedication is extraordinary!`,
              category: "streak_protection",
              data: {
                route: "/dashboard",
                streakDays: String(body.streakDays),
                action: "streak_milestone",
              },
            }),
          });
          notificationsDispatched++;
        }
        break;
      }

      case "subscription_expiry": {
        const now = new Date();
        const inThreeDays = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString();
        const { data: expiringUsers, error: subError } = await supabase
          .from("profiles")
          .select("id, email, subscription_tier, subscription_expires_at")
          .eq("subscription_tier", "pro")
          .lte("subscription_expires_at", inThreeDays)
          .gte("subscription_expires_at", now.toISOString());

        if (!subError && expiringUsers) {
          for (const user of expiringUsers) {
            const expiresAt = new Date(user.subscription_expires_at);
            const daysLeft = Math.max(1, Math.ceil((expiresAt.getTime() - now.getTime()) / (24 * 60 * 60 * 1000)));

            await fetch(sendPushUrl, {
              method: "POST",
              headers,
              body: JSON.stringify({
                userId: user.id,
                title: "📅 Your Kortex Pro is expiring soon",
                body: `${daysLeft} day${daysLeft > 1 ? "s" : ""} left. Renew now to keep AI features and unlimited sync active.`,
                category: "subscription",
                data: {
                  route: "/subscription",
                  daysLeft: String(daysLeft),
                  action: "subscription_expiry",
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
