package ratelimit

import (
	"testing"
	"time"

	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

func TestABurstThenTheSteadyRate(t *testing.T) {
	c := clock.NewFixed(time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC))
	l := New(Rule{PerMinute: 6, Burst: 3}, c)
	for i := range 3 {
		if ok, _ := l.Allow("203.0.113.7"); !ok {
			t.Fatalf("request %d of the burst refused", i+1)
		}
	}
	ok, wait := l.Allow("203.0.113.7")
	if ok || wait != 10*time.Second {
		t.Fatalf("fourth = %v, wait %v; want refused for 10s", ok, wait)
	}
	if ok, _ := l.Allow("198.51.100.2"); !ok {
		t.Error("another client was refused")
	}
	c.Set(c.Now().Add(10 * time.Second))
	if ok, _ := l.Allow("203.0.113.7"); !ok {
		t.Error("refused after a token refilled")
	}
}

func TestIdleClientsAreForgotten(t *testing.T) {
	c := clock.NewFixed(time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC))
	l := New(Rule{PerMinute: 60, Burst: 10}, c)
	l.Allow("a")
	l.Allow("b")
	c.Set(c.Now().Add(2 * time.Minute))
	l.Allow("c")
	if n := l.Len(); n != 1 {
		t.Errorf("%d buckets after the others idled, want 1", n)
	}
}
