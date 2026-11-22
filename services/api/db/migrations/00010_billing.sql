-- PayNow payment requests, payments and receipts (build plan, Phase 8;
-- ADR 018, ADR 024). Penny never moves money: a request asks for it, the
-- payee and the payer each confirm it arrived, and the receipt records that
-- both did.

-- +goose Up
CREATE TYPE proxy_type AS ENUM ('mobile', 'uen');

CREATE TABLE payee_accounts (
    workspace_id        uuid        NOT NULL,
    membership_id       uuid        NOT NULL,
    proxy_type          proxy_type  NOT NULL,
    proxy_value         text        NOT NULL,
    display_name        text        NOT NULL,
    send_automatically  boolean     NOT NULL DEFAULT false,
    -- When the payee confirmed the test code showed their registered name.
    verified_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (workspace_id, membership_id),
    CONSTRAINT payee_accounts_membership_fkey FOREIGN KEY (workspace_id, membership_id)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT payee_accounts_display_name_length CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 25)
);

COMMENT ON TABLE payee_accounts IS 'Where a tutor receives PayNow: a mobile number or a UEN.';

CREATE TYPE payment_request_status AS ENUM ('draft', 'open', 'paid', 'cancelled');

CREATE TABLE payment_requests (
    id                   uuid                   PRIMARY KEY DEFAULT uuidv7(),
    workspace_id         uuid                   NOT NULL REFERENCES workspaces (id),
    -- PNY- and six Crockford base32 characters, unique within the team.
    reference            text                   NOT NULL,
    payee_membership_id  uuid                   NOT NULL,
    student_id           uuid                   NOT NULL,
    amount_cents         bigint                 NOT NULL,
    currency             char(3)                NOT NULL DEFAULT 'SGD',
    due_on               date                   NOT NULL,
    status               payment_request_status NOT NULL DEFAULT 'draft',
    note                 text                   NOT NULL DEFAULT '',
    sent_at              timestamptz,
    payer_confirmed_at   timestamptz,
    paid_at              timestamptz,
    cancelled_at         timestamptz,
    last_reminded_at     timestamptz,
    created_by           uuid                   NOT NULL REFERENCES users (id),
    created_at           timestamptz            NOT NULL DEFAULT now(),
    updated_at           timestamptz            NOT NULL DEFAULT now(),

    CONSTRAINT payment_requests_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT payment_requests_reference_key UNIQUE (workspace_id, reference),
    CONSTRAINT payment_requests_payee_fkey FOREIGN KEY (workspace_id, payee_membership_id)
        REFERENCES workspace_memberships (workspace_id, id),
    CONSTRAINT payment_requests_student_fkey FOREIGN KEY (workspace_id, student_id)
        REFERENCES students (workspace_id, id),
    CONSTRAINT payment_requests_amount_positive CHECK (amount_cents > 0),
    CONSTRAINT payment_requests_reference_format CHECK (reference ~ '^PNY-[0-9A-HJKMNP-TV-Z]{6}$'),
    CONSTRAINT payment_requests_paid_when_paid CHECK ((status = 'paid') = (paid_at IS NOT NULL)),
    CONSTRAINT payment_requests_cancelled_when_cancelled CHECK ((status = 'cancelled') = (cancelled_at IS NOT NULL)),
    CONSTRAINT payment_requests_note_length CHECK (char_length(note) <= 500)
);

CREATE INDEX payment_requests_by_created ON payment_requests (workspace_id, created_at DESC, id DESC);
CREATE INDEX payment_requests_open_due ON payment_requests (due_on) WHERE status = 'open';

CREATE TABLE payment_request_lines (
    id            uuid    PRIMARY KEY DEFAULT uuidv7(),
    workspace_id  uuid    NOT NULL,
    request_id    uuid    NOT NULL,
    position      integer NOT NULL,
    lesson_id     uuid,
    description   text    NOT NULL,
    amount_cents  bigint  NOT NULL,
    -- The lesson had several tutors: the payee, its lead, bills it whole and
    -- the split is arranged outside Penny (ADR 018).
    co_taught     boolean NOT NULL DEFAULT false,
    -- True while the request is a draft, open or paid, so a lesson is on at
    -- most one live request at a time.
    live          boolean NOT NULL DEFAULT true,

    CONSTRAINT payment_request_lines_request_fkey FOREIGN KEY (workspace_id, request_id)
        REFERENCES payment_requests (workspace_id, id),
    CONSTRAINT payment_request_lines_lesson_fkey FOREIGN KEY (workspace_id, lesson_id)
        REFERENCES lessons (workspace_id, id),
    CONSTRAINT payment_request_lines_amount_positive CHECK (amount_cents > 0),
    CONSTRAINT payment_request_lines_description_length CHECK (char_length(btrim(description)) BETWEEN 1 AND 200)
);

CREATE UNIQUE INDEX payment_request_lines_lesson_once ON payment_request_lines (lesson_id) WHERE live AND lesson_id IS NOT NULL;
CREATE INDEX payment_request_lines_by_request ON payment_request_lines (workspace_id, request_id, position);

