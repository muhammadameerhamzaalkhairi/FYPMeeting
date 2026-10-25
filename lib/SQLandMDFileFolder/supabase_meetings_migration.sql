-- ============================================================
-- LIVEMEET - MEETINGS MIGRATION (run once in Supabase SQL Editor)
-- Adds: meetings table, pause/timer columns, RPC functions, overview view
-- WARNING: step 2 deletes the rows currently in meeting_schedule (test data).
--          Re-import the Excel from the app after running this.
-- ============================================================

-- ------------------------------------------------------------
-- 1. MEETINGS (one row = one meeting day, created by Excel import)
-- ------------------------------------------------------------
CREATE TABLE meetings (
    id              BIGSERIAL PRIMARY KEY,
    title           TEXT NOT NULL,
    meeting_date    DATE NOT NULL,
    status          TEXT NOT NULL DEFAULT 'upcoming'
                    CHECK (status IN ('upcoming', 'running', 'paused', 'done')),
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    paused_at       TIMESTAMPTZ,                 -- NOT NULL only while paused
    paused_seconds  INT NOT NULL DEFAULT 0,      -- total paused time so far
    total_seconds   INT,                         -- set when meeting ends (pauses excluded)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (title, meeting_date)                 -- same file imported twice = same meeting
);

-- Only ONE meeting can be running/paused at a time (database enforces it)
CREATE UNIQUE INDEX one_active_meeting ON meetings ((true))
    WHERE status IN ('running', 'paused');

-- ------------------------------------------------------------
-- 2. meeting_schedule: link rows to a meeting + per-group timer columns
-- ------------------------------------------------------------
DELETE FROM meeting_schedule;

ALTER TABLE meeting_schedule DROP CONSTRAINT IF EXISTS meeting_schedule_day_reg_uq;

ALTER TABLE meeting_schedule
    ADD COLUMN meeting_id     BIGINT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    ADD COLUMN paused_seconds INT NOT NULL DEFAULT 0,   -- paused time while this group was running
    ADD COLUMN duration_sec   INT,                      -- set when group ends (pauses excluded)
    ADD CONSTRAINT meeting_schedule_meeting_reg_uq UNIQUE (meeting_id, reg_no);

CREATE INDEX idx_meeting_schedule_meeting ON meeting_schedule (meeting_id, group_no);

-- ------------------------------------------------------------
-- 3. SECURITY (app is login-gated -> role 'authenticated')
-- ------------------------------------------------------------
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON meetings FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON meetings TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE meetings_id_seq TO authenticated;
CREATE POLICY "authenticated full access" ON meetings
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ------------------------------------------------------------
-- 4. OVERVIEW VIEW (Meetings list + Home counters)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW meetings_overview WITH (security_invoker = true) AS
SELECT m.id, m.title, m.meeting_date, m.status,
       m.started_at, m.ended_at, m.paused_at, m.paused_seconds, m.total_seconds, m.created_at,
       COUNT(DISTINCT s.group_no)::int                                                AS groups_total,
       COUNT(s.id)::int                                                               AS students_total,
       COUNT(DISTINCT s.group_no) FILTER (WHERE s.status = 'done')::int               AS groups_done,
       COUNT(DISTINCT s.group_no) FILTER (WHERE s.status = 'skipped')::int            AS groups_skipped,
       COUNT(DISTINCT s.group_no) FILTER (WHERE s.status IN ('upcoming','running'))::int AS groups_remaining
FROM meetings m
LEFT JOIN meeting_schedule s ON s.meeting_id = m.id
GROUP BY m.id;

REVOKE ALL ON meetings_overview FROM anon;
GRANT SELECT ON meetings_overview TO authenticated;

-- ------------------------------------------------------------
-- 5. FUNCTIONS (called from Flutter with supabase.rpc)
-- ------------------------------------------------------------

-- Server clock (app uses it to correct phone clock differences)
CREATE OR REPLACE FUNCTION server_now() RETURNS TIMESTAMPTZ
LANGUAGE sql STABLE AS $$ SELECT clock_timestamp() $$;

-- Excel import: creates one meeting per date. Dates already added are skipped.
-- p_rows = JSON array of {group_no, meeting_date, meeting_time, project, supervisor, reg_no, student_name, tech}
-- Returns JSON array: [{meeting_id, meeting_date, already_added, groups, students}]
CREATE OR REPLACE FUNCTION import_schedule(p_title TEXT, p_rows JSONB)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    d          DATE;
    v_id       BIGINT;
    v_exists   BOOLEAN;
    v_groups   INT;
    v_students INT;
    v_result   JSONB := '[]'::jsonb;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION 'No rows to import';
    END IF;

    FOR d IN
        SELECT DISTINCT (e->>'meeting_date')::date
        FROM jsonb_array_elements(p_rows) e
        ORDER BY 1
    LOOP
        SELECT id INTO v_id FROM meetings WHERE title = p_title AND meeting_date = d;
        v_exists := v_id IS NOT NULL;

        IF NOT v_exists THEN
            INSERT INTO meetings (title, meeting_date) VALUES (p_title, d) RETURNING id INTO v_id;

            INSERT INTO meeting_schedule
                (meeting_id, group_no, meeting_date, meeting_time, project, supervisor,
                 reg_no, student_name, tech)
            SELECT v_id, x.group_no, x.meeting_date, x.meeting_time, x.project, x.supervisor,
                   x.reg_no, x.student_name, x.tech
            FROM jsonb_to_recordset(p_rows) AS x(
                     group_no int, meeting_date date, meeting_time time, project text,
                     supervisor text, reg_no text, student_name text, tech text)
            WHERE x.meeting_date = d;
        END IF;

        SELECT COUNT(DISTINCT s.group_no), COUNT(*) INTO v_groups, v_students
        FROM meeting_schedule s WHERE s.meeting_id = v_id;

        v_result := v_result || jsonb_build_object(
            'meeting_id', v_id, 'meeting_date', d, 'already_added', v_exists,
            'groups', v_groups, 'students', v_students);
    END LOOP;

    RETURN v_result;
