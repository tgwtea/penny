-- Account deletion (PDPA, app store rules). A deleted user's row stays,
-- because lessons, payments, receipts and the audit log must keep pointing at
-- it, but its name, email and identity-provider link are replaced.

-- +goose Up
ALTER TABLE users ADD COLUMN deleted_at timestamptz;

COMMENT ON COLUMN users.deleted_at IS
    'When the person deleted their account. Name, email and firebase_uid are anonymised at the same time.';
