-- Row-level security, the second of the three layers of enforcement
-- (docs/architecture.md, "Enforcement, in three layers"). Every query is
-- already scoped by workspace_id in its store; these policies refuse
-- another team's rows even if one forgets, for the app role (penny_app),
-- which owns no tables. The migrator owns them and is not bound.
--
-- database.InWorkspaceTx sets app.workspace_id; database.InCrossTeamTx
-- sets app.cross_team for the few operations that span teams by design. A
-- transaction with neither sees no team's rows.

-- +goose Up
-- +goose StatementBegin
CREATE FUNCTION penny_in_scope(ws uuid) RETURNS boolean
LANGUAGE sql STABLE PARALLEL SAFE
AS $$
    SELECT ws = nullif(current_setting('app.workspace_id', true), '')::uuid
        OR coalesce(current_setting('app.cross_team', true), '') = 'on'
$$;
-- +goose StatementEnd

COMMENT ON FUNCTION penny_in_scope(uuid) IS
    'Whether the current transaction may see rows of team ws: its own team, or every team for cross-team work.';

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY team_scope ON workspaces USING (penny_in_scope(id)) WITH CHECK (penny_in_scope(id));

-- +goose StatementBegin
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'workspace_memberships', 'audit_events',
        'students', 'student_contacts', 'student_goals', 'locations',
        'lessons', 'lesson_tutors', 'lesson_participants', 'lesson_items', 'cancellation_policies',
        'lesson_series', 'lesson_series_tutors', 'lesson_series_students', 'calendar_feeds',
        'email_log',
        'payee_accounts', 'payment_requests', 'payment_request_lines', 'payment_links', 'payment_records',
        'receipt_counters', 'receipts', 'idempotency_keys'
    ] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('CREATE POLICY team_scope ON %I USING (penny_in_scope(workspace_id)) WITH CHECK (penny_in_scope(workspace_id))', t);
    END LOOP;
END $$;
-- +goose StatementEnd

-- Records that must not change after the fact, for every role: the audit
-- log is append-only, and a receipt only ever gains its void fields, once.

-- +goose StatementBegin
CREATE FUNCTION penny_append_only() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = 'insufficient_privilege';
END
$$;
-- +goose StatementEnd

CREATE TRIGGER audit_events_append_only
    BEFORE UPDATE OR DELETE ON audit_events
    FOR EACH ROW EXECUTE FUNCTION penny_append_only();

-- +goose StatementBegin
CREATE FUNCTION penny_receipt_immutable() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'receipts are never deleted; void one instead' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF OLD.voided_at IS NOT NULL
        OR to_jsonb(NEW) - 'voided_at' - 'voided_by' - 'void_reason'
           IS DISTINCT FROM to_jsonb(OLD) - 'voided_at' - 'voided_by' - 'void_reason' THEN
        RAISE EXCEPTION 'a receipt only changes by being voided, once' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
END
$$;
-- +goose StatementEnd

CREATE TRIGGER receipts_immutable
    BEFORE UPDATE OR DELETE ON receipts
    FOR EACH ROW EXECUTE FUNCTION penny_receipt_immutable();
