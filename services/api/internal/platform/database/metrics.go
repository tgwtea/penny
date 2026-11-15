package database

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
)

// PoolCollector exports pgxpool statistics to Prometheus.
type PoolCollector struct {
	pool *pgxpool.Pool

	acquired     *prometheus.Desc
	idle         *prometheus.Desc
	total        *prometheus.Desc
	max          *prometheus.Desc
	acquireCount *prometheus.Desc
	emptyAcquire *prometheus.Desc
	acquireWait  *prometheus.Desc
}

// NewPoolCollector returns a collector for pool.
func NewPoolCollector(pool *pgxpool.Pool) *PoolCollector {
	desc := func(name, help string) *prometheus.Desc {
		return prometheus.NewDesc("penny_db_pool_"+name, help, nil, nil)
	}
	return &PoolCollector{
		pool:         pool,
		acquired:     desc("acquired_connections", "Connections currently in use."),
		idle:         desc("idle_connections", "Connections open and idle."),
		total:        desc("total_connections", "Connections open, in use or idle."),
		max:          desc("max_connections", "The pool's connection limit."),
		acquireCount: desc("acquires_total", "Connections acquired from the pool."),
		emptyAcquire: desc("empty_acquires_total", "Acquires that had to wait because no connection was idle."),
		acquireWait:  desc("acquire_wait_seconds_total", "Time spent waiting to acquire a connection."),
	}
}

// Describe implements prometheus.Collector.
func (c *PoolCollector) Describe(ch chan<- *prometheus.Desc) {
	for _, d := range []*prometheus.Desc{c.acquired, c.idle, c.total, c.max, c.acquireCount, c.emptyAcquire, c.acquireWait} {
		ch <- d
	}
}

// Collect implements prometheus.Collector.
func (c *PoolCollector) Collect(ch chan<- prometheus.Metric) {
	s := c.pool.Stat()
	ch <- prometheus.MustNewConstMetric(c.acquired, prometheus.GaugeValue, float64(s.AcquiredConns()))
	ch <- prometheus.MustNewConstMetric(c.idle, prometheus.GaugeValue, float64(s.IdleConns()))
	ch <- prometheus.MustNewConstMetric(c.total, prometheus.GaugeValue, float64(s.TotalConns()))
	ch <- prometheus.MustNewConstMetric(c.max, prometheus.GaugeValue, float64(s.MaxConns()))
	ch <- prometheus.MustNewConstMetric(c.acquireCount, prometheus.CounterValue, float64(s.AcquireCount()))
	ch <- prometheus.MustNewConstMetric(c.emptyAcquire, prometheus.CounterValue, float64(s.EmptyAcquireCount()))
	ch <- prometheus.MustNewConstMetric(c.acquireWait, prometheus.CounterValue, s.AcquireDuration().Seconds())
}
