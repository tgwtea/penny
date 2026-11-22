# Respond to a data breach

Use this when personal data may have been seen, copied, changed or lost by someone who should not have it: a leaked database dump or backup, a stolen laptop with a production credential, a bug that showed one team's records to another, an email sent to the wrong parent in bulk.

Under the PDPA, a breach is **notifiable** when it is likely to cause significant harm to the people affected, or when it affects 500 or more people. Assess whether it is notifiable within 30 days of finding it; once you decide it is, tell the PDPC within 3 calendar days, and tell the people affected as soon as you can (unless the PDPC says otherwise). Students are often minors, and lesson notes and contact details are sensitive, so lean towards "significant harm".

Keep a timeline from the first minute: what you saw, when, and what you did.

## 1. Contain (first hour)

1. Stop the leak. Depending on the cause:
   - Revoke the credential: rotate the database role's password (`penny-app-db`, `penny-migrator-db`), the Postmark token, the unsubscribe secret, or the Firebase service account.
   - Roll back the release that caused it (ArgoCD: sync the previous revision).
   - Take the affected endpoint out of service if the bug cannot be rolled back quickly.
2. Preserve evidence. Do not delete logs or rows. Copy the relevant API and ingress logs and the audit events for the window.

## 2. Assess (within days, at most 30)

Answer, and write the answers into the timeline:

- What data: names, contact details, lesson notes, PayNow numbers, receipts?
- Whose, and how many: which teams, how many students, contacts and team members? The audit log (`audit_events`) and the email log (`email_log`) help to count.
- Who got it, and can it be recovered or confirmed deleted?
- What harm is likely: identity theft, someone contacting a child, financial loss, embarrassment?

If the breach is likely to cause significant harm, or affects 500 or more people, it is notifiable.

## 3. Notify (within 3 calendar days of deciding it is notifiable)

- **The PDPC**, through its data breach notification form, with what you know so far. You can update it later.
- **The people affected**, unless the PDPC directs otherwise: what happened, what data, what you have done, what they can do, and whom to contact. For students, write to their contacts.
- **Each affected team's owner**, since the records are theirs.

## 4. Fix and review

1. Fix the cause and add a test that would have caught it.
2. Write a short post-incident review: timeline, cause, what worked, what to change. Link it from this runbook's history.
3. If the cause was a gap in a check (an ASVS item, a row-level security policy, a missing rate limit), update [docs/security.md](../security.md).
