package httpapi

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"testing"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/notify"
)

// paymentStudio is the lesson studio with Mei Lin's PayNow account set up
// and checked, and two of her lessons with Arjun done.
type paymentStudio struct {
	lessonStudio
	lessons []gen.Lesson
	keys    int
}

func newPaymentStudio(t *testing.T) *paymentStudio {
	t.Helper()
	ps := &paymentStudio{lessonStudio: newLessonStudio(t)}
	ps.setAccount(t, ps.teacherID, ps.teacher, false)
	for _, d := range []int{10, 17} {
		ps.lessons = append(ps.lessons, ps.done(t, ps.book(t, at(d, 16, 0), at(d, 16, 45), ps.teacherID, ps.arjun.Id), ps.teacher))
	}
	// Booking queued reminders for lessons now past; they are not what
	// these tests are about.
	ps.api.runJobs(0)
	return ps
}

func (ps *paymentStudio) setAccount(t *testing.T, member openapi_types.UUID, who Person, auto bool) {
	t.Helper()
	set, err := ps.api.Client.SetPayeeAccountWithResponse(ps.ctx, ps.team.Id, member, gen.PayeeAccountInput{
		ProxyType: gen.ProxyTypeMobile, ProxyValue: "+65 9123 4567", DisplayName: "Mei Lin Tan", SendAutomatically: &auto,
	}, who.Auth)
	if err != nil || set.JSON200 == nil {
		t.Fatalf("set payee account = %v %s", err, set.Body)
	}
	if set.JSON200.ProxyValue != "+6591234567" || !strings.HasPrefix(set.JSON200.TestPayload, "000201") {
		t.Fatalf("payee account = %+v", set.JSON200)
	}
	verified, err := ps.api.Client.VerifyPayeeAccountWithResponse(ps.ctx, ps.team.Id, member, who.Auth)
	if err != nil || verified.JSON200 == nil || !verified.JSON200.Verified {
		t.Fatalf("verify = %v %s", err, verified.Body)
	}
}

func (ps *paymentStudio) done(t *testing.T, l gen.Lesson, who Person) gen.Lesson {
	t.Helper()
	done, err := ps.api.Client.CompleteLessonWithResponse(ps.ctx, ps.team.Id, l.Id, &gen.CompleteLessonParams{IfMatch: ifMatch(l)}, gen.CompleteLessonRequest{}, who.Auth)
	if err != nil || done.JSON200 == nil {
		t.Fatalf("complete = %v %s", err, done.Body)
	}
	return *done.JSON200
}

func (ps *paymentStudio) key() string {
	ps.keys++
	return fmt.Sprintf("test-key-%04d", ps.keys)
}

// request asks for Arjun's done lessons as Mei Lin, due 26 November.
func (ps *paymentStudio) request(t *testing.T, who Person) gen.PaymentRequestWithLink {
	t.Helper()
	ids := []openapi_types.UUID{ps.lessons[0].Id, ps.lessons[1].Id}
	resp, err := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &ids,
			ExtraLines: &[]gen.ExtraLine{{Description: "Grade 5 theory book", AmountCents: 1890}}}, who.Auth)
	if err != nil || resp.JSON201 == nil {
		t.Fatalf("create request = %v %s", err, resp.Body)
	}
	return *resp.JSON201
}

func (ps *paymentStudio) send(t *testing.T, id openapi_types.UUID) gen.PaymentRequestWithLink {
	t.Helper()
	sent, err := ps.api.Client.SendPaymentRequestWithResponse(ps.ctx, ps.team.Id, id, ps.teacher.Auth)
	if err != nil || sent.JSON200 == nil {
		t.Fatalf("send = %v %s", err, sent.Body)
	}
	return *sent.JSON200
}

func (ps *paymentStudio) record(t *testing.T, id openapi_types.UUID, cents int64) gen.PaymentRequest {
	t.Helper()
	resp, err := ps.api.Client.RecordPaymentWithResponse(ps.ctx, ps.team.Id, id, &gen.RecordPaymentParams{IdempotencyKey: ps.key()},
		gen.PaymentInput{AmountCents: cents, PaidOn: day(19), Method: gen.PaymentMethodPaynow}, ps.teacher.Auth)
	if err != nil || resp.JSON200 == nil {
		t.Fatalf("record payment = %v %s", err, resp.Body)
	}
	return *resp.JSON200
}

