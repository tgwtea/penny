package paging

import (
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/apperr"
)

func TestCursorRoundTrip(t *testing.T) {
	c := Cursor{Key: "arjun nair", ID: uuid.New()}
	s := Encode(c)
	got, err := Decode(&s)
	if err != nil || got == nil || *got != c {
		t.Fatalf("Decode(Encode(%v)) = %v, %v", c, got, err)
	}
}

func TestDecodeRefusesNonsense(t *testing.T) {
	for _, bad := range []string{"%%%", "e30", Encode(Cursor{Key: "x"})} {
		if _, err := Decode(&bad); !errors.Is(err, apperr.ErrValidation) {
			t.Errorf("Decode(%q) = %v, want a validation error", bad, err)
		}
	}
	if c, err := Decode(nil); c != nil || err != nil {
		t.Errorf("Decode(nil) = %v, %v; want the first page", c, err)
	}
}

func TestLimitAndPage(t *testing.T) {
	big, zero := int32(9999), int32(0)
	if Limit(nil, 100, 500) != 100 || Limit(&big, 100, 500) != 500 || Limit(&zero, 100, 500) != 100 {
		t.Error("Limit does not apply its default and maximum")
	}
	rows, more := Page([]int{1, 2, 3}, 2)
	if len(rows) != 2 || !more {
		t.Errorf("Page = %v, %v; want two rows and more", rows, more)
	}
	if _, more := Page([]int{1, 2}, 2); more {
		t.Error("Page reports more on the last page")
	}
}
