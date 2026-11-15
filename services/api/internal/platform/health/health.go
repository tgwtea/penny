// Package health runs the dependency checks behind the readiness probe.
package health

import (
	"context"
	"sync"
	"time"
)

// Check is one dependency the server needs before it can take traffic.
type Check struct {
	Name string
	// Run returns nil when the dependency is usable. Its error text is
	// shown in /readyz, so it must never contain secrets.
	Run func(ctx context.Context) error
}

// Result is the outcome of one Check.
type Result struct {
	Name string
	Err  error
}

// RunAll runs every check concurrently, each bounded by timeout, and
// returns the results in the order the checks were given.
func RunAll(ctx context.Context, timeout time.Duration, checks []Check) []Result {
	results := make([]Result, len(checks))
	var wg sync.WaitGroup
	for i, c := range checks {
		wg.Go(func() {
			ctx, cancel := context.WithTimeout(ctx, timeout)
			defer cancel()
			results[i] = Result{Name: c.Name, Err: c.Run(ctx)}
		})
	}
	wg.Wait()
	return results
}

// Healthy reports whether every result passed.
func Healthy(results []Result) bool {
	for _, r := range results {
		if r.Err != nil {
			return false
		}
	}
	return true
}
