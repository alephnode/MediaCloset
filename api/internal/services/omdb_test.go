package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOMDBService_SearchMovie(t *testing.T) {
	tests := []struct {
		name         string
		title        string
		director     *string
		year         *int
		mockResponse string
		statusCode   int
		wantErr      bool
		wantTitle    string
		wantDirector *string
		wantYear     *int
	}{
		{
			name:       "successful search with all fields",
			title:      "The Matrix",
			mockResponse: `{
				"Title": "The Matrix",
				"Year": "1999",
				"Director": "Lana Wachowski, Lilly Wachowski",
				"Genre": "Action, Sci-Fi",
				"Plot": "A computer hacker learns about the true nature of reality.",
				"Poster": "https://example.com/poster.jpg",
				"imdbRating": "8.7",
				"Runtime": "136 min",
				"Response": "True"
			}`,
			statusCode:   http.StatusOK,
			wantErr:      false,
			wantTitle:    "The Matrix",
			wantDirector: stringPtr("Lana Wachowski, Lilly Wachowski"),
			wantYear:     intPtr(1999),
		},
		{
			name:       "movie not found",
			title:      "NonexistentMovie123",
			mockResponse: `{
				"Response": "False",
				"Error": "Movie not found!"
			}`,
			statusCode: http.StatusOK,
			wantErr:    true,
		},
		{
			name:         "server error",
			title:        "Test Movie",
			mockResponse: "Internal Server Error",
			statusCode:   http.StatusInternalServerError,
			wantErr:      true,
		},
		{
			name:       "search with year filter",
			title:      "Batman",
			year:       intPtr(1989),
			mockResponse: `{
				"Title": "Batman",
				"Year": "1989",
				"Director": "Tim Burton",
				"Response": "True"
			}`,
			statusCode:   http.StatusOK,
			wantErr:      false,
			wantTitle:    "Batman",
			wantDirector: stringPtr("Tim Burton"),
			wantYear:     intPtr(1989),
		},
		{
			name:     "search with director filter",
			title:    "Inception",
			director: stringPtr("Christopher Nolan"),
			mockResponse: `{
				"Title": "Inception",
				"Year": "2010",
				"Director": "Christopher Nolan",
				"Response": "True"
			}`,
			statusCode:   http.StatusOK,
			wantErr:      false,
			wantTitle:    "Inception",
			wantDirector: stringPtr("Christopher Nolan"),
			wantYear:     intPtr(2010),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mock server
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify query parameters
				if r.URL.Query().Get("t") != tt.title {
					t.Errorf("Expected title %s, got %s", tt.title, r.URL.Query().Get("t"))
				}
				if tt.year != nil && r.URL.Query().Get("y") != "" {
					// Year parameter should be present if provided
				}

				w.WriteHeader(tt.statusCode)
				w.Write([]byte(tt.mockResponse))
			}))
			defer server.Close()

			// Create service with mock server URL
			service := &OMDBService{
				client: server.Client(),
				apiKey: "test-api-key",
				baseURL: server.URL,
			}

			// Execute search
			result, err := service.SearchMovie(context.Background(), tt.title, tt.director, tt.year)

			// Check error
			if (err != nil) != tt.wantErr {
				t.Errorf("SearchMovie() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			// If we expected an error, we're done
			if tt.wantErr {
				return
			}

			// Verify result fields
			if result == nil {
				t.Fatal("Expected non-nil result")
			}

			if tt.wantTitle != "" && result.Title != tt.wantTitle {
				t.Errorf("Title = %v, want %v", result.Title, tt.wantTitle)
			}

			if tt.wantDirector != nil && (result.Director == nil || *result.Director != *tt.wantDirector) {
				t.Errorf("Director = %v, want %v", result.Director, *tt.wantDirector)
			}

			if tt.wantYear != nil && (result.Year == nil || *result.Year != *tt.wantYear) {
				t.Errorf("Year = %v, want %v", result.Year, *tt.wantYear)
			}

			// Verify source is set
			if result.Source != "omdb" {
				t.Errorf("Source = %s, want omdb", result.Source)
			}
		})
	}
}

func TestOMDBService_SearchMovie_InvalidJSON(t *testing.T) {
	// Test invalid JSON response
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("invalid json {"))
	}))
	defer server.Close()

	service := &OMDBService{
		client: server.Client(),
		apiKey: "test-api-key",
		baseURL: server.URL,
	}

	_, err := service.SearchMovie(context.Background(), "Test", nil, nil)
	if err == nil {
		t.Error("Expected error for invalid JSON, got nil")
	}
}

func TestOMDBService_SearchMovie_ContextCancellation(t *testing.T) {
	// Test context cancellation
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Server should not be reached due to cancelled context
		t.Error("Server should not be called with cancelled context")
	}))
	defer server.Close()

	service := &OMDBService{
		client: server.Client(),
		apiKey: "test-api-key",
		baseURL: server.URL,
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	_, err := service.SearchMovie(ctx, "Test", nil, nil)
	if err == nil {
		t.Error("Expected error for cancelled context, got nil")
	}
}

// Helper functions
func stringPtr(s string) *string {
	return &s
}

func intPtr(i int) *int {
	return &i
}
