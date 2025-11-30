package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDiscogsService_IsConfigured(t *testing.T) {
	tests := []struct {
		name           string
		consumerKey    string
		consumerSecret string
		want           bool
	}{
		{
			name:           "both credentials provided",
			consumerKey:    "test-key",
			consumerSecret: "test-secret",
			want:           true,
		},
		{
			name:           "empty key",
			consumerKey:    "",
			consumerSecret: "test-secret",
			want:           false,
		},
		{
			name:           "empty secret",
			consumerKey:    "test-key",
			consumerSecret: "",
			want:           false,
		},
		{
			name:           "both empty",
			consumerKey:    "",
			consumerSecret: "",
			want:           false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			service := &DiscogsService{
				consumerKey:    tt.consumerKey,
				consumerSecret: tt.consumerSecret,
			}

			if got := service.IsConfigured(); got != tt.want {
				t.Errorf("IsConfigured() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDiscogsService_SearchByBarcode(t *testing.T) {
	tests := []struct {
		name         string
		barcode      string
		mockResponse string
		statusCode   int
		wantErr      bool
		wantArtist   *string
		wantAlbum    *string
		wantYear     *int
		wantLabel    *string
		wantGenres   []string
	}{
		{
			name:    "successful search with all fields",
			barcode: "724384260651",
			mockResponse: `{
				"results": [{
					"id": 249504,
					"title": "Pink Floyd - The Dark Side Of The Moon",
					"year": 1973,
					"label": ["Harvest"],
					"genre": ["Rock"],
					"style": ["Prog Rock", "Psychedelic Rock"],
					"cover_image": "https://example.com/cover.jpg",
					"resource_url": "https://api.discogs.com/releases/249504",
					"type": "release"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Pink Floyd"),
			wantAlbum:  stringPtr("The Dark Side Of The Moon"),
			wantYear:   intPtr(1973),
			wantLabel:  stringPtr("Harvest"),
			wantGenres: []string{"Rock", "Prog Rock", "Psychedelic Rock"},
		},
		{
			name:    "no results found",
			barcode: "000000000000",
			mockResponse: `{
				"results": []
			}`,
			statusCode: http.StatusOK,
			wantErr:    true,
		},
		{
			name:         "server error",
			barcode:      "123456789",
			mockResponse: "Internal Server Error",
			statusCode:   http.StatusInternalServerError,
			wantErr:      true,
		},
		{
			name:    "title without separator - album only",
			barcode: "123456",
			mockResponse: `{
				"results": [{
					"title": "Some Album",
					"year": 2020,
					"type": "release"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantAlbum:  stringPtr("Some Album"),
			wantYear:   intPtr(2020),
		},
		{
			name:    "duplicate genres removed",
			barcode: "123456",
			mockResponse: `{
				"results": [{
					"title": "Artist - Album",
					"genre": ["Rock", "Jazz"],
					"style": ["Rock", "Fusion"],
					"type": "release"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Artist"),
			wantAlbum:  stringPtr("Album"),
			wantGenres: []string{"Rock", "Jazz", "Fusion"},
		},
		{
			name:    "multiple labels - uses first",
			barcode: "123456",
			mockResponse: `{
				"results": [{
					"title": "Artist - Album",
					"label": ["Label One", "Label Two", "Label Three"],
					"type": "release"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Artist"),
			wantAlbum:  stringPtr("Album"),
			wantLabel:  stringPtr("Label One"),
		},
		{
			name:    "missing optional fields",
			barcode: "123456",
			mockResponse: `{
				"results": [{
					"title": "Minimal - Release",
					"type": "release"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Minimal"),
			wantAlbum:  stringPtr("Release"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mock server
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify query parameters
				if r.URL.Query().Get("barcode") != tt.barcode {
					t.Errorf("Expected barcode %s, got %s", tt.barcode, r.URL.Query().Get("barcode"))
				}
				if r.URL.Query().Get("type") != "release" {
					t.Errorf("Expected type=release, got %s", r.URL.Query().Get("type"))
				}

				// Verify auth header
				authHeader := r.Header.Get("Authorization")
				if !containsHelper(authHeader, "Discogs key=") {
					t.Error("Expected Discogs auth header")
				}

				w.WriteHeader(tt.statusCode)
				w.Write([]byte(tt.mockResponse))
			}))
			defer server.Close()

			// Create service with mock server
			service := &DiscogsService{
				client:         server.Client(),
				consumerKey:    "test-key",
				consumerSecret: "test-secret",
				baseURL:        server.URL,
			}

			// Execute search
			result, err := service.SearchByBarcode(context.Background(), tt.barcode)

			// Check error
			if (err != nil) != tt.wantErr {
				t.Errorf("SearchByBarcode() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			// If we expected an error, we're done
			if tt.wantErr {
				return
			}

			// Verify result
			if result == nil {
				t.Fatal("Expected non-nil result")
			}

			if result.Source != "discogs" {
				t.Errorf("Source = %s, want discogs", result.Source)
			}

			if tt.wantArtist != nil {
				if result.Artist == nil {
					t.Errorf("Artist = nil, want %s", *tt.wantArtist)
				} else if *result.Artist != *tt.wantArtist {
					t.Errorf("Artist = %s, want %s", *result.Artist, *tt.wantArtist)
				}
			}

			if tt.wantAlbum != nil {
				if result.Album == nil {
					t.Errorf("Album = nil, want %s", *tt.wantAlbum)
				} else if *result.Album != *tt.wantAlbum {
					t.Errorf("Album = %s, want %s", *result.Album, *tt.wantAlbum)
				}
			}

			if tt.wantYear != nil {
				if result.Year == nil {
					t.Errorf("Year = nil, want %d", *tt.wantYear)
				} else if *result.Year != *tt.wantYear {
					t.Errorf("Year = %d, want %d", *result.Year, *tt.wantYear)
				}
			}

			if tt.wantLabel != nil {
				if result.Label == nil {
					t.Errorf("Label = nil, want %s", *tt.wantLabel)
				} else if *result.Label != *tt.wantLabel {
					t.Errorf("Label = %s, want %s", *result.Label, *tt.wantLabel)
				}
			}

			if len(tt.wantGenres) > 0 {
				if len(result.Genres) != len(tt.wantGenres) {
					t.Errorf("Genres length = %d, want %d", len(result.Genres), len(tt.wantGenres))
				} else {
					for i, genre := range tt.wantGenres {
						if result.Genres[i] != genre {
							t.Errorf("Genres[%d] = %s, want %s", i, result.Genres[i], genre)
						}
					}
				}
			}
		})
	}
}

func TestDiscogsService_SearchByBarcode_NotConfigured(t *testing.T) {
	service := &DiscogsService{
		consumerKey:    "",
		consumerSecret: "",
	}

	_, err := service.SearchByBarcode(context.Background(), "test")
	if err == nil {
		t.Error("Expected error for unconfigured service, got nil")
	}
}

func TestDiscogsService_SearchByBarcode_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("invalid json {"))
	}))
	defer server.Close()

	service := &DiscogsService{
		client:         server.Client(),
		consumerKey:    "test-key",
		consumerSecret: "test-secret",
		baseURL:        server.URL,
	}

	_, err := service.SearchByBarcode(context.Background(), "test")
	if err == nil {
		t.Error("Expected error for invalid JSON, got nil")
	}
}

func TestDiscogsService_SearchByBarcode_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("Server should not be called with cancelled context")
	}))
	defer server.Close()

	service := &DiscogsService{
		client:         server.Client(),
		consumerKey:    "test-key",
		consumerSecret: "test-secret",
		baseURL:        server.URL,
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := service.SearchByBarcode(ctx, "test")
	if err == nil {
		t.Error("Expected error for cancelled context, got nil")
	}
}
