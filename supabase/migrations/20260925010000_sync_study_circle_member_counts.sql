-- Migration: 20260925010000_sync_study_circle_member_counts.sql
-- Automatically update study_circles.member_count when members join or leave a study circle.

CREATE OR REPLACE FUNCTION trg_sync_study_circle_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE study_circles
        SET member_count = (
            SELECT COUNT(*) FROM study_circle_members WHERE circle_id = NEW.circle_id
        ),
        updated_at = now()
        WHERE id = NEW.circle_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE study_circles
        SET member_count = (
            SELECT COUNT(*) FROM study_circle_members WHERE circle_id = OLD.circle_id
        ),
        updated_at = now()
        WHERE id = OLD.circle_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_study_circle_members_count_sync ON study_circle_members;

CREATE TRIGGER trg_study_circle_members_count_sync
AFTER INSERT OR DELETE ON study_circle_members
FOR EACH ROW
EXECUTE FUNCTION trg_sync_study_circle_member_count();
