# Answer a personal data request

Use this when someone asks what Penny holds about them, asks for it to be corrected, or asks for it to be deleted (PDPA; see [docs/privacy.md](../privacy.md)). Respond as soon as you reasonably can, and within 30 days. If you will need longer, tell them so within the 30 days and say when they will hear.

Log each request where the team keeps its admin records: who asked, when, what for, what you sent and when.

## 1. Check who is asking

- **A person who signs in** asking about themselves: they can serve themselves. Point them at Account, then "Download my data". Nothing else to check.
- **A parent or student** asking about a student: they do not sign in, so the team's owner answers. Confirm the request comes from a contact on the student's record, from the email address on file, or from the student, before sending anything. A request from someone not on the record goes back with a polite refusal until the owner has confirmed who they are.
- **Anyone else**, including other team members: refuse. Their data is not yours to give.

## 2. Access

1. As the team's owner, export the student's record:

   ```sh
   curl -H "Authorization: Bearer $TOKEN" \
     https://api.<domain>/v1/workspaces/<team-id>/students/<student-id>/export > student.json
   ```

2. Read it before sending. Notes on a shared lesson can mention another student; remove other people's details, or leave the note out and say so.
3. Send it to the requester's address on file, as a file they can open, with a short note saying what it contains.

The export lists the student with their contacts and goals, every lesson they are in with its tasks, goals and notes, and every payment request and receipt. Each export is audited.

## 3. Correction

Edit the record in the app: the student, the contact or the note. Names on receipts already issued cannot change, because receipts are immutable. If a receipt is wrong, the payee voids it with the reason and issues a corrected one.

## 4. Deletion

- **A contact** who no longer wants to be contacted: remove them from the student, or switch off their emails. Receipts and lessons that mentioned them stay, without their contact details.
- **A student** who has left: archive them. Their lessons and payments stay as the team's records, which must be kept for 5 years.
- **A person who signs in**: Account, then "Delete my account". If they are the only owner of a team with other members, they must make someone else owner first.
- **A whole team, or a student's details after the retention period**: not built yet. Ask an engineer to remove the rows by hand in one transaction, keeping receipts and payment records for 5 years from their date, and record what was removed in the request log.

## 5. Close the request

Reply to the requester saying what you did. Keep the request log entry for as long as the team keeps its other admin records.
