// Package auth provides Bearer-token authentication middleware.
// Valid tokens are loaded from the API_KEYS environment variable at startup.
// Each token maps to a client name that is injected into the request context
// for downstream logging and rate-limiting.
package auth

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
)

type contextKey string

const ClientKey contextKey = "client"

// Middleware wraps next with Bearer-token authentication.
// If apiKeys is empty, authentication is DISABLED (dev mode) and a warning is
// logged on every request.
func Middleware(next http.Handler, apiKeys map[string]string, log *slog.Logger) http.Handler {
	if len(apiKeys) == 0 {
		log.Warn("auth: no API_KEYS configured — authentication is DISABLED")
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// /health is always public — no auth required.
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}

		if len(apiKeys) == 0 {
			// Dev mode: inject a synthetic client name so downstream works.
			r = r.WithContext(context.WithValue(r.Context(), ClientKey, "anonymous"))
			next.ServeHTTP(w, r)
			return
		}

		token := bearerToken(r)
		if token == "" {
			jsonError(w, "missing or malformed Authorization header", http.StatusUnauthorized)
			return
		}

		clientName, ok := apiKeys[token]
		if !ok {
			log.Warn("auth: rejected unknown token", "remote", r.RemoteAddr)
			jsonError(w, "invalid API key", http.StatusUnauthorized)
			return
		}

		// Attach client name to context for downstream use.
		ctx := context.WithValue(r.Context(), ClientKey, clientName)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// ClientFromContext retrieves the authenticated client name, or "unknown".
func ClientFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(ClientKey).(string); ok {
		return v
	}
	return "unknown"
}

func bearerToken(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if h == "" {
		return ""
	}
	parts := strings.SplitN(h, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}

func jsonError(w http.ResponseWriter, msg string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
