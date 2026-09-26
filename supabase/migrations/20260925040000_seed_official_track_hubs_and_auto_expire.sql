-- Migration: 20260925040000_seed_official_track_hubs_and_auto_expire.sql
-- Delete legacy study rooms and seed official 24/7 Silent Focus Hubs per track.
-- Also auto-expire user-created empty rooms after 30 minutes.

DELETE FROM public.study_rooms;

INSERT INTO public.study_rooms (
    id,
    title,
    description,
    subject,
    category,
    pomodoro_duration_minutes,
    pomodoro_state,
    active_participants_count,
    max_participants,
    ambient_sound_track,
    active_goal,
    is_silent_focus
) VALUES 
(
    '00000000-0000-0000-0000-000000000001',
    'JAMB Official Silent Focus Hub',
    '24/7 Official Silent Study Room for JAMB / UTME Candidates',
    'JAMB-STUDY-HUB',
    'JAMB',
    25,
    'focusing',
    1,
    50,
    'lofi',
    'Past Questions & Active Recall Practice',
    true
),
(
    '00000000-0000-0000-0000-000000000002',
    'WAEC / GCE Official Silent Focus Hub',
    '24/7 Official Silent Study Room for WAEC & GCE Candidates',
    'WAEC-STUDY-HUB',
    'WAEC',
    25,
    'focusing',
    1,
    50,
    'lofi',
    'Syllabus Topic Mastery',
    true
),
(
    '00000000-0000-0000-0000-000000000003',
    'NECO Official Silent Focus Hub',
    '24/7 Official Silent Study Room for NECO Candidates',
    'NECO-STUDY-HUB',
    'NECO',
    25,
    'focusing',
    1,
    50,
    'lofi',
    'Exam Prep & Deep Focus Work',
    true
),
(
    '00000000-0000-0000-0000-000000000004',
    'JUPEB / IJMB Official Silent Focus Hub',
    '24/7 Official Silent Study Room for A-Level & JUPEB Candidates',
    'JUPEB-STUDY-HUB',
    'JUPEB',
    25,
    'focusing',
    1,
    50,
    'lofi',
    'Advanced Syllabus Deep Work',
    true
),
(
    '00000000-0000-0000-0000-000000000005',
    'General Peer Focus Hub',
    '24/7 Official Silent Study Room for All Scholars',
    'GENERAL-STUDY-HUB',
    'General',
    25,
    'focusing',
    1,
    50,
    'lofi',
    'Pomodoro Silent Study',
    true
)
ON CONFLICT (id) DO UPDATE SET 
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    subject = EXCLUDED.subject,
    category = EXCLUDED.category,
    active_participants_count = EXCLUDED.active_participants_count;

-- Auto-expire user-created rooms with 0 active peers after 30 minutes
CREATE OR REPLACE FUNCTION cleanup_inactive_study_rooms()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    WITH deleted_rooms AS (
        DELETE FROM public.study_rooms
        WHERE title NOT ILIKE '%Official Silent Focus Hub%'
          AND title NOT ILIKE '%General Peer Focus Hub%'
          AND (active_participants_count <= 0 OR active_participants_count IS NULL)
          AND created_at < (now() - INTERVAL '30 minutes')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_count FROM deleted_rooms;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_inactive_rooms_count', v_deleted_count,
        'timestamp', now()
    );
END;
$$;
