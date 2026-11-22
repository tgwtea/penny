package notify

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
)

// unsubscribeClaim is what an unsubscribe link says: stop one category of
// email for one contact of one team.
type unsubscribeClaim struct {
	WorkspaceID uuid.UUID `json:"w"`
	ContactID   uuid.UUID `json:"c"`
	Category    Category  `json:"k"`
}

// signUnsubscribe makes a link token: the claim and an HMAC-SHA256 of it.
// Links never expire; an old email's link should still work.
func signUnsubscribe(secret []byte, c unsubscribeClaim) string {
	payload, _ := json.Marshal(c)
	p := base64.RawURLEncoding.EncodeToString(payload)
	return p + "." + base64.RawURLEncoding.EncodeToString(mac(secret, p))
}

// verifyUnsubscribe reads a token, or reports it forged or garbled.
func verifyUnsubscribe(secret []byte, token string) (unsubscribeClaim, bool) {
	p, sig, ok := strings.Cut(token, ".")
	if !ok {
		return unsubscribeClaim{}, false
	}
	got, err := base64.RawURLEncoding.DecodeString(sig)
	if err != nil || !hmac.Equal(got, mac(secret, p)) {
		return unsubscribeClaim{}, false
	}
	payload, err := base64.RawURLEncoding.DecodeString(p)
	if err != nil {
		return unsubscribeClaim{}, false
	}
	var c unsubscribeClaim
	if err := json.Unmarshal(payload, &c); err != nil || !c.Category.Stoppable() || c.ContactID == uuid.Nil {
		return unsubscribeClaim{}, false
	}
	return c, true
}

func mac(secret []byte, payload string) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte("penny-unsubscribe:" + payload))
	return h.Sum(nil)
}

// maskEmail shows enough of an address to recognise it: p***@example.com.
func maskEmail(email string) string {
	local, domain, ok := strings.Cut(email, "@")
	if !ok || local == "" {
		return "***"
	}
	return local[:1] + "***@" + domain
}
