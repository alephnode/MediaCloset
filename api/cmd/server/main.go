package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"mediacloset/api/internal/config"
	"mediacloset/api/internal/graph"
	custommw "mediacloset/api/internal/middleware"
	"mediacloset/api/internal/ratelimit"
	"mediacloset/api/internal/services"
)

var startTime = time.Now()

func main() {
	log.Println("Starting MediaCloset GraphQL API...")

	cfg := config.Load()

	r := chi.NewRouter()

	// Middleware block
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	})

	// API key authentication for clients
	r.Use(custommw.APIKeyAuth(cfg.APIKey, cfg.IsDevelopment()))

	apiRateLimiter := custommw.NewRateLimiter()
	r.Use(apiRateLimiter.Middleware())

	rateLimiter := ratelimit.NewServiceLimiter()
	omdbService := services.NewOMDBService(cfg.OMDBAPIKey)
	musicBrainzService := services.NewMusicBrainzService(rateLimiter)
	discogsService := services.NewDiscogsService(cfg.DiscogsKey, cfg.DiscogsSecret)
	itunesService := services.NewITunesService()
	barcodeService := services.NewBarcodeService(
		discogsService,
		itunesService,
		musicBrainzService,
		omdbService,
	)
	hasuraClient := services.NewHasuraClient(cfg.HasuraEndpoint, cfg.HasuraAdminSecret)

	var emailService *services.EmailService
	if cfg.AWSSESFromEmail != "" && cfg.AWSAccessKeyID != "" && cfg.AWSSecretAccessKey != "" {
		var err error
		emailService, err = services.NewEmailService(
			context.Background(),
			cfg.AWSRegion,
			cfg.AWSAccessKeyID,
			cfg.AWSSecretAccessKey,
			cfg.AWSSESFromEmail,
		)
		if err != nil {
			log.Printf("Warning: Failed to initialize email service: %v", err)
			log.Println("Login codes will be logged to console instead")
		}
	} else if !cfg.IsDevelopment() {
		log.Println("Warning: AWS SES not fully configured ")
	}

	authService := services.NewAuthService(hasuraClient, emailService, cfg.JWTSecret, cfg.IsDevelopment())

	// JWT authentication middleware (user authentication)
	r.Use(custommw.JWTAuth(authService))

	resolver := &graph.Resolver{
		Config:          cfg,
		OMDBService:     omdbService,
		MusicBrainz:     musicBrainzService,
		Discogs:         discogsService,
		ITunes:          itunesService,
		BarcodeService:  barcodeService,
		HasuraClient:    hasuraClient,
		AuthService:     authService,
		RateLimiter:     rateLimiter,
		ServerStartTime: startTime,
	}
	srv := handler.NewDefaultServer(graph.NewExecutableSchema(graph.Config{Resolvers: resolver}))

	if cfg.IsDevelopment() {
		r.Handle("/", playground.Handler("MediaCloset GraphQL", "/query"))
		log.Println("GraphQL playground available at http://localhost:" + cfg.Port + "/")
	}

	r.Handle("/query", srv)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		uptime := int(time.Since(startTime).Seconds())
		response := fmt.Sprintf(`{"status":"ok","version":"1.0.0","uptime":%d}`, uptime)
		w.Write([]byte(response))
	})

	addr := cfg.GetServerAddress()
	log.Printf("Server listening on %s", addr)
	log.Printf("GraphQL endpoint: http://localhost%s/query", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}
