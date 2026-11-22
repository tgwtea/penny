# Personal data in Penny

Singapore's Personal Data Protection Act (PDPA) applies to the teams that use Penny, and to Penny as the service that holds their records. This page says what personal data Penny holds, why, for how long, and how each kind of request is answered. The [data requests runbook](runbooks/data-requests.md) has the steps; the [breach runbook](runbooks/breach-response.md) covers notification.

Students are often minors, so contact details, lesson notes and payment details are treated as sensitive throughout: they never appear in logs, metrics or audit payloads (docs/architecture.md, "Observability").

## What is held, and why

| Data | About | Why Penny needs it | Module |
| --- | --- | --- | --- |
| Name, email, sign-in ID | People who sign in | To sign them in and show who did what | `identity` |
| Name, email, role in each team | Team members | So the team knows who teaches and who owns it | `workspace` |
| Student name, notes, goals | Students | To schedule and teach them | `scheduling` |
| Contact name, email, phone, relationship, email choices | Parents and other contacts | To send reminders, payment requests and receipts | `scheduling` |
| Lessons, attendance, tasks, goals and notes | Students and tutors | The team's teaching record | `scheduling` |
| PayNow mobile number or UEN, display name | Payees | To put the right recipient in each PayNow code | `billing` |
| Payment requests, payment records, receipts | Students, payers, payees | The team's business records of what was billed and paid | `billing` |
| Email log: recipient address, category, outcome | Recipients | To answer "did the reminder arrive?" | `notify` |
| Audit log: who did what, when, to which record (IDs and statuses only) | Team members | To trace changes and settle disputes | `audit` |

Penny never sees money or bank details beyond the payee's PayNow proxy. Firebase Authentication holds sign-in credentials; Postmark delivers email and keeps its own delivery logs. Both are processors under their own terms.

## How long it is kept

| Data | Kept for | Then |
| --- | --- | --- |
| Idempotency keys | 1 day | Deleted by the daily `retention` job |
| Payment links | Until 90 days past the due day, plus 30 days | Their hashes are deleted by the `retention` job |
| Email log | 1 year | Deleted by the `retention` job |
| Background jobs | River's defaults: a day once done, a week once discarded | Deleted by River |
| A deleted account's name and email | Not kept | Removed at once by `DELETE /v1/me`; the row stays, anonymised, so records that mention it stay intact |
| Payment requests, payment records, receipts | As long as the team exists, and at least 5 years | Businesses in Singapore keep their records for 5 years; receipts are immutable and are never deleted |
| Audit log | As long as the team exists | Append-only for every role (migration 00011) |
| Students, contacts, lessons, notes | Until the team removes them | Archived students keep their history; contacts can be removed at any time |
| Database backups | 30 days | Expired by the backup store's retention policy (`deploy/base/database/objectstore.yaml`) |

Deleting a whole team, and erasing an archived student's details after a retention period, are not built yet. Until they are, the runbook says how to handle such a request by hand.

## Requests from individuals

| Request | How it is answered |
| --- | --- |
| Access: a person who signs in | `GET /v1/me/export`, "Download my data" on the Account page: their profile, each team's record of them, their PayNow account and policies, and what they did |
| Access: a student or their family | The team's owner runs `GET /v1/workspaces/{id}/students/{id}/export`, reviews it (it can mention other people, such as a co-taught lesson's other students in a note) and passes it on |
| Correction | The ordinary edit screens: account name, member names, students and contacts. Receipts cannot be corrected in place; the payee voids one and issues a corrected one |
| Withdrawing consent to emails | The unsubscribe link in every reminder; contacts can also be switched off by the team. Receipts and payment requests always go to billing contacts while they are billing contacts |
| Deleting an account | `DELETE /v1/me`, "Delete my account": the person leaves every team and their name and email are removed. Refused while they are the only owner of a team with other members |

Every export is written to the audit log (`personal_data.exported`, `student.exported`).