func (ps *paymentStudio) payerConfirms(t *testing.T, token string) gen.PublicPaymentRequest {
	t.Helper()
	resp, err := ps.api.Client.ConfirmPaidByPayerWithResponse(ps.ctx, token)
	if err != nil || resp.JSON200 == nil {
		t.Fatalf("I've paid = %v %s", err, resp.Body)
	}
	return *resp.JSON200
}

var payLink = regexp.MustCompile(`http://localhost:5173/pay/([A-Za-z0-9_-]{22})`)

// emailedToken is the payment link token in the newest email to addr.
func (ps *paymentStudio) emailedToken(t *testing.T, addr string) string {
	t.Helper()
	sent := ps.api.Mailer.Sent()
	for i := len(sent) - 1; i >= 0; i-- {
		if sent[i].To.Email == addr {
			if m := payLink.FindStringSubmatch(sent[i].Text); m != nil {
				return m[1]
			}
		}
	}
	t.Fatalf("no payment link emailed to %s", addr)
	return ""
}

func emailsTo(sent []notify.Message, addr string, c notify.Category) []notify.Message {
	var out []notify.Message
	for _, m := range sent {
		if m.To.Email == addr && m.Category == c {
			out = append(out, m)
		}
	}
	return out
}

func TestAPaymentRequestClosesWhenBothSidesConfirm(t *testing.T) {
	ps := newPaymentStudio(t)
	created := ps.request(t, ps.teacher)
	r := created.Request
	if created.Link != nil || r.Status != gen.PaymentRequestStatusDraft {
		t.Fatalf("new request = %s with link %v, want a draft without one", r.Status, created.Link)
	}
	if r.AmountCents != 13890 || len(r.Lines) != 3 || r.Lines[0].Description != "Guitar, Grade 5, Tue 10 Nov 2026" || !regexp.MustCompile(`^PNY-[0-9A-Z]{6}$`).MatchString(r.Reference) {
		t.Errorf("request = %d cents, lines %+v, reference %s", r.AmountCents, r.Lines, r.Reference)
	}
	billable, _ := ps.api.Client.ListBillableLessonsWithResponse(ps.ctx, ps.team.Id, &gen.ListBillableLessonsParams{}, ps.teacher.Auth)
	if n := len(billable.JSON200.Items); n != 0 {
		t.Errorf("%d lessons still billable once on a request, want none", n)
	}
	if n := len(ps.api.queued("payment_request_email")); n != 0 {
		t.Fatalf("a draft queued %d emails", n)
	}

	sent := ps.send(t, r.Id)
	if sent.Request.Status != gen.PaymentRequestStatusOpen || deref(sent.Request.WaitingFor) != gen.WaitingForBoth || sent.Link == nil {
		t.Fatalf("sent = %+v", sent)
	}
	ps.api.runJobs(0)
	emails := emailsTo(ps.api.Mailer.Sent(), "parent.arjun@example.com", notify.PaymentRequests)
	if len(emails) != 1 || emails[0].Subject != "Payment request from Mei Lin Tan: S$ 138.90 for Arjun's lessons" {
		t.Fatalf("request emails = %+v", emails)
	}
	for _, want := range []string{"by Thursday 26 November", "Guitar, Grade 5, Tue 17 Nov 2026: S$ 60.00", r.Reference, "Cancellation policy:"} {
		if !strings.Contains(emails[0].Text, want) {
			t.Errorf("request email lacks %q:\n%s", want, emails[0].Text)
		}
	}
	token := ps.emailedToken(t, "parent.arjun@example.com")
	if strings.HasSuffix(*sent.Link, token) {
		t.Error("the parent's link is the tutor's; each send gets its own")
	}

	page, err := ps.api.Client.GetPublicPaymentRequestWithResponse(ps.ctx, token)
	if err != nil || page.JSON200 == nil {
		t.Fatalf("public page = %v %s", err, page.Body)
	}
	p := page.JSON200
	if p.StudentFirstName != "Arjun" || p.PayeeName != "Mei Lin Tan" || p.TeamName != "Koh Guitar Studio" || p.AmountCents != 13890 || p.PayerConfirmed {
		t.Errorf("public page = %+v", p)
	}
	if p.PaynowPayload == nil || !strings.Contains(*p.PaynowPayload, "5406138.90") || !strings.Contains(*p.PaynowPayload, r.Reference) {
		t.Errorf("PayNow payload = %v, want the amount and reference", p.PaynowPayload)
	}
	if strings.Contains(string(page.Body), "Nair") {
		t.Error("the public page shows the student's family name")
	}

	recorded := ps.record(t, r.Id, 13890)
	if recorded.Status != gen.PaymentRequestStatusOpen || deref(recorded.WaitingFor) != gen.WaitingForPayer || recorded.Receipt != nil {
		t.Fatalf("after the payee confirms = %s waiting for %v, receipt %v", recorded.Status, recorded.WaitingFor, recorded.Receipt)
	}
	if recorded.Payment == nil || recorded.Payment.RecordedBy != "Mei Lin Tan" {
		t.Errorf("payment = %+v", recorded.Payment)
	}

	confirmed := ps.payerConfirms(t, token)
	if confirmed.Status != gen.PaymentRequestStatusPaid || !confirmed.PayerConfirmed || confirmed.PaynowPayload != nil {
		t.Fatalf("after the payer confirms = %+v", confirmed)
	}
	paid, _ := ps.api.Client.GetPaymentRequestWithResponse(ps.ctx, ps.team.Id, r.Id, ps.owner.Auth)
	if paid.JSON200.Receipt == nil || paid.JSON200.Receipt.Number != "R-0001" || paid.JSON200.WaitingFor != nil {
		t.Fatalf("paid request = %s", paid.Body)
	}

	ps.api.runJobs(0)
	sentNow := ps.api.Mailer.Sent()
	receipts := emailsTo(sentNow, "parent.arjun@example.com", notify.Receipts)
	if len(receipts) != 1 || len(receipts[0].Attachments) != 1 || receipts[0].Attachments[0].Filename != "Receipt R-0001.pdf" {
		t.Fatalf("receipt emails = %+v", receipts)
	}
	updates := emailsTo(sentNow, "meilin@kohguitar.example", notify.PaymentUpdates)
	if len(updates) != 1 || updates[0].Subject != r.Reference+" is paid" {
		t.Errorf("payee updates = %+v", updates)
	}

	receipt, _ := ps.api.Client.GetReceiptWithResponse(ps.ctx, ps.team.Id, paid.JSON200.Receipt.Id, ps.teacher.Auth)
	pdf, err := ps.api.Client.GetReceiptPdfWithResponse(ps.ctx, ps.team.Id, receipt.JSON200.Id, ps.teacher.Auth)
	if err != nil || pdf.StatusCode() != http.StatusOK || !bytes.HasPrefix(pdf.Body, []byte("%PDF")) {
		t.Fatalf("PDF = %v %d", err, pdf.StatusCode())
	}
	sum := sha256.Sum256(pdf.Body)
	if hex.EncodeToString(sum[:]) != receipt.JSON200.ContentSha256 || !bytes.Equal(pdf.Body, receipts[0].Attachments[0].Content) {
		t.Error("the PDF's hash does not match its receipt, or differs from the one emailed")
	}

	reopened, err := ps.api.Client.ReopenLessonWithResponse(ps.ctx, ps.team.Id, ps.lessons[0].Id, &gen.ReopenLessonParams{IfMatch: ifMatch(ps.lessons[0])}, ps.owner.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "reopening a billed lesson", reopened.StatusCode(), reopened.Body, http.StatusConflict, "")
}

