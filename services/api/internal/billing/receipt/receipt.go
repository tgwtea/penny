// Package receipt renders a receipt as a PDF, the same way every time from
// the same record, so its SHA-256 shows a copy is unaltered
// (docs/architecture.md, "Receipts and traceability").
package receipt

import (
	"bytes"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/go-pdf/fpdf"
)

// IBM Plex Sans, the brand's typeface (ADR 020), under the SIL Open Font
// Licence (fonts/OFL.txt).
var (
	//go:embed fonts/IBMPlexSans-Regular.ttf
	regularFont []byte
	//go:embed fonts/IBMPlexSans-SemiBold.ttf
	semiBoldFont []byte
)

// Document is everything a receipt shows.
type Document struct {
	Number      string // "R-0042"
	IssuedAt    time.Time
	TeamName    string
	PayeeName   string
	StudentName string
	Reference   string // the request's PNY- reference
	Lines       []Line
	AmountCents int64
	Currency    string
	PaidOn      time.Time
	Method      string // "PayNow"
	// Replaces is the number of the receipt this one corrects, if any.
	Replaces string
	// CoTaught adds the note that the lead tutor billed a shared lesson.
	CoTaught bool
	Location *time.Location
}

// Line is one thing the receipt covers.
type Line struct {
	Description string
	AmountCents int64
}

// Render returns the PDF and the hex SHA-256 of its bytes.
func Render(d Document) ([]byte, string, error) {
	loc := d.Location
	if loc == nil {
		loc = time.UTC
	}
	pdf := fpdf.New("P", "mm", "A4", "")
	// Fixed metadata: the same record renders the same bytes.
	pdf.SetCreationDate(d.IssuedAt.UTC())
	pdf.SetModificationDate(d.IssuedAt.UTC())
	pdf.SetCatalogSort(true)
	pdf.SetCompression(true)
	pdf.SetProducer("Penny", false)
	pdf.SetTitle("Receipt "+d.Number, true)
	pdf.SetAuthor(d.TeamName, true)
	pdf.AddUTF8FontFromBytes("Plex", "", regularFont)
	pdf.AddUTF8FontFromBytes("Plex", "B", semiBoldFont)
	pdf.SetMargins(20, 20, 20)
	pdf.SetAutoPageBreak(true, 20)
	pdf.AddPage()

	ink := func() { pdf.SetTextColor(0x1C, 0x2B, 0x3A) }
	muted := func() { pdf.SetTextColor(0x5B, 0x6B, 0x7B) }
	const width = 170.0

	ink()
	pdf.SetFont("Plex", "B", 20)
	pdf.CellFormat(width, 10, "Receipt "+d.Number, "", 1, "L", false, 0, "")
	pdf.SetFont("Plex", "", 11)
	muted()
	pdf.CellFormat(width, 6, d.TeamName, "", 1, "L", false, 0, "")
	pdf.Ln(6)

	row := func(label, value string) {
		muted()
		pdf.SetFont("Plex", "", 10)
		pdf.CellFormat(45, 6, label, "", 0, "L", false, 0, "")
		ink()
		pdf.SetFont("Plex", "", 11)
		pdf.MultiCell(width-45, 6, value, "", "L", false)
	}
	row("Issued", d.IssuedAt.In(loc).Format("2 January 2006, 15:04"))
	row("Received by", d.PayeeName)
	row("For", d.StudentName)
	row("Payment reference", d.Reference)
	row("Paid on", d.PaidOn.Format("2 January 2006"))
	row("Paid by", d.Method)
	if d.Replaces != "" {
		row("Replaces", "Receipt "+d.Replaces+", which was voided")
	}
	pdf.Ln(6)

	pdf.SetDrawColor(0xD9, 0xDF, 0xE5)
	pdf.Line(20, pdf.GetY(), 20+width, pdf.GetY())
	pdf.Ln(3)
	for _, l := range d.Lines {
		ink()
		pdf.SetFont("Plex", "", 11)
		y := pdf.GetY()
		pdf.MultiCell(width-40, 6, l.Description, "", "L", false)
		end := pdf.GetY()
		pdf.SetXY(20+width-40, y)
		pdf.CellFormat(40, 6, Money(l.AmountCents, d.Currency), "", 0, "R", false, 0, "")
		pdf.SetY(end)
	}
	pdf.Ln(2)
	pdf.Line(20, pdf.GetY(), 20+width, pdf.GetY())
	pdf.Ln(3)
	pdf.SetFont("Plex", "B", 12)
	pdf.CellFormat(width-40, 7, "Total received", "", 0, "L", false, 0, "")
	pdf.CellFormat(40, 7, Money(d.AmountCents, d.Currency), "", 1, "R", false, 0, "")
	pdf.Ln(8)

	muted()
	pdf.SetFont("Plex", "", 9)
	note := "Both the payee and the payer confirmed this payment. Penny records payments; it does not move money."
	if d.CoTaught {
		note += " A lesson here was taught by several tutors: the lead tutor billed it, and the tutors arrange the split outside Penny."
	}
	pdf.MultiCell(width, 5, note, "", "L", false)

	var b bytes.Buffer
	if err := pdf.Output(&b); err != nil {
		return nil, "", fmt.Errorf("render receipt: %w", err)
	}
	sum := sha256.Sum256(b.Bytes())
	return b.Bytes(), hex.EncodeToString(sum[:]), nil
}

// Money formats cents as "S$ 240.00" (brand book, "Voice and copy").
func Money(cents int64, currency string) string {
	symbol := currency + " "
	if currency == "SGD" {
		symbol = "S$ "
	}
	sign := ""
	if cents < 0 {
		sign, cents = "-", -cents
	}
	whole := fmt.Sprint(cents / 100)
	var grouped strings.Builder
	for i, r := range whole {
		if i > 0 && (len(whole)-i)%3 == 0 {
			grouped.WriteByte(',')
		}
		grouped.WriteRune(r)
	}
	return fmt.Sprintf("%s%s%s.%02d", sign, symbol, grouped.String(), cents%100)
}

// Number formats a receipt number: R-0042.
func Number(n int) string { return fmt.Sprintf("R-%04d", n) }
