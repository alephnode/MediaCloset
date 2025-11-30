package middleware

import (
	"log"
	"net/http"
	"strings"
)

// APIKeyAuth validates the X-API-Key header against the configured API key
func APIKeyAuth(apiKey string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Allow health check without authentication
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}

			// Get API key from header
			providedKey := r.Header.Get("X-API-Key")
			if providedKey == "" {
				log.Printf("[Auth] Missing X-API-Key header for %s %s", r.Method, r.URL.Path)
				http.Error(w, `{"error":"Missing X-API-Key header"}`, http.StatusUnauthorized)
				return
			}

			// Validate API key
			if !strings.EqualFold(providedKey, apiKey) {
				log.Printf("[Auth] Invalid API key for %s %s", r.Method, r.URL.Path)
				http.Error(w, `{"error":"Invalid API key"}`, http.StatusUnauthorized)
				return
			}

			// API key is valid, continue
			next.ServeHTTP(w, r)
		})
	}
}