func TestThePayerMayConfirmFirst(t *testing.T) {
	ps := newPaymentStudio(t)
	r := ps.request(t, ps.teacher).Request
	ps.send(t, r.Id)
	ps.api.runJobs(0)
	token := ps.emailedToken(t, "parent.arjun@example.com")

	ps.payerConfirms(t, token)
	again := ps.payerConfirms(t, token)
	if again.Status != gen.PaymentRequestStatusOpen || !again.PayerConfirmed {
		t.Fatalf("after the payer confirms = %+v", again)
	}
	got, _ := ps.api.Client.GetPaymentRequestWithResponse(ps.ctx, ps.team.Id, r.Id, ps.teacher.Auth)
	if deref(got.JSON200.WaitingFor) != gen.WaitingForPayee {
		t.Errorf("waiting for %v, want the payee", got.JSON200.WaitingFor)
	}
	ps.api.runJobs(0)
	updates := emailsTo(ps.api.Mailer.Sent(), "meilin@kohguitar.example", notify.PaymentUpdates)
	if len(updates) != 1 || !strings.Contains(updates[0].Text, "says they paid S$ 138.90") {
		t.Fatalf("payee updates = %+v", updates)
	}

	paid := ps.record(t, r.Id, 13890)
	if paid.Status != gen.PaymentRequestStatusPaid || paid.Receipt == nil {
		t.Fatalf("after both confirm = %s, receipt %v", paid.Status, paid.Receipt)
	}
}

