package middleware

import (
	"context"
	"log"
	"net/http"
	"strings"

	"mediacloset/api/internal/services"
)

// UserContextKey is the key used to store user info in the request context
type UserContextKey struct{}

// UserInfo contains user information from the JWT token
type UserInfo struct {
	UserID string
	Email  string
}

// JWTAuth validates JWT tokens and extracts user information (if present)
// This middleware is permissive - it doesn't require auth, but extracts it if provided
// Individual resolvers will enforce authentication as needed
func JWTAuth(authService *services.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Allow health check without authentication
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}

			// Allow GraphQL playground in development without auth
			if r.URL.Path == "/" && r.Method == "GET" {
				next.ServeHTTP(w, r)
				return
			}

			// Get token from Authorization header
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				// Try to get from query parameter (for GraphQL playground)
				authHeader = r.URL.Query().Get("token")
			}

			// If no token provided, continue without authentication
			// Individual resolvers will check for auth as needed
			if authHeader == "" {
				next.ServeHTTP(w, r)
				return
			}

			// Extract token from "Bearer <token>" format
			tokenString := authHeader
			if strings.HasPrefix(authHeader, "Bearer ") {
				tokenString = strings.TrimPrefix(authHeader, "Bearer ")
			}

			// Validate token
			userID, email, err := authService.ValidateToken(tokenString)
			if err != nil {
				// Invalid token, but continue anyway - resolver will handle auth errors
				log.Printf("[JWT Auth] Invalid token for %s %s: %v", r.Method, r.URL.Path, err)
				next.ServeHTTP(w, r)
				return
			}

			// Add user info to context
			ctx := context.WithValue(r.Context(), UserContextKey{}, UserInfo{
				UserID: userID,
				Email:  email,
			})

			// Continue with authenticated request
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUserFromContext extracts user information from the request context
func GetUserFromContext(ctx context.Context) (*UserInfo, bool) {
	userInfo, ok := ctx.Value(UserContextKey{}).(UserInfo)
	if !ok {
		return nil, false
	}
	return &userInfo, true
}
