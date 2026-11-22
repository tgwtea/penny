package httpapi

import (
	"context"
	"fmt"
	"math"
	"net"
	"net/http"
	"net/netip"
	"strings"

	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
	"github.com/tgwtea/penny/services/api/internal/platform/ratelimit"
)

// RateLimits limit the operations anyone can call without signing in: the
// payment page, unsubscribe links and calendar feeds. Health probes and
// version are exempt.
type RateLimits struct {
	// Reads are GETs of a public page or feed.
	Reads *ratelimit.Limiter
	// Writes are the public POSTs: "I've paid" and unsubscribe.
	Writes *ratelimit.Limiter
	// TrustedProxies are the ingress addresses whose X-Forwarded-For is
	// believed. Without any, the peer address is the client.
	TrustedProxies []netip.Prefix
}

// DefaultRateLimits are generous for a person and tight for a script.
func DefaultRateLimits(trusted []netip.Prefix) RateLimits {
	return RateLimits{
		Reads:          ratelimit.New(ratelimit.Rule{PerMinute: 60, Burst: 30}, nil),
		Writes:         ratelimit.New(ratelimit.Rule{PerMinute: 10, Burst: 5}, nil),
		TrustedProxies: trusted,
	}
}

// unlimited are the probes, by the operation IDs the generated server uses.
var unlimited = map[string]bool{"GetLivez": true, "GetReadyz": true, "GetVersion": true}

// rateLimit is a strict-server middleware that limits every public
// operation per client address. Which operations are public is read from
// the contract, as for authenticate.
func rateLimit(limits RateLimits, secured map[string]bool, problems problemWriter) gen.StrictMiddlewareFunc {
	return func(next gen.StrictHandlerFunc, operationID string) gen.StrictHandlerFunc {
		if secured[operationID] || unlimited[operationID] || limits.Reads == nil {
			return next
		}
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			limiter := limits.Reads
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				limiter = limits.Writes
			}
			ok, wait := limiter.Allow(clientIP(r, limits.TrustedProxies))
			if !ok {
				w.Header().Set("Retry-After", fmt.Sprint(int(math.Ceil(wait.Seconds()))))
				problems.write(w, r, problemRateLimited, "Too many requests from your network. Wait a moment and try again.")
				return nil, nil
			}
			return next(ctx, w, r, request)
		}
	}
}

// clientIP is the address a request came from: the peer, or, when the
// peer is a trusted proxy, the nearest address in X-Forwarded-For that is
// not one. Entries a client wrote itself sit further left and are never
// reached.
func clientIP(r *http.Request, trusted []netip.Prefix) string {
	peer := remoteAddr(r)
	if !isTrusted(peer, trusted) {
		return peer.String()
	}
	hops := strings.Split(strings.Join(r.Header.Values("X-Forwarded-For"), ","), ",")
	for i := len(hops) - 1; i >= 0; i-- {
		addr, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			break
		}
		addr = addr.Unmap()
		if !isTrusted(addr, trusted) {
			return addr.String()
		}
	}
	return peer.String()
}

func remoteAddr(r *http.Request) netip.Addr {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	addr, err := netip.ParseAddr(host)
	if err != nil {
		return netip.IPv4Unspecified()
	}
	return addr.Unmap()
}

func isTrusted(addr netip.Addr, trusted []netip.Prefix) bool {
	for _, p := range trusted {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}
