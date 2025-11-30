package middleware

import (
	"log"
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// RateLimiter manages rate limits for API clients
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	mu       sync.RWMutex
	rate     rate.Limit
	burst    int
}

// NewRateLimiter creates a new rate limiter for API clients
// Default: 100 requests per minute (burst of 20)
func NewRateLimiter() *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
		rate:     rate.Limit(100.0 / 60.0), // 100 requests per minute
		burst:    20,
	}
}

// getLimiter gets or creates a rate limiter for a specific API key
func (rl *RateLimiter) getLimiter(apiKey string) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	limiter, exists := rl.limiters[apiKey]
	if !exists {
		limiter = rate.NewLimiter(rl.rate, rl.burst)
		rl.limiters[apiKey] = limiter
	}

	return limiter
}

// Middleware returns a middleware that enforces rate limiting per API key
func (rl *RateLimiter) Middleware() func(http.Handler) http.Handler {
	// Start cleanup goroutine to remove old limiters
	go rl.cleanup()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip rate limiting for health check
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}

			// Get API key from header (should be set by auth middleware)
			apiKey := r.Header.Get("X-API-Key")
			if apiKey == "" {
				// If no API key, allow request (auth middleware will handle it)
				next.ServeHTTP(w, r)
				return
			}

			// Get limiter for this API key
			limiter := rl.getLimiter(apiKey)

			// Check if request is allowed
			if !limiter.Allow() {
				log.Printf("[RateLimit] Rate limit exceeded for API key ending in ...%s", apiKey[len(apiKey)-4:])
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"Rate limit exceeded. Maximum 100 requests per minute."}`))
				return
			}

			// Request is allowed
			next.ServeHTTP(w, r)
		})
	}
}

// cleanup periodically removes unused limiters to prevent memory leaks
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		rl.mu.Lock()
		// In a production system, you might track last access time
		// For now, we keep all limiters (single-user app)
		rl.mu.Unlock()
	}
}
