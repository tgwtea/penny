package httpserver

import (
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"testing"
	"time"
)

func TestRunFinishesInFlightRequestsOnShutdown(t *testing.T) {
	addr := freeAddr(t)
	started := make(chan struct{})
	release := make(chan struct{})
	srv := New(addr, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		<-release
		_, _ = io.WriteString(w, "done")
	}))

	ctx, cancel := context.WithCancel(context.Background())
	runErr := make(chan error, 1)
	go func() {
		runErr <- Run(ctx, slog.New(slog.DiscardHandler), 5*time.Second, srv)
	}()

	body := make(chan string, 1)
	go func() {
		resp, err := getWithRetry("http://" + addr + "/")
		if err != nil {
			body <- "error: " + err.Error()
			return
		}
		defer resp.Body.Close()
		b, _ := io.ReadAll(resp.Body)
		body <- string(b)
	}()

	<-started
	cancel() // like SIGTERM while a request is in flight
	close(release)

	if got := <-body; got != "done" {
		t.Errorf("in-flight request got %q, want done", got)
	}
	if err := <-runErr; err != nil {
		t.Errorf("Run returned %v, want nil after a clean shutdown", err)
	}
}

func TestRunFailsWhenTheAddressIsTaken(t *testing.T) {
	var lc net.ListenConfig
	ln, err := lc.Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	err = Run(context.Background(), slog.New(slog.DiscardHandler), time.Second, New(ln.Addr().String(), http.NotFoundHandler()))
	if err == nil {
		t.Fatal("Run succeeded on a taken address, want error")
	}
}

func freeAddr(t *testing.T) string {
	t.Helper()
	var lc net.ListenConfig
	ln, err := lc.Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	if err := ln.Close(); err != nil {
		t.Fatal(err)
	}
	return addr
}

func getWithRetry(url string) (*http.Response, error) {
	var lastErr error
	for range 50 {
		resp, err := http.Get(url) //nolint:noctx // test helper
		if err == nil {
			return resp, nil
		}
		lastErr = err
		time.Sleep(20 * time.Millisecond)
	}
	return nil, lastErr
}