func TestTeachersBillOnlyForThemselves(t *testing.T) {
	ps := newPaymentStudio(t)
	ps.setAccount(t, ps.ownerMember, ps.owner, false)
	owners := ps.done(t, ps.book(t, at(18, 10, 0), at(18, 10, 45), ps.ownerMember, ps.sofia.Id), ps.owner)

	forOwner, err := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.sofia.Id, PayeeId: ps.ownerMember, DueOn: day(26), LessonIds: &[]openapi_types.UUID{owners.Id}}, ps.teacher.Auth)
	if err != nil {
		t.Fatal(err)
	}
	wantProblem(t, "a teacher billing for the owner", forOwner.StatusCode(), forOwner.Body, http.StatusNotFound, "")

	theirs, err := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.sofia.Id, PayeeId: ps.ownerMember, DueOn: day(26), LessonIds: &[]openapi_types.UUID{owners.Id}}, ps.owner.Auth)
	if err != nil || theirs.JSON201 == nil {
		t.Fatalf("owner's request = %v %s", err, theirs.Body)
	}
	mine := ps.request(t, ps.teacher)

	list, _ := ps.api.Client.ListPaymentRequestsWithResponse(ps.ctx, ps.team.Id, &gen.ListPaymentRequestsParams{}, ps.teacher.Auth)
	if len(list.JSON200.Items) != 1 || list.JSON200.Items[0].Id != mine.Request.Id {
		t.Errorf("teacher sees %d requests, want only her own", len(list.JSON200.Items))
	}
	all, _ := ps.api.Client.ListPaymentRequestsWithResponse(ps.ctx, ps.team.Id, &gen.ListPaymentRequestsParams{}, ps.owner.Auth)
	if len(all.JSON200.Items) != 2 {
		t.Errorf("owner sees %d requests, want both", len(all.JSON200.Items))
	}
	hidden, _ := ps.api.Client.GetPaymentRequestWithResponse(ps.ctx, ps.team.Id, theirs.JSON201.Request.Id, ps.teacher.Auth)
	wantProblem(t, "a teacher reading the owner's request", hidden.StatusCode(), hidden.Body, http.StatusNotFound, "")
	account, _ := ps.api.Client.GetPayeeAccountWithResponse(ps.ctx, ps.team.Id, ps.ownerMember, ps.teacher.Auth)
	wantProblem(t, "a teacher reading the owner's PayNow account", account.StatusCode(), account.Body, http.StatusForbidden, "")

	// The owner may send and record for Mei Lin.
	if _, err := ps.api.Client.SendPaymentRequestWithResponse(ps.ctx, ps.team.Id, mine.Request.Id, ps.owner.Auth); err != nil {
		t.Fatal(err)
	}
}

func TestARequestNeedsBillableLessonsOfThePayee(t *testing.T) {
	ps := newPaymentStudio(t)
	upcoming := ps.book(t, at(24, 16, 0), at(24, 16, 45), ps.teacherID, ps.arjun.Id)
	sofias := ps.done(t, ps.book(t, at(18, 17, 0), at(18, 17, 45), ps.teacherID, ps.sofia.Id), ps.teacher)

	for _, c := range []struct {
		what   string
		in     gen.PaymentRequestInput
		status int
	}{
		{"a lesson not done yet", gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &[]openapi_types.UUID{upcoming.Id}}, http.StatusBadRequest},
		{"another student's lesson", gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &[]openapi_types.UUID{sofias.Id}}, http.StatusBadRequest},
		{"a due day in the past", gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(18), LessonIds: &[]openapi_types.UUID{ps.lessons[0].Id}}, http.StatusBadRequest},
		{"nothing to bill", gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26)}, http.StatusBadRequest},
		{"a payee without a checked account", gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.ownerMember, DueOn: day(26), ExtraLines: &[]gen.ExtraLine{{Description: "Book", AmountCents: 100}}}, http.StatusConflict},
	} {
		resp, err := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()}, c.in, ps.owner.Auth)
		if err != nil {
			t.Fatal(err)
		}
		wantProblem(t, c.what, resp.StatusCode(), resp.Body, c.status, "")
	}

	ps.request(t, ps.teacher)
	twice, _ := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &[]openapi_types.UUID{ps.lessons[0].Id}}, ps.teacher.Auth)
	wantProblem(t, "billing a lesson twice", twice.StatusCode(), twice.Body, http.StatusConflict, "")
}

