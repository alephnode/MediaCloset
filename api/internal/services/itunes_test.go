package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestITunesService_SearchByBarcode(t *testing.T) {
	tests := []struct {
		name         string
		barcode      string
		mockResponse string
		statusCode   int
		wantErr      bool
		wantArtist   *string
		wantAlbum    *string
		wantYear     *int
		wantGenres   []string
	}{
		{
			name:    "successful search with all fields",
			barcode: "602537347377",
			mockResponse: `{
				"resultCount": 1,
				"results": [{
					"artistName": "Taylor Swift",
					"collectionName": "1989",
					"releaseDate": "2014-10-27T07:00:00Z",
					"primaryGenreName": "Pop",
					"artworkUrl100": "https://example.com/artwork/100x100.jpg",
					"trackCount": 13,
					"collectionId": 907242701
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Taylor Swift"),
			wantAlbum:  stringPtr("1989"),
			wantYear:   intPtr(2014),
			wantGenres: []string{"Pop"},
		},
		{
			name:    "no results found",
			barcode: "000000000000",
			mockResponse: `{
				"resultCount": 0,
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
			name:    "multiple results - uses first",
			barcode: "123456789",
			mockResponse: `{
				"resultCount": 2,
				"results": [
					{
						"artistName": "Artist One",
						"collectionName": "Album One",
						"releaseDate": "2020-01-01T00:00:00Z",
						"primaryGenreName": "Rock"
					},
					{
						"artistName": "Artist Two",
						"collectionName": "Album Two",
						"releaseDate": "2021-01-01T00:00:00Z",
						"primaryGenreName": "Jazz"
					}
				]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Artist One"),
			wantAlbum:  stringPtr("Album One"),
			wantYear:   intPtr(2020),
			wantGenres: []string{"Rock"},
		},
		{
			name:    "artwork URL upgrade - 100x100 to 600x600",
			barcode: "123456",
			mockResponse: `{
				"resultCount": 1,
				"results": [{
					"artistName": "Test Artist",
					"collectionName": "Test Album",
					"artworkUrl100": "https://example.com/image/100x100bb.jpg"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Test Artist"),
			wantAlbum:  stringPtr("Test Album"),
		},
		{
			name:    "missing optional fields",
			barcode: "123456",
			mockResponse: `{
				"resultCount": 1,
				"results": [{
					"artistName": "Minimal Artist",
					"collectionName": "Minimal Album"
				}]
			}`,
			statusCode: http.StatusOK,
			wantErr:    false,
			wantArtist: stringPtr("Minimal Artist"),
			wantAlbum:  stringPtr("Minimal Album"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mock server
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				// Verify query parameters
				if r.URL.Query().Get("term") != tt.barcode {
					t.Errorf("Expected barcode %s, got %s", tt.barcode, r.URL.Query().Get("term"))
				}
				if r.URL.Query().Get("entity") != "album" {
					t.Errorf("Expected entity=album, got %s", r.URL.Query().Get("entity"))
				}

				w.WriteHeader(tt.statusCode)
				w.Write([]byte(tt.mockResponse))
			}))
			defer server.Close()

			// Create service with mock server
			service := &ITunesService{
				client:  server.Client(),
				baseURL: server.URL,
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

			if result.Source != "itunes" {
				t.Errorf("Source = %s, want itunes", result.Source)
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

			// Check artwork URL upgrade
			if tt.name == "artwork URL upgrade - 100x100 to 600x600" {
				if result.CoverURL == nil {
					t.Error("CoverURL = nil, want upgraded URL")
				} else if !contains(*result.CoverURL, "600x600") {
					t.Errorf("CoverURL = %s, expected to contain 600x600", *result.CoverURL)
				}
			}
		})
	}
}

func TestITunesService_SearchByBarcode_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("invalid json {"))
	}))
	defer server.Close()

	service := &ITunesService{
		client:  server.Client(),
		baseURL: server.URL,
	}

	_, err := service.SearchByBarcode(context.Background(), "test")
	if err == nil {
		t.Error("Expected error for invalid JSON, got nil")
	}
}

func TestITunesService_SearchByBarcode_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("Server should not be called with cancelled context")
	}))
	defer server.Close()

	service := &ITunesService{
		client:  server.Client(),
		baseURL: server.URL,
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := service.SearchByBarcode(ctx, "test")
	if err == nil {
		t.Error("Expected error for cancelled context, got nil")
	}
}

// Helper function
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
