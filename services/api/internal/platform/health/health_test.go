package health

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestRunAllKeepsOrderAndReportsFailures(t *testing.T) {
	boom := errors.New("boom")
	results := RunAll(context.Background(), time.Second, []Check{
		{Name: "a", Run: func(context.Context) error { return nil }},
		{Name: "b", Run: func(context.Context) error { return boom }},
	})
	if len(results) != 2 || results[0].Name != "a" || results[1].Name != "b" {
		t.Fatalf("results = %+v, want a then b", results)
	}
	if results[0].Err != nil || !errors.Is(results[1].Err, boom) {
		t.Errorf("results = %+v, want a ok and b failing", results)
	}
	if Healthy(results) {
		t.Error("Healthy = true with a failing check")
	}
}

func TestRunAllTimesOutSlowChecks(t *testing.T) {
	results := RunAll(context.Background(), 10*time.Millisecond, []Check{
		{Name: "slow", Run: func(ctx context.Context) error {
			<-ctx.Done()
			return ctx.Err()
		}},
	})
	if !errors.Is(results[0].Err, context.DeadlineExceeded) {
		t.Errorf("err = %v, want deadline exceeded", results[0].Err)
	}
}

func TestHealthyWithNoChecks(t *testing.T) {
	if !Healthy(nil) {
		t.Error("Healthy(nil) = false, want true")
	}
}
