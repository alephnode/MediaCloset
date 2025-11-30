package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"mediacloset/api/internal/graph/model"
	"mediacloset/api/internal/ratelimit"
)

// MusicBrainzService handles requests to the MusicBrainz and Cover Art Archive APIs
type MusicBrainzService struct {
	client  *http.Client
	limiter *ratelimit.ServiceLimiter
}

// NewMusicBrainzService creates a new MusicBrainz API client with rate limiting
func NewMusicBrainzService(limiter *ratelimit.ServiceLimiter) *MusicBrainzService {
	return &MusicBrainzService{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		limiter: limiter,
	}
}

// MusicBrainzSearchResponse represents the search response from MusicBrainz API
type MusicBrainzSearchResponse struct {
	Releases []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
		Date  string `json:"date"` // Format: YYYY-MM-DD
	} `json:"releases"`
}

// CoverArtArchiveResponse represents the metadata response from Cover Art Archive
type CoverArtArchiveResponse struct {
	Images []struct {
		Image string   `json:"image"`
		Types []string `json:"types"`
		Front bool     `json:"front"`
	} `json:"images"`
}

// SearchAlbum searches for an album by artist and title, returns album metadata with cover art
func (s *MusicBrainzService) SearchAlbum(ctx context.Context, artist string, album string) (*model.AlbumData, error) {
	// Rate limit - wait for permission (1 req/sec)
	if err := s.limiter.WaitMusicBrainz(ctx); err != nil {
		return nil, fmt.Errorf("rate limit wait failed: %w", err)
	}

	// Step 1: Search for release ID
	releaseID, err := s.searchRelease(ctx, artist, album)
	if err != nil {
		return nil, fmt.Errorf("failed to search release: %w", err)
	}

	// Step 2: Fetch cover art URL
	coverURL, err := s.fetchCoverArtURL(ctx, releaseID)
	if err != nil {
		// Cover art is optional, log but don't fail
		fmt.Printf("Failed to fetch cover art for release %s: %v\n", releaseID, err)
	}

	// Build album data model
	albumData := &model.AlbumData{
		Artist: &artist,
		Album:  &album,
		Source: "musicbrainz",
	}

	if coverURL != nil {
		albumData.CoverURL = coverURL
	}

	return albumData, nil
}

// searchRelease searches MusicBrainz for a release and returns the first match's ID
func (s *MusicBrainzService) searchRelease(ctx context.Context, artist string, album string) (string, error) {
	// Build search query: release:"album" AND artist:"artist"
	query := fmt.Sprintf("release:\"%s\" AND artist:\"%s\"", album, artist)

	// URL encode the query
	params := url.Values{}
	params.Set("query", query)
	params.Set("fmt", "json")

	apiURL := fmt.Sprintf("https://musicbrainz.org/ws/2/release/?%s", params.Encode())

	// Create request
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", "MediaCloset/1.0 (Go API)")

	// Execute request
	resp, err := s.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	// Parse JSON
	var searchResp MusicBrainzSearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return "", fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Check if we got any results
	if len(searchResp.Releases) == 0 {
		return "", fmt.Errorf("no releases found for artist '%s', album '%s'", artist, album)
	}

	// Return first release ID
	return searchResp.Releases[0].ID, nil
}

// fetchCoverArtURL fetches the cover art URL for a given release ID
func (s *MusicBrainzService) fetchCoverArtURL(ctx context.Context, releaseID string) (*string, error) {
	// Try direct front cover URL first
	directURL := fmt.Sprintf("https://coverartarchive.org/release/%s/front", releaseID)

	req, err := http.NewRequestWithContext(ctx, "GET", directURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", "MediaCloset/1.0 (Go API)")

	// Execute request (this will redirect to the actual image)
	resp, err := s.client.Do(req)
	if err == nil && resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		// Get the final URL after redirects
		finalURL := resp.Request.URL.String()
		return &finalURL, nil
	}
	if resp != nil {
		resp.Body.Close()
	}

	// If direct URL failed, try metadata API
	return s.fetchCoverArtFromMetadata(ctx, releaseID)
}

// fetchCoverArtFromMetadata fetches cover art from the metadata endpoint
func (s *MusicBrainzService) fetchCoverArtFromMetadata(ctx context.Context, releaseID string) (*string, error) {
	metadataURL := fmt.Sprintf("https://coverartarchive.org/release/%s", releaseID)

	req, err := http.NewRequestWithContext(ctx, "GET", metadataURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", "MediaCloset/1.0 (Go API)")

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
	var coverResp CoverArtArchiveResponse
	if err := json.Unmarshal(body, &coverResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Find first front cover image
	for _, img := range coverResp.Images {
		if img.Front {
			return &img.Image, nil
		}
	}

	// If no front cover, return first image
	if len(coverResp.Images) > 0 {
		return &coverResp.Images[0].Image, nil
	}

	return nil, fmt.Errorf("no cover art found")
}
