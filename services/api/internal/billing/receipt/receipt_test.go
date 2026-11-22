package receipt

import (
	"bytes"
	"testing"
	"time"
)

func document() Document {
	sgt := time.FixedZone("SGT", 8*3600)
	return Document{
		Number: "R-0042", IssuedAt: time.Date(2026, 11, 20, 9, 30, 0, 0, time.UTC), TeamName: "Koh Guitar Studio",
		PayeeName: "Mei Lin Tan", StudentName: "Arjun Nair 陈", Reference: "PNY-7K3Q9X",
		Lines:       []Line{{Description: "Guitar lesson, Thu 19 Nov", AmountCents: 6000}, {Description: "Exam book", AmountCents: 1850}},
		AmountCents: 7850, Currency: "SGD", PaidOn: time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC), Method: "PayNow",
		CoTaught: true, Location: sgt,
	}
}

func TestRenderingIsDeterministic(t *testing.T) {
	a, hashA, err := Render(document())
	if err != nil {
		t.Fatal(err)
	}
	b, hashB, err := Render(document())
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(a, b) || hashA != hashB {
		t.Fatal("the same record rendered two different PDFs; the content hash would not prove anything")
	}
	if !bytes.HasPrefix(a, []byte("%PDF-")) || len(hashA) != 64 {
		t.Errorf("not a PDF, or a bad hash %q", hashA)
	}
	changed := document()
	changed.AmountCents++
	_, hashC, _ := Render(changed)
	if hashC == hashA {
		t.Error("a changed amount kept the same hash")
	}
}

func TestMoney(t *testing.T) {
	for cents, want := range map[int64]string{24000: "S$ 240.00", 5: "S$ 0.05", 123456789: "S$ 1,234,567.89"} {
		if got := Money(cents, "SGD"); got != want {
			t.Errorf("Money(%d) = %q, want %q", cents, got, want)
		}
	}
	if Number(42) != "R-0042" {
		t.Errorf("Number(42) = %q", Number(42))
	}
}
