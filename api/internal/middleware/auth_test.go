package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAPIKeyAuth(t *testing.T) {
	apiKey := "test-api-key-12345"

	// Create a test handler that just returns 200 OK
	testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Wrap with auth middleware (production mode - isDevelopment=false)
	authMiddleware := APIKeyAuth(apiKey, false)
	handler := authMiddleware(testHandler)

	tests := []struct {
		name           string
		path           string
		apiKeyHeader   string
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "Valid API key should succeed",
			path:           "/query",
			apiKeyHeader:   apiKey,
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
		{
			name:           "Missing API key should fail",
			path:           "/query",
			apiKeyHeader:   "",
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   "{\"error\":\"Missing X-API-Key header\"}\n",
		},
		{
			name:           "Invalid API key should fail",
			path:           "/query",
			apiKeyHeader:   "wrong-key",
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   "{\"error\":\"Invalid API key\"}\n",
		},
		{
			name:           "Health endpoint should bypass auth",
			path:           "/health",
			apiKeyHeader:   "",
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
		{
			name:           "Case insensitive API key comparison",
			path:           "/query",
			apiKeyHeader:   "TEST-API-KEY-12345",
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", tt.path, nil)
			if tt.apiKeyHeader != "" {
				req.Header.Set("X-API-Key", tt.apiKeyHeader)
			}

			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, rr.Code)
			}

			if rr.Body.String() != tt.expectedBody {
				t.Errorf("Expected body %q, got %q", tt.expectedBody, rr.Body.String())
			}
		})
	}
}

func TestAPIKeyAuthDevelopmentMode(t *testing.T) {
	apiKey := "test-api-key-12345"

	// Create a test handler that just returns 200 OK
	testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Wrap with auth middleware (development mode - isDevelopment=true)
	authMiddleware := APIKeyAuth(apiKey, true)
	handler := authMiddleware(testHandler)

	tests := []struct {
		name           string
		path           string
		apiKeyHeader   string
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "Development mode should bypass auth for root path",
			path:           "/",
			apiKeyHeader:   "",
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
		{
			name:           "Development mode should bypass auth for /query",
			path:           "/query",
			apiKeyHeader:   "",
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
		{
			name:           "Development mode should still work with valid API key",
			path:           "/query",
			apiKeyHeader:   apiKey,
			expectedStatus: http.StatusOK,
			expectedBody:   "OK",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", tt.path, nil)
			if tt.apiKeyHeader != "" {
				req.Header.Set("X-API-Key", tt.apiKeyHeader)
			}

			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, rr.Code)
			}

			if rr.Body.String() != tt.expectedBody {
				t.Errorf("Expected body %q, got %q", tt.expectedBody, rr.Body.String())
			}
		})
	}
}
