// Package ratelimit keeps a token bucket per key, such as a client's IP
// address, in memory (docs/architecture.md, "Security and privacy": rate-
// limit the public payment page and every unauthenticated endpoint).
//
// Each replica limits on its own, so with n replicas a client gets up to n
// times the rate. That is enough to stop one client hammering a public
// page; an edge limit at the ingress can tighten it further.
package ratelimit

import (
	"math"
	"sync"
	"time"

	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// Rule is how fast one key may go: Burst requests at once, refilled at
// PerMinute.
type Rule struct {
	PerMinute float64
	Burst     float64
}

// Limiter holds a bucket per key. Buckets idle long enough to be full
// again are forgotten, so memory stays bounded by recent clients.
type Limiter struct {
	rule  Rule
	clock clock.Clock

	mu        sync.Mutex
	buckets   map[string]*bucket
	lastSweep time.Time
}

type bucket struct {
	tokens float64
	at     time.Time
}

// New returns a limiter for rule.
func New(rule Rule, c clock.Clock) *Limiter {
	if c == nil {
		c = clock.System{}
	}
	return &Limiter{rule: rule, clock: c, buckets: map[string]*bucket{}, lastSweep: c.Now()}
}

// Allow takes a token for key. When none is left it returns false and how
// long until one is.
func (l *Limiter) Allow(key string) (bool, time.Duration) {
	now := l.clock.Now()
	perSecond := l.rule.PerMinute / 60
	l.mu.Lock()
	defer l.mu.Unlock()
	l.sweep(now)

	b, ok := l.buckets[key]
	if !ok {
		b = &bucket{tokens: l.rule.Burst, at: now}
		l.buckets[key] = b
	}
	b.tokens = math.Min(l.rule.Burst, b.tokens+now.Sub(b.at).Seconds()*perSecond)
	b.at = now
	if b.tokens >= 1 {
		b.tokens--
		return true, 0
	}
	wait := time.Duration((1 - b.tokens) / perSecond * float64(time.Second))
	return false, wait
}

// sweep forgets full buckets, at most once a minute.
func (l *Limiter) sweep(now time.Time) {
	if now.Sub(l.lastSweep) < time.Minute {
		return
	}
	l.lastSweep = now
	refill := time.Duration(l.rule.Burst / (l.rule.PerMinute / 60) * float64(time.Second))
	for k, b := range l.buckets {
		if now.Sub(b.at) >= refill {
			delete(l.buckets, k)
		}
	}
}

// Len is how many keys have a bucket, for tests.
func (l *Limiter) Len() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.buckets)
}
