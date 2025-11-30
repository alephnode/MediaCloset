package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"golang.org/x/time/rate"
)

func TestRateLimiter(t *testing.T) {
	// Create a test handler that just returns 200 OK
	testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	t.Run("Health endpoint bypasses rate limiting", func(t *testing.T) {
		rl := NewRateLimiter()
		handler := rl.Middleware()(testHandler)

		// Make many requests to /health
		for i := 0; i < 30; i++ {
			req := httptest.NewRequest("GET", "/health", nil)
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != http.StatusOK {
				t.Errorf("Request %d: Expected status 200, got %d", i, rr.Code)
			}
		}
	})

	t.Run("Rate limit enforced per API key", func(t *testing.T) {
		// Create a custom rate limiter with very low limits for testing
		rl := &RateLimiter{
			limiters: make(map[string]*rate.Limiter),
			rate:     rate.Limit(1.0), // 1 request per second
			burst:    2,               // Allow burst of 2
		}

		handler := rl.Middleware()(testHandler)
		apiKey := "test-key-123"

		// First 2 requests should succeed (burst capacity)
		for i := 0; i < 2; i++ {
			req := httptest.NewRequest("GET", "/query", nil)
			req.Header.Set("X-API-Key", apiKey)
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != http.StatusOK {
				t.Errorf("Request %d: Expected status 200, got %d", i, rr.Code)
			}
		}

		// Next request should be rate limited
		req := httptest.NewRequest("GET", "/query", nil)
		req.Header.Set("X-API-Key", apiKey)
		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusTooManyRequests {
			t.Errorf("Expected status 429, got %d", rr.Code)
		}

		expectedBody := `{"error":"Rate limit exceeded. Maximum 100 requests per minute."}`
		if rr.Body.String() != expectedBody {
			t.Errorf("Expected body %q, got %q", expectedBody, rr.Body.String())
		}
	})

	t.Run("Different API keys have separate rate limits", func(t *testing.T) {
		// Create a custom rate limiter with very low limits
		rl := &RateLimiter{
			limiters: make(map[string]*rate.Limiter),
			rate:     rate.Limit(1.0), // 1 request per second
			burst:    1,               // Allow burst of 1
		}

		handler := rl.Middleware()(testHandler)

		// First API key - use up burst
		req1 := httptest.NewRequest("GET", "/query", nil)
		req1.Header.Set("X-API-Key", "key-1")
		rr1 := httptest.NewRecorder()
		handler.ServeHTTP(rr1, req1)

		if rr1.Code != http.StatusOK {
			t.Errorf("Expected key-1 first request to succeed, got status %d", rr1.Code)
		}

		// Second API key should still have burst available
		req2 := httptest.NewRequest("GET", "/query", nil)
		req2.Header.Set("X-API-Key", "key-2")
		rr2 := httptest.NewRecorder()
		handler.ServeHTTP(rr2, req2)

		if rr2.Code != http.StatusOK {
			t.Errorf("Expected key-2 first request to succeed, got status %d", rr2.Code)
		}

		// First API key should now be rate limited
		req3 := httptest.NewRequest("GET", "/query", nil)
		req3.Header.Set("X-API-Key", "key-1")
		rr3 := httptest.NewRecorder()
		handler.ServeHTTP(rr3, req3)

		if rr3.Code != http.StatusTooManyRequests {
			t.Errorf("Expected key-1 second request to be rate limited, got status %d", rr3.Code)
		}
	})

	t.Run("Rate limit allows request without API key", func(t *testing.T) {
		rl := NewRateLimiter()
		handler := rl.Middleware()(testHandler)

		// Request without API key should pass through (auth middleware will handle it)
		req := httptest.NewRequest("GET", "/query", nil)
		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("Expected status 200, got %d", rr.Code)
		}
	})

	t.Run("Rate limit refills over time", func(t *testing.T) {
		// Create a custom rate limiter with quick refill for testing
		rl := &RateLimiter{
			limiters: make(map[string]*rate.Limiter),
			rate:     rate.Limit(10.0), // 10 requests per second
			burst:    1,                // Allow burst of 1
		}

		handler := rl.Middleware()(testHandler)
		apiKey := "test-refill-key"

		// First request succeeds
		req1 := httptest.NewRequest("GET", "/query", nil)
		req1.Header.Set("X-API-Key", apiKey)
		rr1 := httptest.NewRecorder()
		handler.ServeHTTP(rr1, req1)

		if rr1.Code != http.StatusOK {
			t.Errorf("First request: Expected status 200, got %d", rr1.Code)
		}

		// Second request immediately after should be rate limited
		req2 := httptest.NewRequest("GET", "/query", nil)
		req2.Header.Set("X-API-Key", apiKey)
		rr2 := httptest.NewRecorder()
		handler.ServeHTTP(rr2, req2)

		if rr2.Code != http.StatusTooManyRequests {
			t.Errorf("Second request: Expected status 429, got %d", rr2.Code)
		}

		// Wait for token to refill (100ms at 10 req/sec)
		time.Sleep(150 * time.Millisecond)

		// Third request after wait should succeed
		req3 := httptest.NewRequest("GET", "/query", nil)
		req3.Header.Set("X-API-Key", apiKey)
		rr3 := httptest.NewRecorder()
		handler.ServeHTTP(rr3, req3)

		if rr3.Code != http.StatusOK {
			t.Errorf("Third request after wait: Expected status 200, got %d", rr3.Code)
		}
	})
}
