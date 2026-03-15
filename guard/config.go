package main

import (
	"os"
	"strconv"
	"strings"
)

type config struct {
	ListenAddr     string
	UpstreamURL    string
	AgentURL       string            // Python agent server
	APIKeys        map[string]string // token → client name
	AllowedOrigins []string
	RateLimit      float64 // requests per second per client
	RateBurst      int     // burst allowance
}

func loadConfig() config {
	cfg := config{
		ListenAddr:  env("GUARD_ADDR", ":8080"),
		UpstreamURL: env("UPSTREAM_URL", "http://localhost:3000"),
		AgentURL:    env("AGENT_URL", "http://localhost:4000"),
		RateLimit:   envFloat("RATE_LIMIT_RPS", 2),
		RateBurst:   envInt("RATE_BURST", 10),
	}

	// ALLOWED_ORIGINS=https://app.example.com,https://other.example.com
	origins := env("ALLOWED_ORIGINS", "")
	if origins != "" {
		cfg.AllowedOrigins = strings.Split(origins, ",")
	}

	// API_KEYS=token1:clientA,token2:clientB
	// Each token grants access; the client name is used in logs.
	cfg.APIKeys = parseAPIKeys(env("API_KEYS", ""))

	return cfg
}

func parseAPIKeys(raw string) map[string]string {
	m := make(map[string]string)
	for _, pair := range strings.Split(raw, ",") {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		parts := strings.SplitN(pair, ":", 2)
		token := strings.TrimSpace(parts[0])
		name := token // default client name = token itself
		if len(parts) == 2 {
			name = strings.TrimSpace(parts[1])
		}
		if token != "" {
			m[token] = name
		}
	}
	return m
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envFloat(key string, fallback float64) float64 {
	if v := os.Getenv(key); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
