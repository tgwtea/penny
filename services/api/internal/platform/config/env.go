// Package config reads each binary's configuration from environment
// variables, the only configuration source (docs/architecture.md, "Backend").
//
// Loading collects every problem before failing, so a misconfigured pod
// reports all of its mistakes in one log line instead of one per restart.
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"net/netip"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// LookupFunc returns the value of an environment variable and whether it is
// set. os.LookupEnv satisfies it; tests pass a map-backed function.
type LookupFunc func(key string) (string, bool)

// reader accumulates parse errors while reading variables.
type reader struct {
	lookup LookupFunc
	errs   []error
}

func newReader(lookup LookupFunc) *reader {
	return &reader{lookup: lookup}
}

// value returns the trimmed value of key, or "" when it is unset or blank.
func (r *reader) value(key string) string {
	v, ok := r.lookup(key)
	if !ok {
		return ""
	}
	return strings.TrimSpace(v)
}

func (r *reader) fail(key, format string, args ...any) {
	r.errs = append(r.errs, fmt.Errorf("%s: %s", key, fmt.Sprintf(format, args...)))
}

func (r *reader) err() error {
	if len(r.errs) == 0 {
		return nil
	}
	return fmt.Errorf("invalid configuration: %w", errors.Join(r.errs...))
}

func (r *reader) string(key, fallback string) string {
	if v := r.value(key); v != "" {
		return v
	}
	return fallback
}

func (r *reader) required(key string) string {
	v := r.value(key)
	if v == "" {
		r.fail(key, "is required")
	}
	return v
}

func (r *reader) duration(key string, fallback time.Duration) time.Duration {
	v := r.value(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil || d < 0 {
		r.fail(key, "must be a non-negative duration such as 20s, got %q", v)
		return fallback
	}
	return d
}

func (r *reader) oneOf(key, fallback string, allowed ...string) string {
	v := strings.ToLower(r.string(key, fallback))
	for _, a := range allowed {
		if v == a {
			return v
		}
	}
	r.fail(key, "must be one of %s, got %q", strings.Join(allowed, ", "), v)
	return fallback
}

func (r *reader) logLevel(key string, fallback slog.Level) slog.Level {
	v := r.value(key)
	if v == "" {
		return fallback
	}
	var level slog.Level
	if err := level.UnmarshalText([]byte(v)); err != nil {
		r.fail(key, "must be debug, info, warn or error, got %q", v)
		return fallback
	}
	return level
}

// listenAddr reads a host:port listen address. The host may be empty.
func (r *reader) listenAddr(key, fallback string) string {
	v := r.string(key, fallback)
	i := strings.LastIndex(v, ":")
	if i < 0 {
		r.fail(key, "must be host:port or :port, got %q", v)
		return fallback
	}
	port, err := strconv.Atoi(v[i+1:])
	if err != nil || port < 0 || port > 65535 {
		r.fail(key, "has an invalid port in %q", v)
		return fallback
	}
	return v
}

// databaseURL reads a postgres:// URL. Credentials may be left out of the
// URL and supplied through PGUSER and PGPASSWORD instead, which is how the
// cluster passes them (deploy/base/api/deployment.yaml).
func (r *reader) databaseURL(key string) string {
	v := r.required(key)
	if v == "" {
		return ""
	}
	u, err := url.Parse(v)
	if err != nil || (u.Scheme != "postgres" && u.Scheme != "postgresql") {
		// Never echo the value: it may contain a password.
		r.fail(key, "must be a postgres:// URL")
		return ""
	}
	return v
}

// origins reads a comma-separated list of browser origins such as
// https://app.example.com. Paths, queries and wildcards are rejected.
func (r *reader) origins(key string) []string {
	v := r.value(key)
	if v == "" {
		return nil
	}
	var out []string
	for _, raw := range strings.Split(v, ",") {
		origin := strings.TrimRight(strings.TrimSpace(raw), "/")
		if origin == "" {
			continue
		}
		u, err := url.Parse(origin)
		if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" ||
			u.Path != "" || u.RawQuery != "" || strings.Contains(origin, "*") {
			r.fail(key, "entry %q must be an origin such as https://app.example.com", raw)
			continue
		}
		out = append(out, origin)
	}
	return out
}

// prefixes reads a comma-separated list of CIDRs. A bare address is its
// own /32 or /128.
func (r *reader) prefixes(key string) []netip.Prefix {
	v := r.value(key)
	if v == "" {
		return nil
	}
	var out []netip.Prefix
	for _, raw := range strings.Split(v, ",") {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}
		p, err := netip.ParsePrefix(raw)
		if err != nil {
			addr, addrErr := netip.ParseAddr(raw)
			if addrErr != nil {
				r.fail(key, "entry %q must be a CIDR such as 10.42.0.0/16", raw)
				continue
			}
			p = netip.PrefixFrom(addr, addr.BitLen())
		}
		out = append(out, p.Masked())
	}
	return out
}

// publicURL reads an absolute http(s) URL with no path beyond "/", query or
// fragment, and returns it without a trailing slash.
func (r *reader) publicURL(key, fallback string) string {
	v := strings.TrimRight(r.string(key, fallback), "/")
	u, err := url.Parse(v)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" ||
		u.Path != "" || u.RawQuery != "" || u.Fragment != "" {
		r.fail(key, "must be an address such as https://api.example.com, got %q", v)
		return fallback
	}
	return v
}

// secret reads a required secret of at least minLength characters. Its
// value is never echoed in errors.
func (r *reader) secret(key string, minLength int) string {
	v := r.value(key)
	switch {
	case v == "":
		r.fail(key, "is required")
	case len(v) < minLength:
		r.fail(key, "must be at least %d characters", minLength)
	}
	return v
}
