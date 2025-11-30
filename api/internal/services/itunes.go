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

// ITunesService handles requests to the iTunes Search API
type ITunesService struct {
	client  *http.Client
	baseURL string
}

// NewITunesService creates a new iTunes Search API client
func NewITunesService() *ITunesService {
	return &ITunesService{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		baseURL: "https://itunes.apple.com",
	}
}

// ITunesSearchResponse represents the response from iTunes Search API
type ITunesSearchResponse struct {
	ResultCount int `json:"resultCount"`
	Results     []struct {
		ArtistName         string `json:"artistName"`
		CollectionName     string `json:"collectionName"`
		ReleaseDate        string `json:"releaseDate"` // Format: YYYY-MM-DDTHH:MM:SSZ
		PrimaryGenreName   string `json:"primaryGenreName"`
		ArtworkURL100      string `json:"artworkUrl100"`
		TrackCount         int    `json:"trackCount"`
		CollectionID       int    `json:"collectionId"`
	} `json:"results"`
}

// SearchByBarcode searches iTunes for an album using a barcode (UPC)
// Note: iTunes doesn't directly support barcode search, so we search by term
func (s *ITunesService) SearchByBarcode(ctx context.Context, barcode string) (*model.AlbumData, error) {
	// Build query URL
	params := url.Values{}
	params.Set("term", barcode)
	params.Set("entity", "album")
	params.Set("limit", "5")

	apiURL := fmt.Sprintf("%s/search?%s", s.baseURL, params.Encode())

	// Create request
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

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
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	// Parse JSON
	var searchResp ITunesSearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Check if we got any results
	if searchResp.ResultCount == 0 || len(searchResp.Results) == 0 {
		return nil, fmt.Errorf("no results found for barcode %s", barcode)
	}

	// Use first result
	result := searchResp.Results[0]

	// Build album data
	albumData := &model.AlbumData{
		Source: "itunes",
	}

	if result.ArtistName != "" {
		albumData.Artist = &result.ArtistName
	}

	if result.CollectionName != "" {
		albumData.Album = &result.CollectionName
	}

	// Extract year from release date (format: YYYY-MM-DDTHH:MM:SSZ)
	if result.ReleaseDate != "" {
		yearStr := strings.Split(result.ReleaseDate, "-")[0]
		var year int
		if _, err := fmt.Sscanf(yearStr, "%d", &year); err == nil {
			albumData.Year = &year
		}
	}

	// Genres
	if result.PrimaryGenreName != "" {
		albumData.Genres = []string{result.PrimaryGenreName}
	}

	// Cover art URL - upgrade to higher resolution
	if result.ArtworkURL100 != "" {
		// Replace 100x100 with 600x600 for better quality
		coverURL := strings.ReplaceAll(result.ArtworkURL100, "100x100", "600x600")
		albumData.CoverURL = &coverURL
	}

	return albumData, nil
}
