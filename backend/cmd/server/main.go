package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/serverdeck/serverdeck-backend/internal/api"
	"github.com/serverdeck/serverdeck-backend/internal/auth"
	"github.com/serverdeck/serverdeck-backend/internal/config"
	"github.com/serverdeck/serverdeck-backend/internal/docker"
	"github.com/serverdeck/serverdeck-backend/internal/hostctrl"
	"github.com/serverdeck/serverdeck-backend/internal/metrics"
	"github.com/serverdeck/serverdeck-backend/internal/services"
)

const version = "1.0.0"

func main() {
	log.Printf("Starting ServerDeck Backend Agent v%s...", version)

	// 1. Load configuration
	cfg := config.Load()
	log.Printf("[Config] Listen: %s | Config Path: %s", cfg.ListenAddr, cfg.ServicesConfigPath)

	// 2. Setup root context for graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 3. Initialize Metrics Collector
	var collector metrics.Collector
	if cfg.ForceMockMetrics {
		log.Println("[Metrics] Using mock metrics collector.")
		collector = metrics.NewMockCollector()
	} else {
		collector = metrics.NewSystemCollector()
	}

	// 4. Initialize Docker client (with fallback to mock if unreachable)
	dockerCli := docker.NewClient(ctx, cfg.ForceMockDocker)
	defer func() {
		_ = dockerCli.Close()
	}()

	// 5. Initialize Services manager
	svcMgr := services.NewManager(cfg.ServicesConfigPath)
	if err := svcMgr.Load(); err != nil {
		log.Printf("[Services] Warning: failed to load services config: %v", err)
	}

	// 6. Initialize WebSocket Hub
	wsHub := api.NewWSHub()
	go wsHub.Run(ctx)

	// 7. Background ticker for real-time host_tick over WebSocket
	go startHostTicker(ctx, cfg.TickInterval, wsHub, collector, dockerCli)

	// 8. Subscribe to Docker container events stream
	go startContainerEventListener(ctx, wsHub, dockerCli)

	// 9. Setup API and router with Auth, Host Control, and CORS
	authMw := auth.NewMiddleware(cfg.AuthToken, cfg.AllowedOrigins)
	hostCtrl := hostctrl.NewManager(dockerCli.IsMock())
	serverAPI := api.NewServerAPI(collector, dockerCli, svcMgr, hostCtrl, wsHub, version)
	handler := api.SetupRouter(serverAPI, authMw)

	// 10. Start HTTP server
	httpServer := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("ServerDeck agent listening on http://%s", cfg.ListenAddr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("ServerDeck failed to listen: %v", err)
		}
	}()

	// 11. Graceful shutdown
	<-ctx.Done()
	log.Println("Shutting down ServerDeck agent gracefully...")

	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelShutdown()

	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	log.Println("ServerDeck backend agent exited cleanly.")
}

func startHostTicker(
	ctx context.Context,
	interval time.Duration,
	wsHub *api.WSHub,
	collector metrics.Collector,
	dockerCli docker.Client,
) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Only gather and broadcast if at least one client is connected
			if wsHub.ConnectedClientsCount() == 0 {
				continue
			}

			summary, err := dockerCli.GetSummary(ctx)
			if err != nil {
				summary = metrics.ContainersSummary{}
			}

			overview, err := collector.GetHostOverview(ctx, summary)
			if err != nil {
				log.Printf("[Ticker] Failed to get host overview: %v", err)
				continue
			}

			wsHub.BroadcastHostTick(overview)
		}
	}
}

func startContainerEventListener(
	ctx context.Context,
	wsHub *api.WSHub,
	dockerCli docker.Client,
) {
	eventsChan, err := dockerCli.SubscribeEvents(ctx)
	if err != nil {
		log.Printf("[Events] Failed to subscribe to container events: %v", err)
		return
	}

	for {
		select {
		case <-ctx.Done():
			return
		case event, ok := <-eventsChan:
			if !ok {
				return
			}
			wsHub.BroadcastContainerEvent(event)
		}
	}
}
