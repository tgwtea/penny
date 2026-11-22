-- Student and parent accounts (build plan, Phase 10; ADR 025). An owner
-- gives a contact or a student access; Penny invites that address, and
-- the first verified sign-in links the record to the person.

-- +goose Up
ALTER TABLE student_contacts
    ADD COLUMN can_sign_in boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT student_contacts_sign_in_needs_email CHECK (NOT can_sign_in OR email IS NOT NULL),
    ADD CONSTRAINT student_contacts_linked_needs_access CHECK (user_id IS NULL OR can_sign_in);

ALTER TABLE students
    ADD COLUMN sign_in_email citext,
    ADD CONSTRAINT students_sign_in_email_not_blank CHECK (sign_in_email <> ''),
    ADD CONSTRAINT students_linked_needs_access CHECK (user_id IS NULL OR sign_in_email IS NOT NULL);

COMMENT ON COLUMN student_contacts.can_sign_in IS 'The owner gave this contact a parent account; user_id is set at their first verified sign-in.';
COMMENT ON COLUMN students.sign_in_email IS 'The owner gave the student an account at this address; user_id is set at their first verified sign-in.';

CREATE INDEX student_contacts_by_user ON student_contacts (workspace_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX students_by_user ON students (workspace_id, user_id) WHERE user_id IS NOT NULL;