func TestRetriedWritesHappenOnce(t *testing.T) {
	ps := newPaymentStudio(t)
	ids := []openapi_types.UUID{ps.lessons[0].Id}
	params := &gen.CreatePaymentRequestParams{IdempotencyKey: "create-arjun-november"}
	body := gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &ids}
	first, _ := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, params, body, ps.teacher.Auth)
	second, _ := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, params, body, ps.teacher.Auth)
	if first.JSON201 == nil || second.JSON201 == nil || first.JSON201.Request.Id != second.JSON201.Request.Id {
		t.Fatalf("retry = %s / %s, want the same request", first.Body, second.Body)
	}
	ps.send(t, first.JSON201.Request.Id)

	pay := &gen.RecordPaymentParams{IdempotencyKey: "pay-arjun-november"}
	in := gen.PaymentInput{AmountCents: 6000, PaidOn: day(19), Method: gen.PaymentMethodPaynow}
	for range 2 {
		resp, _ := ps.api.Client.RecordPaymentWithResponse(ps.ctx, ps.team.Id, first.JSON201.Request.Id, pay, in, ps.teacher.Auth)
		if resp.JSON200 == nil {
			t.Fatalf("record = %d %s", resp.StatusCode(), resp.Body)
		}
	}
	var records int
	if err := ps.api.Pool.QueryRow(ps.ctx, `SELECT count(*) FROM payment_records`).Scan(&records); err != nil || records != 1 {
		t.Errorf("payment records = %d, %v; want 1", records, err)
	}
	reused, _ := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: "pay-arjun-november"}, body, ps.teacher.Auth)
	wantProblem(t, "a key reused for another change", reused.StatusCode(), reused.Body, http.StatusConflict, "")
}

// paidRequest takes a request through to paid and returns it.
func (ps *paymentStudio) paidRequest(t *testing.T, lessons []openapi_types.UUID, cents int64) gen.PaymentRequest {
	t.Helper()
	resp, err := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &lessons}, ps.teacher.Auth)
	if err != nil || resp.JSON201 == nil {
		t.Fatalf("create = %v %s", err, resp.Body)
	}
	sent := ps.send(t, resp.JSON201.Request.Id)
	ps.payerConfirms(t, (*sent.Link)[strings.LastIndex(*sent.Link, "/")+1:])
	return ps.record(t, sent.Request.Id, cents)
}

