package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"mediacloset/api/internal/graph/model"
)

// DiscogsService handles requests to the Discogs API
type DiscogsService struct {
	client         *http.Client
	consumerKey    string
	consumerSecret string
	baseURL        string
}

// NewDiscogsService creates a new Discogs API client
func NewDiscogsService(consumerKey, consumerSecret string) *DiscogsService {
	return &DiscogsService{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		consumerKey:    consumerKey,
		consumerSecret: consumerSecret,
		baseURL:        "https://api.discogs.com",
	}
}

// DiscogsSearchResponse represents the response from Discogs database search
type DiscogsSearchResponse struct {
	Results []struct {
		ID          int      `json:"id"`
		Title       string   `json:"title"`  // Format: "Artist - Album"
		Year        int      `json:"year"`
		Label       []string `json:"label"`
		Genre       []string `json:"genre"`
		Style       []string `json:"style"`
		CoverImage  string   `json:"cover_image"`
		ResourceURL string   `json:"resource_url"`
		Type        string   `json:"type"` // "release", "master", etc.
	} `json:"results"`
}

// IsConfigured returns true if Discogs credentials are provided
func (s *DiscogsService) IsConfigured() bool {
	return s.consumerKey != "" && s.consumerSecret != ""
}

// SearchByBarcode searches Discogs for a release using a barcode (UPC)
func (s *DiscogsService) SearchByBarcode(ctx context.Context, barcode string) (*model.AlbumData, error) {
	if !s.IsConfigured() {
		return nil, fmt.Errorf("Discogs API credentials not configured")
	}

	// Build query URL
	params := url.Values{}
	params.Set("barcode", barcode)
	params.Set("type", "release")

	apiURL := fmt.Sprintf("%s/database/search?%s", s.baseURL, params.Encode())

	// Create request
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Add authentication headers
	req.Header.Set("User-Agent", "MediaCloset/1.0 (Go API)")
	req.Header.Set("Authorization", fmt.Sprintf("Discogs key=%s, secret=%s", s.consumerKey, s.consumerSecret))

	// Execute request
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	// Parse JSON
	var searchResp DiscogsSearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Check if we got any results
	if len(searchResp.Results) == 0 {
		return nil, fmt.Errorf("no results found for barcode %s", barcode)
	}

	// Use first result
	result := searchResp.Results[0]

	// Build album data
	albumData := &model.AlbumData{
		Source: "discogs",
	}

	// Extract artist and album from title (format: "Artist - Album")
	if result.Title != "" {
		if strings.Contains(result.Title, " - ") {
			parts := strings.SplitN(result.Title, " - ", 2)
			if len(parts) == 2 {
				artist := strings.TrimSpace(parts[0])
				album := strings.TrimSpace(parts[1])
				albumData.Artist = &artist
				albumData.Album = &album
			}
		} else {
			// If no separator, use the whole title as album
			albumData.Album = &result.Title
		}
	}

	// Year
	if result.Year > 0 {
		albumData.Year = &result.Year
	}

	// Label (use first if multiple)
	if len(result.Label) > 0 {
		albumData.Label = &result.Label[0]
	}

	// Genres - combine genre and style fields, remove duplicates
	var allGenres []string
	allGenres = append(allGenres, result.Genre...)
	allGenres = append(allGenres, result.Style...)

	if len(allGenres) > 0 {
		// Remove duplicates
		seen := make(map[string]bool)
		uniqueGenres := []string{}
		for _, genre := range allGenres {
			if !seen[genre] {
				seen[genre] = true
				uniqueGenres = append(uniqueGenres, genre)
			}
		}
		albumData.Genres = uniqueGenres
	}

	// Cover art
	if result.CoverImage != "" {
		albumData.CoverURL = &result.CoverImage
	}

	return albumData, nil
}
