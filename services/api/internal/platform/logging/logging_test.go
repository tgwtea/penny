package logging

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"testing"
)

func TestContextAttributesAreLogged(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&buf, slog.LevelInfo, "json")

	ctx := WithAttrs(context.Background(), slog.String("request_id", "r1"))
	ctx = WithAttrs(ctx, slog.String("workspace_id", "w1"))
	logger.With("component", "test").InfoContext(ctx, "hello")

	var record map[string]any
	if err := json.Unmarshal(buf.Bytes(), &record); err != nil {
		t.Fatalf("log line is not JSON: %v\n%s", err, buf.String())
	}
	for key, want := range map[string]string{
		"msg":          "hello",
		"request_id":   "r1",
		"workspace_id": "w1",
		"component":    "test",
	} {
		if got := record[key]; got != want {
			t.Errorf("%s = %v, want %q", key, got, want)
		}
	}
}

func TestLevelFiltersRecords(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&buf, slog.LevelWarn, "text")
	logger.Info("hidden")
	if buf.Len() != 0 {
		t.Errorf("info record written at warn level: %s", buf.String())
	}
	logger.Warn("shown")
	if buf.Len() == 0 {
		t.Error("warn record not written at warn level")
	}
}