func TestVoidingAReceiptCorrectsOrReopens(t *testing.T) {
	ps := newPaymentStudio(t)
	first := ps.paidRequest(t, []openapi_types.UUID{ps.lessons[0].Id}, 5000)
	second := ps.paidRequest(t, []openapi_types.UUID{ps.lessons[1].Id}, 6000)
	if first.Receipt.Number != "R-0001" || second.Receipt.Number != "R-0002" {
		t.Fatalf("receipts = %s, %s; want R-0001 and R-0002", first.Receipt.Number, second.Receipt.Number)
	}

	// The first was recorded short: void it with what really arrived.
	corrected, err := ps.api.Client.VoidReceiptWithResponse(ps.ctx, ps.team.Id, first.Receipt.Id, &gen.VoidReceiptParams{IdempotencyKey: ps.key()},
		gen.VoidReceiptInput{Reason: "Recorded S$ 50 by mistake; S$ 60 arrived.", Correction: &gen.PaymentInput{AmountCents: 6000, PaidOn: day(19), Method: gen.PaymentMethodPaynow}}, ps.teacher.Auth)
	if err != nil || corrected.JSON200 == nil {
		t.Fatalf("void with correction = %v %s", err, corrected.Body)
	}
	old := corrected.JSON200
	if old.Voided == nil || old.Voided.By != "Mei Lin Tan" || old.ReplacedByReceiptId == nil {
		t.Fatalf("voided receipt = %+v", old)
	}
	replacement, _ := ps.api.Client.GetReceiptWithResponse(ps.ctx, ps.team.Id, *old.ReplacedByReceiptId, ps.owner.Auth)
	if replacement.JSON200.Number != "R-0003" || replacement.JSON200.AmountCents != 6000 || deref(replacement.JSON200.ReplacesReceiptId) != old.Id {
		t.Errorf("replacement = %s", replacement.Body)
	}
	still, _ := ps.api.Client.GetPaymentRequestWithResponse(ps.ctx, ps.team.Id, first.Id, ps.teacher.Auth)
	if still.JSON200.Status != gen.PaymentRequestStatusPaid || still.JSON200.Receipt.Number != "R-0003" {
		t.Errorf("corrected request = %s, receipt %+v", still.JSON200.Status, still.JSON200.Receipt)
	}

	// The second was never paid: void it, and both confirm again.
	reopened, _ := ps.api.Client.VoidReceiptWithResponse(ps.ctx, ps.team.Id, second.Receipt.Id, &gen.VoidReceiptParams{IdempotencyKey: ps.key()},
		gen.VoidReceiptInput{Reason: "The transfer bounced."}, ps.teacher.Auth)
	if reopened.JSON200 == nil || reopened.JSON200.ReplacedByReceiptId != nil {
		t.Fatalf("void = %s", reopened.Body)
	}
	open, _ := ps.api.Client.GetPaymentRequestWithResponse(ps.ctx, ps.team.Id, second.Id, ps.teacher.Auth)
	if open.JSON200.Status != gen.PaymentRequestStatusOpen || deref(open.JSON200.WaitingFor) != gen.WaitingForBoth || open.JSON200.Payment != nil {
		t.Errorf("reopened request = %s", open.Body)
	}
	twice, _ := ps.api.Client.VoidReceiptWithResponse(ps.ctx, ps.team.Id, second.Receipt.Id, &gen.VoidReceiptParams{IdempotencyKey: ps.key()},
		gen.VoidReceiptInput{Reason: "Again"}, ps.teacher.Auth)
	wantProblem(t, "voiding twice", twice.StatusCode(), twice.Body, http.StatusConflict, "")

	list, _ := ps.api.Client.ListReceiptsWithResponse(ps.ctx, ps.team.Id, &gen.ListReceiptsParams{}, ps.owner.Auth)
	var numbers []string
	for _, r := range list.JSON200.Items {
		numbers = append(numbers, fmt.Sprintf("%s:%v", r.Number, r.Voided))
	}
	if got := strings.Join(numbers, " "); got != "R-0003:false R-0002:true R-0001:true" {
		t.Errorf("receipts = %s", got)
	}
}

func TestWithdrawingARequestFreesItsLessons(t *testing.T) {
	ps := newPaymentStudio(t)
	r := ps.request(t, ps.teacher).Request
	sent := ps.send(t, r.Id)
	token := (*sent.Link)[strings.LastIndex(*sent.Link, "/")+1:]

	cancelled, err := ps.api.Client.CancelPaymentRequestWithResponse(ps.ctx, ps.team.Id, r.Id, ps.teacher.Auth)
	if err != nil || cancelled.JSON200 == nil || cancelled.JSON200.Status != gen.PaymentRequestStatusCancelled {
		t.Fatalf("cancel = %v %s", err, cancelled.Body)
	}
	billable, _ := ps.api.Client.ListBillableLessonsWithResponse(ps.ctx, ps.team.Id, &gen.ListBillableLessonsParams{StudentId: &ps.arjun.Id}, ps.teacher.Auth)
	if len(billable.JSON200.Items) != 2 || billable.JSON200.Items[0].Payee.DisplayName != "Mei Lin Tan" {
		t.Errorf("billable after withdrawing = %s", billable.Body)
	}
	page, _ := ps.api.Client.GetPublicPaymentRequestWithResponse(ps.ctx, token)
	if page.JSON200 == nil || page.JSON200.Status != gen.PaymentRequestStatusCancelled || page.JSON200.PaynowPayload != nil {
		t.Errorf("withdrawn page = %s", page.Body)
	}
	paid, _ := ps.api.Client.ConfirmPaidByPayerWithResponse(ps.ctx, token)
	wantProblem(t, "paying a withdrawn request", paid.StatusCode(), paid.Body, http.StatusConflict, "")

	unknown, _ := ps.api.Client.GetPublicPaymentRequestWithResponse(ps.ctx, "AAAAAAAAAAAAAAAAAAAAAA")
	wantProblem(t, "an unknown link", unknown.StatusCode(), unknown.Body, http.StatusNotFound, "")
}

