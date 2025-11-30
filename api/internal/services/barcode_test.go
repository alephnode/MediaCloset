package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestCleanBarcode(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "remove leading zeros",
			input: "0001234567890",
			want:  "1234567890",
		},
		{
			name:  "remove whitespace",
			input: "  123456  ",
			want:  "123456",
		},
		{
			name:  "remove dashes",
			input: "123-456-789",
			want:  "123456789",
		},
		{
			name:  "remove spaces",
			input: "123 456 789",
			want:  "123456789",
		},
		{
			name:  "remove non-numeric characters",
			input: "ABC123DEF456",
			want:  "123456",
		},
		{
			name:  "all zeros becomes single zero",
			input: "000000",
			want:  "0",
		},
		{
			name:  "complex cleaning",
			input: "  00-123 ABC 456  ",
			want:  "123456",
		},
		{
			name:  "already clean",
			input: "1234567890",
			want:  "1234567890",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := cleanBarcode(tt.input)
			if got != tt.want {
				t.Errorf("cleanBarcode(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestBarcodeService_LookupAlbum_DiscogsSuccess(t *testing.T) {
	// Create mock Discogs server that returns a result
	discogsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"results": [{
				"title": "Artist - Album",
				"year": 2020,
				"type": "release"
			}]
		}`))
	}))
	defer discogsServer.Close()

	// Create mock iTunes server (should not be called)
	itunesServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("iTunes should not be called when Discogs succeeds")
	}))
	defer itunesServer.Close()

	// Create services
	discogs := &DiscogsService{
		client:         &http.Client{Timeout: 1 * time.Second},
		consumerKey:    "test-key",
		consumerSecret: "test-secret",
		baseURL:        discogsServer.URL,
	}

	itunes := &ITunesService{
		client:  &http.Client{Timeout: 1 * time.Second},
		baseURL: itunesServer.URL,
	}

	barcodeService := NewBarcodeService(discogs, itunes, nil, nil)

	result, err := barcodeService.LookupAlbum(context.Background(), "123456")

	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if result == nil {
		t.Fatal("Expected non-nil result")
	}

	if result.Source != "discogs" {
		t.Errorf("Source = %s, want discogs", result.Source)
	}
}

func TestBarcodeService_LookupAlbum_FallbackToITunes(t *testing.T) {
	// Create mock Discogs server that returns no results
	discogsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"results": []}`))
	}))
	defer discogsServer.Close()

	// Create mock iTunes server that returns a result
	itunesServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"resultCount": 1,
			"results": [{
				"artistName": "iTunes Artist",
				"collectionName": "iTunes Album"
			}]
		}`))
	}))
	defer itunesServer.Close()

	// Create services
	discogs := &DiscogsService{
		client:         &http.Client{Timeout: 1 * time.Second},
		consumerKey:    "test-key",
		consumerSecret: "test-secret",
		baseURL:        discogsServer.URL,
	}

	itunes := &ITunesService{
		client:  &http.Client{Timeout: 1 * time.Second},
		baseURL: itunesServer.URL,
	}

	barcodeService := NewBarcodeService(discogs, itunes, nil, nil)

	result, err := barcodeService.LookupAlbum(context.Background(), "123456")

	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if result == nil {
		t.Fatal("Expected non-nil result")
	}

	if result.Source != "itunes" {
		t.Errorf("Source = %s, want itunes", result.Source)
	}
}

func TestBarcodeService_LookupAlbum_AllServicesFail(t *testing.T) {
	// Create mock Discogs server that returns no results
	discogsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"results": []}`))
	}))
	defer discogsServer.Close()

	// Create mock iTunes server that returns no results
	itunesServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"resultCount": 0, "results": []}`))
	}))
	defer itunesServer.Close()

	// Create services
	discogs := &DiscogsService{
		client:         &http.Client{Timeout: 1 * time.Second},
		consumerKey:    "test-key",
		consumerSecret: "test-secret",
		baseURL:        discogsServer.URL,
	}

	itunes := &ITunesService{
		client:  &http.Client{Timeout: 1 * time.Second},
		baseURL: itunesServer.URL,
	}

	barcodeService := NewBarcodeService(discogs, itunes, nil, nil)

	result, err := barcodeService.LookupAlbum(context.Background(), "123456")

	if err == nil {
		t.Error("Expected error when all services fail, got nil")
	}

	if result != nil {
		t.Errorf("Expected nil result, got %v", result)
	}
}

func TestBarcodeService_LookupMovie(t *testing.T) {
	service := NewBarcodeService(nil, nil, nil, nil)

	result, err := service.LookupMovie(context.Background(), "123456789")

	if err == nil {
		t.Error("Expected error for unimplemented movie lookup, got nil")
	}

	if result != nil {
		t.Errorf("Expected nil result, got %v", result)
	}

	expectedErrMsg := "movie barcode lookup not yet implemented"
	if err.Error() != expectedErrMsg {
		t.Errorf("Error message = %s, want %s", err.Error(), expectedErrMsg)
	}
}

func TestBarcodeService_LookupAlbum_DiscogsNotConfigured(t *testing.T) {
	// Create unconfigured Discogs service (empty credentials)
	discogs := &DiscogsService{
		client:         &http.Client{Timeout: 1 * time.Second},
		consumerKey:    "",
		consumerSecret: "",
		baseURL:        "http://unused",
	}

	// Create mock iTunes server that returns a result
	itunesServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"resultCount": 1,
			"results": [{
				"artistName": "iTunes Artist",
				"collectionName": "iTunes Album"
			}]
		}`))
	}))
	defer itunesServer.Close()

	itunes := &ITunesService{
		client:  &http.Client{Timeout: 1 * time.Second},
		baseURL: itunesServer.URL,
	}

	barcodeService := NewBarcodeService(discogs, itunes, nil, nil)

	result, err := barcodeService.LookupAlbum(context.Background(), "123456")

	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if result == nil {
		t.Fatal("Expected non-nil result")
	}

	// Should skip Discogs and use iTunes
	if result.Source != "itunes" {
		t.Errorf("Source = %s, want itunes (Discogs should be skipped when not configured)", result.Source)
	}
}