END $$;

-- START meeting
CREATE OR REPLACE FUNCTION start_meeting(p_id BIGINT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM meetings WHERE status IN ('running', 'paused')) THEN
        RAISE EXCEPTION 'Another meeting is already running';
    END IF;

    UPDATE meetings SET status = 'running', started_at = clock_timestamp()
    WHERE id = p_id AND status = 'upcoming';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'This meeting cannot be started';
    END IF;
END $$;

-- PAUSE meeting
CREATE OR REPLACE FUNCTION pause_meeting(p_id BIGINT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE meetings SET status = 'paused', paused_at = clock_timestamp()
    WHERE id = p_id AND status = 'running';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meeting is not running';
    END IF;
END $$;

-- RESUME meeting (paused time is added to the meeting and to the running group)
CREATE OR REPLACE FUNCTION resume_meeting(p_id BIGINT) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_paused TIMESTAMPTZ;
    v_delta  INT;
BEGIN
    SELECT paused_at INTO v_paused FROM meetings
    WHERE id = p_id AND status = 'paused' FOR UPDATE;

    IF v_paused IS NULL THEN
        RAISE EXCEPTION 'Meeting is not paused';
    END IF;

    v_delta := EXTRACT(EPOCH FROM (clock_timestamp() - v_paused))::int;

    UPDATE meetings
    SET status = 'running', paused_at = NULL, paused_seconds = paused_seconds + v_delta
    WHERE id = p_id;

    UPDATE meeting_schedule SET paused_seconds = paused_seconds + v_delta
    WHERE meeting_id = p_id AND status = 'running';
END $$;

-- END meeting: running group -> done, groups never held -> skipped
CREATE OR REPLACE FUNCTION end_meeting(p_id BIGINT) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    m       meetings%ROWTYPE;
    v_now   TIMESTAMPTZ := clock_timestamp();
    v_extra INT := 0;
BEGIN
    SELECT * INTO m FROM meetings
    WHERE id = p_id AND status IN ('running', 'paused') FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meeting is not running';
    END IF;

    IF m.status = 'paused' THEN
        v_extra := EXTRACT(EPOCH FROM (v_now - m.paused_at))::int;
    END IF;

    UPDATE meeting_schedule
    SET status = 'done',
        ended_at = v_now,
        paused_seconds = paused_seconds + v_extra,
        duration_sec = GREATEST(0, EXTRACT(EPOCH FROM (v_now - started_at))::int
                                   - (paused_seconds + v_extra))
    WHERE meeting_id = p_id AND status = 'running';

    UPDATE meeting_schedule SET status = 'skipped'
    WHERE meeting_id = p_id AND status = 'upcoming';

    UPDATE meetings
    SET status = 'done',
        ended_at = v_now,
        paused_at = NULL,
        paused_seconds = paused_seconds + v_extra,
        total_seconds = GREATEST(0, EXTRACT(EPOCH FROM (v_now - started_at))::int
                                    - (paused_seconds + v_extra))
    WHERE id = p_id;
END $$;

-- START a group (any order; only while the meeting is running; one group at a time)
CREATE OR REPLACE FUNCTION group_start(p_meeting BIGINT, p_group INT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM 1 FROM meetings WHERE id = p_meeting AND status = 'running' FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meeting is not running';
    END IF;

    IF EXISTS (SELECT 1 FROM meeting_schedule
               WHERE meeting_id = p_meeting AND status = 'running') THEN
        RAISE EXCEPTION 'Another group is already running';
    END IF;

    UPDATE meeting_schedule
    SET status = 'running', started_at = clock_timestamp(),
        ended_at = NULL, paused_seconds = 0, duration_sec = NULL
    WHERE meeting_id = p_meeting AND group_no = p_group AND status = 'upcoming';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group % cannot be started', p_group;
    END IF;
END $$;

-- END a group
CREATE OR REPLACE FUNCTION group_end(p_meeting BIGINT, p_group INT) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
BEGIN
    PERFORM 1 FROM meetings WHERE id = p_meeting AND status = 'running' FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meeting is not running';
    END IF;

    UPDATE meeting_schedule
    SET status = 'done', ended_at = v_now,
        duration_sec = GREATEST(0, EXTRACT(EPOCH FROM (v_now - started_at))::int - paused_seconds)
    WHERE meeting_id = p_meeting AND group_no = p_group AND status = 'running';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group % is not running', p_group;
    END IF;
END $$;

-- ------------------------------------------------------------
-- 6. Only logged-in users can call the functions
-- ------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION server_now(), import_schedule(TEXT, JSONB),
    start_meeting(BIGINT), pause_meeting(BIGINT), resume_meeting(BIGINT), end_meeting(BIGINT),
    group_start(BIGINT, INT), group_end(BIGINT, INT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION server_now(), import_schedule(TEXT, JSONB),
    start_meeting(BIGINT), pause_meeting(BIGINT), resume_meeting(BIGINT), end_meeting(BIGINT),
    group_start(BIGINT, INT), group_end(BIGINT, INT)
    TO authenticated;

NOTIFY pgrst, 'reload schema';
