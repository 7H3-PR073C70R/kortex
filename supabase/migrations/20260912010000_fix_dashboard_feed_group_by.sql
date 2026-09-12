-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: Fix get_dashboard_feed GROUP BY and Aggregations
-- Resolves Postgres error 42803: column uc.enrolled_at must appear in GROUP BY
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_feed()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_analytics JSONB;
    v_heatmap JSONB;
    v_due_decks JSONB;
    v_courses JSONB;
    v_countdown JSONB;
    v_unread_count INT := 0;
    v_insight TEXT := 'Maintain your daily active recall streak to maximize neuro-retention.';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- 1. Analytics Summary & Heatmap
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'dateIso', to_char(activity_date, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'intensityLevel', intensity_level,
            'cardsReviewed', cards_reviewed,
            'minutesStudied', minutes_studied
        )
    ), '[]'::jsonb)
    INTO v_heatmap
    FROM (
        SELECT activity_date, intensity_level, cards_reviewed, minutes_studied
        FROM public.heatmap_activity
        WHERE user_id = v_user_id
          AND activity_date >= (CURRENT_DATE - INTERVAL '28 days')
        ORDER BY activity_date ASC
    ) h;

    -- Query analytics joining profiles with user_analytics
    SELECT jsonb_build_object(
        'currentStreakDays', COALESCE(a.current_streak_days, p.streak_days, 0),
        'longestStreakDays', GREATEST(COALESCE(a.longest_streak_days, p.streak_days, 0), 1),
        'weeklyMinutesStudied', COALESCE(a.weekly_minutes_studied, 0),
        'overallRetentionRate', COALESCE(a.overall_retention_rate, 0.85),
        'totalCardsMastered', COALESCE(a.total_cards_mastered, 0),
        'heatMapData', v_heatmap,
        'xpPoints', COALESCE(a.xp_points, 0),
        'academicRank', COALESCE(a.academic_rank, 'Neural Scholar I')
    )
    INTO v_analytics
    FROM public.profiles p
    LEFT JOIN public.user_analytics a ON a.user_id = p.id
    WHERE p.id = v_user_id;

    -- Fallback if profile row is not yet initialized but user_analytics exists
    IF v_analytics IS NULL THEN
        SELECT jsonb_build_object(
            'currentStreakDays', COALESCE(a.current_streak_days, 0),
            'longestStreakDays', GREATEST(COALESCE(a.longest_streak_days, 0), 1),
            'weeklyMinutesStudied', COALESCE(a.weekly_minutes_studied, 0),
            'overallRetentionRate', COALESCE(a.overall_retention_rate, 0.85),
            'totalCardsMastered', COALESCE(a.total_cards_mastered, 0),
            'heatMapData', v_heatmap,
            'xpPoints', COALESCE(a.xp_points, 0),
            'academicRank', COALESCE(a.academic_rank, 'Neural Scholar I')
        )
        INTO v_analytics
        FROM public.user_analytics a
        WHERE a.user_id = v_user_id;
    END IF;

    -- Absolute fallback if neither row exists yet
    IF v_analytics IS NULL THEN
        v_analytics := jsonb_build_object(
            'currentStreakDays', 0,
            'longestStreakDays', 1,
            'weeklyMinutesStudied', 0,
            'overallRetentionRate', 0.85,
            'totalCardsMastered', 0,
            'heatMapData', v_heatmap,
            'xpPoints', 0,
            'academicRank', 'Neural Scholar I'
        );
    END IF;

    -- 2. Due Study Decks (formatted strictly for StudyDeckModel)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'title', d.title,
            'subject', d.subject,
            'totalCards', d.total_cards,
            'dueCards', d.due_cards,
            'retentionRate', d.retention_rate,
            'lastReviewedIso', to_char(COALESCE(d.last_studied, d.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'category', d.category,
            'coverImageUrl', d.cover_image_url,
            'estimatedMinutes', d.estimated_minutes,
            'colorHex', d.color_hex
        )
    ), '[]'::jsonb)
    INTO v_due_decks
    FROM (
        SELECT *
        FROM public.decks
        WHERE user_id = v_user_id AND due_cards > 0
        ORDER BY due_cards DESC
        LIMIT 5
    ) d;

    -- 3. Enrolled Curated Courses (falling back to top catalog if user has none enrolled)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', course_item.id,
            'courseCode', course_item.course_code,
            'title', course_item.title,
            'department', course_item.department,
            'totalMaterials', course_item.total_materials,
            'hasActivePastPapers', course_item.has_active_past_papers,
            'iconName', course_item.icon_name,
            'colorHex', course_item.color_hex,
            'pdfDownloadUrl', course_item.pdf_download_url,
            'syllabusCoverage', course_item.coverage
        )
    ), '[]'::jsonb)
    INTO v_courses
    FROM (
        SELECT 
            c.id,
            c.course_code,
            c.title,
            c.department,
            c.total_materials,
            c.has_active_past_papers,
            c.icon_name,
            c.color_hex,
            c.pdf_download_url,
            COALESCE(uc.syllabus_coverage, c.syllabus_coverage, 0.75) AS coverage,
            uc.enrolled_at
        FROM public.user_curated_courses uc
        JOIN public.curated_courses c ON c.id = uc.course_id
        WHERE uc.user_id = v_user_id
        ORDER BY uc.enrolled_at DESC
    ) course_item;

    IF v_courses IS NULL OR jsonb_array_length(v_courses) = 0 THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'courseCode', c.course_code,
                'title', c.title,
                'department', c.department,
                'totalMaterials', c.total_materials,
                'hasActivePastPapers', c.has_active_past_papers,
                'iconName', c.icon_name,
                'colorHex', c.color_hex,
                'pdfDownloadUrl', c.pdf_download_url,
                'syllabusCoverage', COALESCE(c.syllabus_coverage, 0.75)
            )
        ), '[]'::jsonb)
        INTO v_courses
        FROM (
            SELECT *
            FROM public.curated_courses
            ORDER BY total_materials DESC
            LIMIT 6
        ) c;
    END IF;

    -- 4. Target Exam Countdown (formatted for ExamCountdownModel)
    SELECT jsonb_build_object(
        'id', e.id,
        'examName', e.exam_title,
        'targetDateIso', to_char(e.exam_date, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'syllabusProgress', e.target_readiness,
        'subjectTrack', e.exam_code,
        'totalMockPapersAvailable', 10,
        'completedMocksCount', 0,
        'badgeTitle', 'NATIONAL STANDARD'
    )
    INTO v_countdown
    FROM public.target_exam_countdowns e
    WHERE e.user_id = v_user_id
    LIMIT 1;

    -- 5. Unread Notifications Count
    SELECT COUNT(*) INTO v_unread_count
    FROM public.notifications
    WHERE user_id = v_user_id AND is_read = false;

    RETURN jsonb_build_object(
        'analyticsSummary', v_analytics,
        'dueStudyDecks', v_due_decks,
        'curatedCourses', v_courses,
        'targetExamCountdown', v_countdown,
        'unreadNotificationCount', v_unread_count,
        'syllabotDailyInsight', v_insight
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
