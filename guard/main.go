package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/healthbee/guard/internal/auth"
	"github.com/healthbee/guard/internal/middleware"
	"github.com/healthbee/guard/internal/proxy"
	"github.com/healthbee/guard/internal/ratelimit"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg := loadConfig()

	// Build the layered handler stack (innermost → outermost)
	//   proxy → auth → rate-limit → logging → CORS
	upstream := proxy.New(cfg.UpstreamURL, log)

	authed := auth.Middleware(upstream, cfg.APIKeys, log)

	rl := ratelimit.NewLimiter(cfg.RateLimit, cfg.RateBurst)
	limited := rl.Middleware(authed, log)

	logged := middleware.Logger(limited, log)
	handler := middleware.CORS(logged, cfg.AllowedOrigins)

	srv := &http.Server{
		Addr:         cfg.ListenAddr,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second, // generous for SSE streams
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Info("guard server starting", "addr", cfg.ListenAddr, "upstream", cfg.UpstreamURL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	<-stop
	log.Info("shutting down")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Error("shutdown error", "err", err)
	}
}