CREATE TABLE payment_links (
    id            uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id  uuid        NOT NULL,
    request_id    uuid        NOT NULL,
    -- SHA-256 of the 128-bit token in the link. The token is never stored.
    token_hash    bytea       NOT NULL,
    expires_at    timestamptz NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT payment_links_token_hash_key UNIQUE (token_hash),
    CONSTRAINT payment_links_request_fkey FOREIGN KEY (workspace_id, request_id)
        REFERENCES payment_requests (workspace_id, id)
);

COMMENT ON TABLE payment_links IS 'Links to a request''s public page: one shown in the app, one per email. They stop working once the request is paid or cancelled.';

CREATE TYPE payment_method AS ENUM ('paynow', 'bank_transfer', 'cash', 'other');

CREATE TABLE payment_records (
    id            uuid           PRIMARY KEY DEFAULT uuidv7(),
    workspace_id  uuid           NOT NULL,
    request_id    uuid           NOT NULL,
    amount_cents  bigint         NOT NULL,
    paid_on       date           NOT NULL,
    method        payment_method NOT NULL,
    recorded_by   uuid           NOT NULL REFERENCES users (id),
    -- Set when a voided receipt's correction replaces this record.
    superseded_at timestamptz,
    created_at    timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT payment_records_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT payment_records_request_fkey FOREIGN KEY (workspace_id, request_id)
        REFERENCES payment_requests (workspace_id, id),
    CONSTRAINT payment_records_amount_positive CHECK (amount_cents > 0)
);

COMMENT ON TABLE payment_records IS 'The payee''s confirmation that money arrived.';

CREATE UNIQUE INDEX payment_records_one_live ON payment_records (request_id) WHERE superseded_at IS NULL;

CREATE TABLE receipt_counters (
    workspace_id  uuid    PRIMARY KEY REFERENCES workspaces (id),
    last_number   integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE receipt_counters IS 'Gapless receipt numbers: the row is locked inside the issuing transaction, so a rollback never skips a number.';

CREATE TABLE receipts (
    id                   uuid        PRIMARY KEY DEFAULT uuidv7(),
    workspace_id         uuid        NOT NULL,
    receipt_number       integer     NOT NULL,
    payment_record_id    uuid        NOT NULL,
    request_id           uuid        NOT NULL,
    issued_at            timestamptz NOT NULL,
    -- What the receipt says, as it was when issued. The PDF is rendered
    -- from these alone, so renaming a team, tutor or student never changes
    -- a receipt or its hash.
    team_name            text        NOT NULL,
    payee_name           text        NOT NULL,
    student_name         text        NOT NULL,
    reference            text        NOT NULL,
    lines                jsonb       NOT NULL,
    amount_cents         bigint      NOT NULL,
    currency             char(3)     NOT NULL,
    paid_on              date        NOT NULL,
    method               payment_method NOT NULL,
    co_taught            boolean     NOT NULL,
    -- The team's timezone when issued, in which the PDF shows times.
    timezone             text        NOT NULL,
    replaces_number      integer,
    content_sha256       text        NOT NULL,
    replaces_receipt_id  uuid,
    voided_at            timestamptz,
    voided_by            uuid        REFERENCES users (id),
    void_reason          text,

    CONSTRAINT receipts_workspace_id_id_key UNIQUE (workspace_id, id),
    CONSTRAINT receipts_number_key UNIQUE (workspace_id, receipt_number),
    CONSTRAINT receipts_payment_record_key UNIQUE (payment_record_id),
    CONSTRAINT receipts_payment_record_fkey FOREIGN KEY (workspace_id, payment_record_id)
        REFERENCES payment_records (workspace_id, id),
    CONSTRAINT receipts_request_fkey FOREIGN KEY (workspace_id, request_id)
        REFERENCES payment_requests (workspace_id, id),
    CONSTRAINT receipts_replaces_fkey FOREIGN KEY (workspace_id, replaces_receipt_id)
        REFERENCES receipts (workspace_id, id),
    CONSTRAINT receipts_voided_together CHECK (
        (voided_at IS NULL AND voided_by IS NULL AND void_reason IS NULL) OR
        (voided_at IS NOT NULL AND voided_by IS NOT NULL AND char_length(btrim(void_reason)) > 0)),
    CONSTRAINT receipts_sha256_format CHECK (content_sha256 ~ '^[0-9a-f]{64}$')
);

COMMENT ON TABLE receipts IS 'Immutable proof of one payment record. Only the void columns are ever set after issue.';

CREATE INDEX receipts_by_issued ON receipts (workspace_id, issued_at DESC, id DESC);

CREATE TABLE idempotency_keys (
    workspace_id  uuid        NOT NULL,
    user_id       uuid        NOT NULL,
    key           text        NOT NULL,
    operation     text        NOT NULL,
    entity_id     uuid        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (workspace_id, user_id, key)
);

COMMENT ON TABLE idempotency_keys IS 'Idempotency-Key headers already used, and what they created. Purged after a day (build plan, Phase 9).';
