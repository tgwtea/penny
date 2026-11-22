# ADR 025: Family accounts are read-only and linked by invitation

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

Phase 10 lets students and parents sign in. The model reserved what it needs: `student` and `parent` values of `membership_role` with empty capability sets, and nullable `user_id` columns on `students` and `student_contacts` (docs/architecture.md, "Domain model"). Left open were how a person becomes linked to a student, what they may see and do, and how a parent pays once they can sign in.

Students are often minors. Lesson notes, other students in a group lesson and team members' details are sensitive, and a parent's or student's account must never reach them by accident.

## Decision

- **Access is given, never assumed.** An owner turns on "Can sign in" for a contact that has an email address, or gives a student a sign-in email. Penny then invites that address to the team as a `parent` or `student` membership, by the same invitation email teachers get. A contact or student whose email merely matches someone who signs in is not linked.
- **Linking happens at the first verified sign-in.** Claiming the invitation (Phase 4) also sets `student_contacts.user_id` or `students.user_id` on every record in the team that was given access for that address. One parent with two children in a team has one membership and two linked contact records.
- **Family accounts are read-only.** Two new capabilities: `view_linked_lessons` (students and parents) and `view_linked_payments` (parents). A student sees their own lessons; a parent sees the lessons of the students they are linked to. Each lesson shows its time, place, tutors and status, and only the items whose visibility allows it: `student` items to the student, `contacts` items to the student and their contacts; `staff` items to neither. Other students in a group lesson are counted, not named. Student notes, the team list and other students are never shown. Nothing can be created or changed, except one thing:
- **A signed-in parent pays as the payment page does.** They see their students' open requests with the same PayNow code and can say "I've paid", which is the payer's confirmation of ADR 024, recorded exactly as the public link's. They also see receipts and download their PDFs. No new link is made for a signed-in view.
- **Turning access off** clears the link on that record; when no linked record is left, the membership is removed. Removing a contact or archiving a student does the same.
- The family endpoints live under `/v1/workspaces/{id}/family/...`, so the staff endpoints stay closed to these roles by capability, and every family query is scoped to the caller's linked students in the service, not only in the screens.

## Consequences

- A parent who is also a teacher in the same team cannot have a second membership there: invitations are one per email per team, and the request is refused with a clear message. They can use a different email for the parent account.
- Capabilities gain two values, a breaking change to older clients by ADR 022's rule, accepted in `api/accepted-breaking-changes.txt` before any client is released.
- Messaging stays out of scope (ADR 015); a family account has no way to write to anyone.
