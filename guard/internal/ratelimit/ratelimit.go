// Package ratelimit provides per-client token-bucket rate limiting using
// golang.org/x/time/rate. Each unique client (identified by the name injected
// by the auth middleware) gets its own limiter.
package ratelimit

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"

	"github.com/healthbee/guard/internal/auth"
)

// Limiter holds per-client rate limiters.
type Limiter struct {
	mu      sync.Mutex
	clients map[string]*entry
	rps     rate.Limit
	burst   int
}

type entry struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// NewLimiter creates a Limiter with the given sustained rate (req/s) and burst.
func NewLimiter(rps float64, burst int) *Limiter {
	l := &Limiter{
		clients: make(map[string]*entry),
		rps:     rate.Limit(rps),
		burst:   burst,
	}
	// Evict stale client entries every 5 minutes.
	go l.cleanup(5 * time.Minute)
	return l
}

// Middleware wraps next with per-client rate limiting.
// /health is excluded from limiting.
func (l *Limiter) Middleware(next http.Handler, log *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}

		client := auth.ClientFromContext(r.Context())
		limiter := l.get(client)

		if !limiter.Allow() {
			log.Warn("rate limit exceeded", "client", client, "path", r.URL.Path)
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", "1")
			w.WriteHeader(http.StatusTooManyRequests)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"error": "rate limit exceeded, please slow down",
			})
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (l *Limiter) get(client string) *rate.Limiter {
	l.mu.Lock()
	defer l.mu.Unlock()

	e, ok := l.clients[client]
	if !ok {
		e = &entry{limiter: rate.NewLimiter(l.rps, l.burst)}
		l.clients[client] = e
	}
	e.lastSeen = time.Now()
	return e.limiter
}

func (l *Limiter) cleanup(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for range ticker.C {
		l.mu.Lock()
		for k, e := range l.clients {
			if time.Since(e.lastSeen) > interval {
				delete(l.clients, k)
			}
		}
		l.mu.Unlock()
	}
}
