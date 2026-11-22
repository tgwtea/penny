package billing

import (
	"crypto/rand"
	"fmt"
)

// crockford is Crockford's base32 alphabet: no I, L, O or U, so a
// reference read aloud or typed into a banking app is hard to get wrong.
const crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

// newReference returns a payment reference such as PNY-7K3Q9X: 30 random
// bits, unique within a team by a database constraint (callers retry on
// the rare collision).
func newReference() (string, error) {
	b := make([]byte, 6)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("make reference: %w", err)
	}
	out := []byte("PNY-")
	for _, v := range b {
		out = append(out, crockford[int(v)%len(crockford)])
	}
	return string(out), nil
}
