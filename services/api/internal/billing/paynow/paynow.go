// Package paynow encodes PayNow QR payloads: SGQR, which follows EMVCo's
// merchant-presented QR format (docs/architecture.md, "QR payload").
//
// Penny encodes them itself rather than depending on a small library, so
// both proxy types are supported (the Go library found handles UEN only)
// and the output is pinned by the golden cases in api/fixtures/paynow.
//
// Before launch, check the output against the MAS SGQR specification and
// scan it in at least three bank apps: how the bill reference shows in the
// payee's own records varies by bank.
package paynow

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
)

// ProxyType is how a PayNow account is addressed.
type ProxyType int

// The proxy types Penny supports, with their EMVCo values.
const (
	Mobile ProxyType = 0
	UEN    ProxyType = 2
)

// Payload is one QR code's content.
type Payload struct {
	ProxyType ProxyType
	// Proxy is "+6591234567" for Mobile or a UEN such as "201234567N".
	Proxy string
	// AmountCents is the amount in SGD cents; 0 leaves it out, for a test
	// code the payer fills in.
	AmountCents int64
	// Editable lets the payer change the amount. Requests fix it.
	Editable bool
	// Expiry is the last day the code can be paid, or zero for none.
	Expiry time.Time
	// MerchantName is the payee's name, shortened to 25 characters.
	MerchantName string
	// Reference is the bill reference, such as PNY-7K3Q9X.
	Reference string
}

const maxFieldLength = 25

var (
	mobileProxy = regexp.MustCompile(`^\+65[89][0-9]{7}$`)
	uenProxy    = regexp.MustCompile(`^[0-9A-Z]{9,10}$`)
	reference   = regexp.MustCompile(`^[0-9A-Z-]{1,25}$`)
)

// Encode returns the QR payload string for p.
func Encode(p Payload) (string, error) {
	switch p.ProxyType {
	case Mobile:
		if !mobileProxy.MatchString(p.Proxy) {
			return "", errors.New("a mobile proxy is +65 followed by 8 digits starting with 8 or 9")
		}
	case UEN:
		if !uenProxy.MatchString(p.Proxy) {
			return "", errors.New("a UEN is 9 or 10 letters and digits")
		}
	default:
		return "", fmt.Errorf("unknown proxy type %d", p.ProxyType)
	}
	if p.AmountCents < 0 {
		return "", errors.New("amount cannot be negative")
	}
	if p.Reference != "" && !reference.MatchString(p.Reference) {
		return "", errors.New("the reference is up to 25 capital letters, digits and hyphens")
	}
	name := merchantName(p.MerchantName)
	if name == "" {
		return "", errors.New("the payee needs a name")
	}

	editable := "0"
	if p.Editable || p.AmountCents == 0 {
		editable = "1"
	}
	account := field("00", "SG.PAYNOW") + field("01", fmt.Sprint(int(p.ProxyType))) + field("02", p.Proxy) + field("03", editable)
	if !p.Expiry.IsZero() {
		account += field("04", p.Expiry.Format("20060102"))
	}

	var b strings.Builder
	b.WriteString(field("00", "01"))
	b.WriteString(field("01", "12"))
	b.WriteString(field("26", account))
	b.WriteString(field("52", "0000"))
	b.WriteString(field("53", "702"))
	if p.AmountCents > 0 {
		b.WriteString(field("54", fmt.Sprintf("%d.%02d", p.AmountCents/100, p.AmountCents%100)))
	}
	b.WriteString(field("58", "SG"))
	b.WriteString(field("59", name))
	b.WriteString(field("60", "Singapore"))
	if p.Reference != "" {
		b.WriteString(field("62", field("01", p.Reference)))
	}
	b.WriteString("6304")
	return b.String() + fmt.Sprintf("%04X", CRC16(b.String())), nil
}

// field is one EMVCo TLV: two-digit ID, two-digit length, value.
func field(id, value string) string {
	return fmt.Sprintf("%s%02d%s", id, len(value), value)
}

// merchantName keeps a name printable ASCII, as SGQR asks, at most 25
// characters.
func merchantName(s string) string {
	var b strings.Builder
	for _, r := range strings.TrimSpace(s) {
		if r >= 0x20 && r < 0x7f {
			b.WriteRune(r)
		}
	}
	out := strings.TrimSpace(b.String())
	if len(out) > maxFieldLength {
		out = strings.TrimSpace(out[:maxFieldLength])
	}
	return out
}

// CRC16 is CRC-16/CCITT-FALSE (polynomial 0x1021, initial 0xFFFF), the
// checksum EMVCo QR codes end with.
func CRC16(s string) uint16 {
	crc := uint16(0xFFFF)
	for i := 0; i < len(s); i++ {
		crc ^= uint16(s[i]) << 8
		for range 8 {
			if crc&0x8000 != 0 {
				crc = crc<<1 ^ 0x1021
			} else {
				crc <<= 1
			}
		}
	}
	return crc
}
