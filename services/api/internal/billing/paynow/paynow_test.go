package paynow

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

var update = flag.Bool("update", false, "rewrite the payloads in api/fixtures/paynow")

const fixtureDir = "../../../../../api/fixtures/paynow"

func TestCRC16MatchesTheStandardCheckValue(t *testing.T) {
	// CRC-16/CCITT-FALSE's published check value for "123456789".
	if got := CRC16("123456789"); got != 0x29B1 {
		t.Errorf("CRC16(123456789) = %04X, want 29B1", got)
	}
}

type fixture struct {
	Name  string `json:"name"`
	Input struct {
		ProxyType    string `json:"proxyType"`
		Proxy        string `json:"proxy"`
		AmountCents  int64  `json:"amountCents"`
		Editable     bool   `json:"editable"`
		Expiry       string `json:"expiry"`
		MerchantName string `json:"merchantName"`
		Reference    string `json:"reference"`
	} `json:"input"`
	Payload string `json:"payload"`
}

func (f fixture) payload(t *testing.T) Payload {
	t.Helper()
	p := Payload{
		Proxy: f.Input.Proxy, AmountCents: f.Input.AmountCents, Editable: f.Input.Editable,
		MerchantName: f.Input.MerchantName, Reference: f.Input.Reference,
	}
	switch f.Input.ProxyType {
	case "mobile":
		p.ProxyType = Mobile
	case "uen":
		p.ProxyType = UEN
	default:
		t.Fatalf("unknown proxyType %q", f.Input.ProxyType)
	}
	if f.Input.Expiry != "" {
		d, err := time.Parse("2006-01-02", f.Input.Expiry)
		if err != nil {
			t.Fatal(err)
		}
		p.Expiry = d
	}
	return p
}

func TestEncodeMatchesTheSharedFixtures(t *testing.T) {
	files, err := filepath.Glob(filepath.Join(fixtureDir, "*.json"))
	if err != nil || len(files) == 0 {
		t.Fatalf("no fixtures in %s", fixtureDir)
	}
	for _, file := range files {
		t.Run(filepath.Base(file), func(t *testing.T) {
			raw, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			var f fixture
			if err := json.Unmarshal(raw, &f); err != nil {
				t.Fatal(err)
			}
			got, err := Encode(f.payload(t))
			if err != nil {
				t.Fatal(err)
			}
			if *update {
				f.Payload = got
				out, _ := json.MarshalIndent(f, "", "  ")
				if err := os.WriteFile(file, append(out, '\n'), 0o600); err != nil {
					t.Fatal(err)
				}
				return
			}
			if got != f.Payload {
				t.Errorf("%s\n got %s\nwant %s", f.Name, got, f.Payload)
			}
			checkStructure(t, got)
		})
	}
}

// checkStructure parses the payload's top-level fields and its CRC, so a
// fixture cannot freeze a malformed payload.
func checkStructure(t *testing.T, payload string) {
	t.Helper()
	ids := []string{}
	for i := 0; i < len(payload); {
		if i+4 > len(payload) {
			t.Fatalf("truncated field at %d", i)
		}
		id, n := payload[i:i+2], payload[i+2:i+4]
		length, err := strconv.Atoi(n)
		if err != nil || i+4+length > len(payload) {
			t.Fatalf("bad length %q at %d", n, i)
		}
		ids = append(ids, id)
		if id == "63" {
			want := payload[:i+4]
			if got := payload[i+4 : i+4+length]; got != fmtCRC(CRC16(want)) {
				t.Errorf("CRC = %s, want %s", got, fmtCRC(CRC16(want)))
			}
		}
		i += 4 + length
	}
	if ids[0] != "00" || ids[len(ids)-1] != "63" {
		t.Errorf("fields %v must start with 00 and end with 63", ids)
	}
}

func fmtCRC(c uint16) string { return strings.ToUpper(strconv.FormatUint(uint64(c)|0x10000, 16)[1:]) }

func TestEncodeRefusesBadInput(t *testing.T) {
	bad := []Payload{
		{ProxyType: Mobile, Proxy: "91234567", MerchantName: "Mei"},
		{ProxyType: Mobile, Proxy: "+6561234567", MerchantName: "Mei"},
		{ProxyType: UEN, Proxy: "abc", MerchantName: "Studio"},
		{ProxyType: Mobile, Proxy: "+6591234567", MerchantName: ""},
		{ProxyType: Mobile, Proxy: "+6591234567", MerchantName: "Mei", Reference: "lower-case"},
		{ProxyType: Mobile, Proxy: "+6591234567", MerchantName: "Mei", AmountCents: -1},
	}
	for _, p := range bad {
		if _, err := Encode(p); err == nil {
			t.Errorf("Encode(%+v) succeeded, want an error", p)
		}
	}
}

func TestMerchantNameIsShortAndPrintable(t *testing.T) {
	if got := merchantName("Koh Guitar Studio and Music School"); got != "Koh Guitar Studio and Mus" {
		t.Errorf("merchantName = %q", got)
	}
	if got := merchantName("Tan 陈美琳 Mei Lin"); got != "Tan  Mei Lin" {
		t.Errorf("merchantName = %q", got)
	}
}
