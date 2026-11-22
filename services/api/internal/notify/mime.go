package notify

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"mime"
	"mime/quotedprintable"
	"net/mail"
	"time"
)

// buildMIME renders m for mailers that speak SMTP: a multipart/alternative
// message with a plain-text and an HTML part, wrapped in multipart/mixed
// with the attachments when there are any.
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
	if len(m.Attachments) == 0 {
		header("Content-Type", `multipart/alternative; boundary="`+boundary+`"`)
		b.WriteString("\r\n")
		if err := writeAlternative(&b, boundary, m); err != nil {
			return nil, "", err
		}
		return b.Bytes(), messageID, nil
	}

	mixed := "penny-mixed-" + id
	header("Content-Type", `multipart/mixed; boundary="`+mixed+`"`)
	b.WriteString("\r\n")
	fmt.Fprintf(&b, "--%s\r\nContent-Type: multipart/alternative; boundary=\"%s\"\r\n\r\n", mixed, boundary)
	if err := writeAlternative(&b, boundary, m); err != nil {
		return nil, "", err
	}
	for _, a := range m.Attachments {
		name := mime.QEncoding.Encode("utf-8", a.Filename)
		fmt.Fprintf(&b, "\r\n--%s\r\nContent-Type: %s; name=\"%s\"\r\nContent-Disposition: attachment; filename=\"%s\"\r\nContent-Transfer-Encoding: base64\r\n\r\n",
			mixed, a.ContentType, name, name)
		writeBase64(&b, a.Content)
	}
	fmt.Fprintf(&b, "\r\n--%s--\r\n", mixed)
	return b.Bytes(), messageID, nil
}

// writeAlternative writes the text and HTML parts and the closing boundary.
func writeAlternative(b *bytes.Buffer, boundary string, m Message) error {
	for _, part := range []struct{ contentType, body string }{
		{"text/plain; charset=utf-8", m.Text},
		{"text/html; charset=utf-8", m.HTML},
	} {
		fmt.Fprintf(b, "--%s\r\nContent-Type: %s\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\n", boundary, part.contentType)
		w := quotedprintable.NewWriter(b)
		if _, err := w.Write([]byte(part.body)); err != nil {
			return err
		}
		if err := w.Close(); err != nil {
			return err
		}
		b.WriteString("\r\n")
	}
	fmt.Fprintf(b, "--%s--\r\n", boundary)
	return nil
}

// writeBase64 writes content in base64 lines of 76 characters (RFC 2045).
func writeBase64(b *bytes.Buffer, content []byte) {
	encoded := base64.StdEncoding.EncodeToString(content)
	for len(encoded) > 76 {
		b.WriteString(encoded[:76])
		b.WriteString("\r\n")
		encoded = encoded[76:]
	}
	b.WriteString(encoded)
	b.WriteString("\r\n")
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
