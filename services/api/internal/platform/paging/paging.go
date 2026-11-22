// Package paging encodes the cursors of cursor-paginated lists
// (docs/architecture.md, "API contract": `?cursor=&limit=`).
//
// A list ordered by (key, id) hands out the last row's key and id as an
// opaque cursor; the next page starts after it. Cursors are not secret and
// not signed: a forged one only changes where a page starts, and every
// query is still scoped to what the caller may see.
package paging

import (
	"encoding/base64"
	"encoding/json"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

// Cursor is a position in a list ordered by (Key, ID).
type Cursor struct {
	Key string    `json:"k"`
	ID  uuid.UUID `json:"i"`
}

// Encode returns c as an opaque string.
func Encode(c Cursor) string {
	b, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(b)
}

// Decode reads a cursor from a request. An empty string is the first page
// (nil); anything unreadable is a validation error.
func Decode(s *string) (*Cursor, error) {
	if s == nil || *s == "" {
		return nil, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(*s)
	var c Cursor
	if err == nil {
		err = json.Unmarshal(b, &c)
	}
	if err != nil || c.ID == uuid.Nil {
		return nil, apperr.New(apperr.ErrValidation, "The cursor is not valid. Start from the first page.")
	}
	return &c, nil
}

// Limit is a page size: requested, or def, at most max.
func Limit(requested *int32, def, maximum int) int {
	if requested == nil || *requested < 1 {
		return def
	}
	return min(int(*requested), maximum)
}

// Page trims rows fetched with one extra (limit+1) to limit and says
// whether more follow.
func Page[T any](rows []T, limit int) ([]T, bool) {
	if len(rows) > limit {
		return rows[:limit], true
	}
	return rows, false
}
