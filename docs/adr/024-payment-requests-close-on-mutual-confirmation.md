# ADR 024: Payment requests close on mutual confirmation

- **Status:** Accepted. Settles the "who collects?" open question in docs/architecture.md and changes its payment flow
- **Date:** 2026-11-22

## Context

The build plan's payment flow made the payee's confirmation the source of truth: the payer could tap "I've paid", which only notified the payee, and the payee's confirmation alone produced the payment record and the receipt. It also left open who may create payment requests: the matrix said "Owner: yes; Teacher: open question (who collects?)".

The product owner decided (22 Nov 2026):

- Owners and teachers can both create payment requests.
- A new request is either sent to the parents at once or held until the person billing approves sending it; that is a setting, not a fixed rule.
- A request is closed only when both the teacher or owner and the parent have confirmed the payment.

## Decision

- **Who bills.** A request has one payee (ADR 018). Owners (`manage_payments`) may create and manage requests for any payee in the team. Teachers get a new capability, `manage_own_payments`, covering requests where they are the payee, for lessons they lead. Lines for lessons must be billable and led by the payee.
- **Sending.** Each payee's PayNow account carries `sendAutomatically`. When it is on, a new request goes straight to the student's billing contacts with its link; when off (the default), it stays a draft until the payee or an owner sends it.
- **Closing.** A request moves from open to paid only when both confirmations exist: the payee's (a payment record: amount, day and method, as now) and the payer's ("I've paid" on the public page, recorded with its time). Either may come first. The receipt is issued, numbered and emailed at the moment the second confirmation arrives, from the payment record. A request with only one confirmation shows who it is waiting for.
- Penny still never moves or sees money; both confirmations are statements by people, and the receipt records that both made them.

## Consequences

- A receipt now means "both sides agreed this was paid", which is stronger evidence in a dispute than the payee's word alone.
- A parent who never taps "I've paid" leaves the request open forever. Payment reminders for overdue requests stop once either side has confirmed, so they never chase a parent who has paid or says they have; the request shows "Waiting for the parent to confirm" or "Waiting for you to confirm".
- A receipt voided without a correction means the payment is no longer agreed: the request reopens and both sides confirm again. A receipt voided with a correction records what really arrived and issues a new receipt that replaces it; the request stays paid. If this becomes common, revisit with a "close without the parent" action for owners, audited, which would need a new ADR.
- `manage_own_payments` is a new value of the contract's `Capability` enum. Older clients that reject unknown enum values (ADR 022) would fail to read `/v1/me`; no client was released before it, so nothing breaks now.