func TestOverdueRequestsAreChasedWeeklyUntilConfirmed(t *testing.T) {
	ps := newPaymentStudio(t)
	r := ps.request(t, ps.teacher).Request
	ps.send(t, r.Id)
	ps.api.runJobs(0)
	start := len(ps.api.Mailer.Sent())

	if n, err := ps.api.services.Notify.QueuePaymentReminders(ps.ctx); err != nil || n != 0 {
		t.Fatalf("reminders before the due day = %d, %v", n, err)
	}
	ps.api.Clock.Set(time.Date(2026, 11, 28, 1, 0, 0, 0, time.UTC))
	if n, err := ps.api.services.Notify.QueuePaymentReminders(ps.ctx); err != nil || n != 1 {
		t.Fatalf("reminders when overdue = %d, %v; want 1", n, err)
	}
	if n, _ := ps.api.services.Notify.QueuePaymentReminders(ps.ctx); n != 0 {
		t.Errorf("queued %d more reminders the same day", n)
	}
	ps.api.runJobs(0)
	reminders := ps.api.Mailer.Sent()[start:]
	if len(reminders) != 1 || reminders[0].Category != notify.PaymentReminders || reminders[0].Unsubscribe == "" ||
		reminders[0].Subject != "Reminder: S$ 138.90 for Arjun's lessons was due Thursday 26 November" {
		t.Fatalf("reminders = %+v", reminders)
	}
	list, _ := ps.api.Client.ListPaymentRequestsWithResponse(ps.ctx, ps.team.Id, &gen.ListPaymentRequestsParams{}, ps.teacher.Auth)
	if !list.JSON200.Items[0].Overdue {
		t.Error("the request is not marked overdue")
	}

	ps.payerConfirms(t, ps.emailedToken(t, "parent.arjun@example.com"))
	ps.api.Clock.Set(time.Date(2026, 12, 6, 1, 0, 0, 0, time.UTC))
	if n, _ := ps.api.services.Notify.QueuePaymentReminders(ps.ctx); n != 0 {
		t.Errorf("chased a parent who says they paid: %d reminders", n)
	}
}

func TestAChangedPayNowNumberMustBeCheckedAgain(t *testing.T) {
	ps := newPaymentStudio(t)
	changed, err := ps.api.Client.SetPayeeAccountWithResponse(ps.ctx, ps.team.Id, ps.teacherID, gen.PayeeAccountInput{
		ProxyType: gen.ProxyTypeMobile, ProxyValue: "+6598765432", DisplayName: "Mei Lin Tan",
	}, ps.teacher.Auth)
	if err != nil || changed.JSON200 == nil || changed.JSON200.Verified {
		t.Fatalf("changed account = %v %s, want it unverified", err, changed.Body)
	}
	resp, _ := ps.api.Client.CreatePaymentRequestWithResponse(ps.ctx, ps.team.Id, &gen.CreatePaymentRequestParams{IdempotencyKey: ps.key()},
		gen.PaymentRequestInput{StudentId: ps.arjun.Id, PayeeId: ps.teacherID, DueOn: day(26), LessonIds: &[]openapi_types.UUID{ps.lessons[0].Id}}, ps.teacher.Auth)
	wantProblem(t, "billing to an unchecked number", resp.StatusCode(), resp.Body, http.StatusConflict, "")

	bad, _ := ps.api.Client.SetPayeeAccountWithResponse(ps.ctx, ps.team.Id, ps.teacherID, gen.PayeeAccountInput{
		ProxyType: gen.ProxyTypeMobile, ProxyValue: "6591234567", DisplayName: "Mei Lin Tan",
	}, ps.teacher.Auth)
	wantProblem(t, "a number without +65", bad.StatusCode(), bad.Body, http.StatusBadRequest, "")
}

func TestAutomaticSendingSkipsTheDraft(t *testing.T) {
	ps := newPaymentStudio(t)
	ps.setAccount(t, ps.teacherID, ps.teacher, true)
	created := ps.request(t, ps.teacher)
	if created.Request.Status != gen.PaymentRequestStatusOpen || created.Link == nil {
		t.Fatalf("auto-sent request = %s with link %v", created.Request.Status, created.Link)
	}
	if n := len(ps.api.queued("payment_request_email")); n != 1 {
		t.Errorf("queued %d request emails, want 1", n)
	}
}
