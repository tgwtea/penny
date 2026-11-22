package notify

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"mime"
	"mime/quotedprintable"
	"net/mail"
	"time"
)

// buildMIME renders m as a multipart/alternative message with a plain-text
// and an HTML part, for mailers that speak SMTP.
func buildMIME(from Address, m Message, now time.Time) ([]byte, string, error) {
	id, err := randomHex(16)
	if err != nil {
		return nil, "", err
	}
	domain := "penny.invalid"
	if addr, err := mail.ParseAddress(from.Email); err == nil {
		if at := bytes.LastIndexByte([]byte(addr.Address), '@'); at >= 0 {
			domain = addr.Address[at+1:]
		}
	}
	messageID := fmt.Sprintf("<%s@%s>", id, domain)
	boundary := "penny-" + id

	var b bytes.Buffer
	header := func(k, v string) { fmt.Fprintf(&b, "%s: %s\r\n", k, v) }
	header("From", formatAddress(from))
	header("To", formatAddress(m.To))
	header("Subject", mime.QEncoding.Encode("utf-8", m.Subject))
	header("Date", now.Format(time.RFC1123Z))
	header("Message-ID", messageID)
	header("MIME-Version", "1.0")
	if m.Unsubscribe != "" {
		header("List-Unsubscribe", "<"+m.Unsubscribe+">")
		header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
	}
	header("Content-Type", `multipart/alternative; boundary="`+boundary+`"`)
	b.WriteString("\r\n")

	for _, part := range []struct{ contentType, body string }{
		{"text/plain; charset=utf-8", m.Text},
		{"text/html; charset=utf-8", m.HTML},
	} {
		fmt.Fprintf(&b, "--%s\r\nContent-Type: %s\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\n", boundary, part.contentType)
		w := quotedprintable.NewWriter(&b)
		if _, err := w.Write([]byte(part.body)); err != nil {
			return nil, "", err
		}
		if err := w.Close(); err != nil {
			return nil, "", err
		}
		b.WriteString("\r\n")
	}
	fmt.Fprintf(&b, "--%s--\r\n", boundary)
	return b.Bytes(), messageID, nil
}

func formatAddress(a Address) string {
	return (&mail.Address{Name: a.Name, Address: a.Email}).String()
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
