import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProvisionRequest {
  courseCode: string;
  title?: string;
  department?: string;
  userId?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let effectiveUserId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabase.auth.getUser(token);
      effectiveUserId = user?.id ?? null;
    }

    const payload: ProvisionRequest = await req.json();
    const courseCode = payload.courseCode?.trim().toUpperCase();
    const title = payload.title?.trim() || `${courseCode} Study Hub`;
    const department = payload.department?.trim() || "General";
    const userId = payload.userId || effectiveUserId;

    if (!courseCode) {
      return new Response(
        JSON.stringify({ error: "courseCode is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Check if study_communities record exists
    const { data: existingCommunity, error: checkError } = await supabase
      .from("study_communities")
      .select("*, study_rooms(id, title, active_participants_count)")
      .eq("course_code", courseCode)
      .maybeSingle();

    if (checkError) {
      console.error("Error querying community:", checkError);
    }

    let communityRecord = existingCommunity;
    let isFoundingMember = false;

    if (!communityRecord) {
      // 2. Create the study_communities record
      const { data: newCommunity, error: insertError } = await supabase
        .from("study_communities")
        .insert({
          course_code: courseCode,
          title: title,
          department: department,
          member_count: 1,
          active_rooms_count: 1,
          forum_threads_count: 3,
        })
        .select()
        .single();

      if (insertError) {
        throw insertError;
      }
      communityRecord = newCommunity;
      isFoundingMember = true;

      // 3. Create default focus room
      const { data: defaultRoom } = await supabase
        .from("study_rooms")
        .insert({
          title: `${courseCode} 25m Focus Pomodoro`,
          description: `Collaborative study session for ${title}.`,
          subject: courseCode,
          category: department,
          pomodoro_duration_minutes: 25,
          pomodoro_state: "focusing",
          active_participants_count: 1,
          created_by: userId,
        })
        .select()
        .single();

      // 4. Create default forum channels / threads
      await supabase.from("forum_posts").insert([
        {
          title: `Welcome to ${title}!`,
          content: `Official discussion space for ${courseCode}. Share questions, past papers, and study strategies.`,
          track: department,
          author_id: userId,
          author_name: "Kortexify Syllabot",
          upvotes: 5,
        },
        {
          title: `${courseCode} Past Paper Solutions & Discussion`,
          content: `Thread for resolving difficult problems and verifying step-by-step solutions.`,
          track: department,
          author_id: userId,
          author_name: "Kortexify Peer Hub",
          upvotes: 3,
        },
        {
          title: `Syllabot AI Notes & Formula Cheat Sheets`,
          content: `Curated LaTeX notes, formulas, and flashcard decks generated for this course.`,
          track: department,
          author_id: userId,
          author_name: "Kortexify AI",
          latex_content: "\\sum_{i=1}^{n} x_i",
          upvotes: 8,
        },
      ]);

      if (defaultRoom) {
        communityRecord.active_room_id = defaultRoom.id;
        communityRecord.active_room_title = defaultRoom.title;
      }
    } else {
      // Increment member count if joining existing
      await supabase
        .from("study_communities")
        .update({ member_count: (communityRecord.member_count || 1) + 1 })
        .eq("id", communityRecord.id);
    }

    // 5. Enroll the user into community_members table if user is present
    if (userId && communityRecord?.id) {
      await supabase.from("community_members").upsert(
        {
          community_id: communityRecord.id,
          user_id: userId,
          is_founding_member: isFoundingMember,
        },
        { onConflict: "community_id,user_id" }
      );
    }

    return new Response(
      JSON.stringify({
        id: communityRecord.id,
        course_code: communityRecord.course_code,
        title: communityRecord.title,
        department: communityRecord.department,
        member_count: communityRecord.member_count ?? 1,
        active_rooms_count: communityRecord.active_rooms_count ?? 1,
        forum_threads_count: communityRecord.forum_threads_count ?? 3,
        is_user_member: true,
        is_founding_member: isFoundingMember,
        active_room_id: communityRecord.active_room_id ?? null,
        active_room_title: communityRecord.active_room_title ?? null,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in provision-course-community:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message || "Internal Server Error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
