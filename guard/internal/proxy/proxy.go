// Package proxy implements reverse proxies that forward requests to the
// upstream Node.js backend and the Python agent server. It handles both
// regular JSON responses and Server-Sent Event (SSE) streams transparently.
package proxy

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/healthbee/guard/internal/auth"
)

// NewRouter returns a handler that routes /agents/* to the Python agent server
// and everything else to the Node.js backend.
func NewRouter(upstreamURL, agentURL string, log *slog.Logger) http.Handler {
	backend := New(upstreamURL, log)
	agents := New(agentURL, log)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/agents") {
			agents.ServeHTTP(w, r)
		} else {
			backend.ServeHTTP(w, r)
		}
	})
}

// New creates a reverse-proxy handler that forwards every request to upstreamURL.
func New(upstreamURL string, log *slog.Logger) http.Handler {
	target, err := url.Parse(upstreamURL)
	if err != nil {
		log.Error("proxy: invalid upstream URL", "url", upstreamURL, "err", err)
		panic(err)
	}

	rp := httputil.NewSingleHostReverseProxy(target)

	// Use a transport tuned for SSE: no response buffering, long idle timeout.
	rp.Transport = &http.Transport{
		MaxIdleConns:        100,
		IdleConnTimeout:     120 * time.Second,
		DisableCompression:  true, // keep SSE streams intact
		ForceAttemptHTTP2:   false,
	}

	// Rewrite the request before forwarding.
	director := rp.Director
	rp.Director = func(req *http.Request) {
		director(req)
		req.Host = target.Host

		// Strip the Authorization header so the upstream never sees the
		// client's token (the upstream trusts the guard implicitly).
		req.Header.Del("Authorization")

		// Inject the authenticated client name as a trusted internal header.
		client := auth.ClientFromContext(req.Context())
		req.Header.Set("X-Guard-Client", client)
		req.Header.Set("X-Forwarded-By", "health-bee-guard")
	}

	// Log upstream errors without crashing.
	rp.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Error("proxy: upstream error", "err", err, "path", r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte(`{"error":"upstream unavailable"}`))
	}

	return rp
}
