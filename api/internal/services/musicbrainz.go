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
	client          *http.Client
	limiter         *ratelimit.ServiceLimiter
	baseURL         string
	coverArtBaseURL string
}

// NewMusicBrainzService creates a new MusicBrainz API client with rate limiting
func NewMusicBrainzService(limiter *ratelimit.ServiceLimiter) *MusicBrainzService {
	return &MusicBrainzService{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		limiter:         limiter,
		baseURL:         "https://musicbrainz.org",
		coverArtBaseURL: "https://coverartarchive.org",
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

// MusicBrainzBarcodeSearchResponse represents the response for barcode lookups
type MusicBrainzBarcodeSearchResponse struct {
	Releases []struct {
		ID           string `json:"id"`
		Title        string `json:"title"`
		Date         string `json:"date"`
		Country      string `json:"country"`
		Barcode      string `json:"barcode"`
		ArtistCredit []struct {
			Artist struct {
				Name string `json:"name"`
			} `json:"artist"`
		} `json:"artist-credit"`
		LabelInfo []struct {
			Label struct {
				Name string `json:"name"`
			} `json:"label"`
		} `json:"label-info"`
	} `json:"releases"`
}

// SearchByBarcode searches MusicBrainz releases by barcode and returns album metadata
func (s *MusicBrainzService) SearchByBarcode(ctx context.Context, barcode string) (*model.AlbumData, error) {
	if err := s.limiter.WaitMusicBrainz(ctx); err != nil {
		return nil, fmt.Errorf("rate limit wait failed: %w", err)
	}

	params := url.Values{}
	params.Set("query", fmt.Sprintf("barcode:%s", barcode))
	params.Set("fmt", "json")
	params.Set("inc", "artists+labels+recordings")

	apiURL := fmt.Sprintf("%s/ws/2/release/?%s", s.baseURL, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", "MediaCloset/1.0 (Go API)")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	var searchResp MusicBrainzBarcodeSearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	if len(searchResp.Releases) == 0 {
		return nil, fmt.Errorf("no releases found for barcode '%s'", barcode)
	}

	release := searchResp.Releases[0]

	var artist *string
	if len(release.ArtistCredit) > 0 {
		if name := release.ArtistCredit[0].Artist.Name; name != "" {
			artist = &name
		}
	}

	var label *string
	if len(release.LabelInfo) > 0 {
		if name := release.LabelInfo[0].Label.Name; name != "" {
			label = &name
		}
	}

	var year *int
	if len(release.Date) >= 4 {
		var parsedYear int
		if _, err := fmt.Sscanf(release.Date[:4], "%d", &parsedYear); err == nil {
			year = &parsedYear
		}
	}

	var albumTitle *string
	if release.Title != "" {
		albumTitle = &release.Title
	}

	// Try to fetch cover art from multiple releases until we find one
	var coverURL *string
	if len(searchResp.Releases) > 0 {
		var lastErr error
		for _, rel := range searchResp.Releases {
			if rel.ID == "" {
				continue
			}
			url, err := s.fetchCoverArtURL(ctx, rel.ID)
			if err == nil && url != nil {
				coverURL = url
				break
			}
			lastErr = err
		}
		if coverURL == nil && lastErr != nil {
			fmt.Printf("Failed to fetch cover art for barcode releases (tried %d): %v\n", len(searchResp.Releases), lastErr)
		}
	}

	albumData := &model.AlbumData{
		Artist:   artist,
		Album:    albumTitle,
		Year:     year,
		Label:    label,
		CoverURL: coverURL,
		Source:   "musicbrainz",
	}

	return albumData, nil
}

// SearchAlbum searches for an album by artist and title, returns album metadata with cover art
func (s *MusicBrainzService) SearchAlbum(ctx context.Context, artist string, album string) (*model.AlbumData, error) {
	// Rate limit - wait for permission (1 req/sec)
	if err := s.limiter.WaitMusicBrainz(ctx); err != nil {
		return nil, fmt.Errorf("rate limit wait failed: %w", err)
	}

	// Step 1: Search for releases
	releaseIDs, err := s.searchReleases(ctx, artist, album)
	if err != nil {
		return nil, fmt.Errorf("failed to search releases: %w", err)
	}

	// Step 2: Try to fetch cover art URL from multiple releases until we find one
	var coverURL *string
	var lastErr error
	for _, releaseID := range releaseIDs {
		url, err := s.fetchCoverArtURL(ctx, releaseID)
		if err == nil && url != nil {
			coverURL = url
			break
		}
		lastErr = err
	}

	if coverURL == nil && lastErr != nil {
		// Cover art is optional, log but don't fail
		fmt.Printf("Failed to fetch cover art for releases (tried %d): %v\n", len(releaseIDs), lastErr)
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

// searchReleases searches MusicBrainz for releases and returns all matching release IDs
func (s *MusicBrainzService) searchReleases(ctx context.Context, artist string, album string) ([]string, error) {
	// Build search query: release:"album" AND artist:"artist"
	query := fmt.Sprintf("release:\"%s\" AND artist:\"%s\"", album, artist)

	// URL encode the query
	params := url.Values{}
	params.Set("query", query)
	params.Set("fmt", "json")
	// Limit to first 10 releases to avoid too many API calls
	params.Set("limit", "10")

	apiURL := fmt.Sprintf("%s/ws/2/release/?%s", s.baseURL, params.Encode())

	// Create request
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
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
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	// Parse JSON
	var searchResp MusicBrainzSearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Check if we got any results
	if len(searchResp.Releases) == 0 {
		return nil, fmt.Errorf("no releases found for artist '%s', album '%s'", artist, album)
	}

	// Return all release IDs
	releaseIDs := make([]string, 0, len(searchResp.Releases))
	for _, release := range searchResp.Releases {
		releaseIDs = append(releaseIDs, release.ID)
	}
	return releaseIDs, nil
}

// fetchCoverArtURL fetches the cover art URL for a given release ID
func (s *MusicBrainzService) fetchCoverArtURL(ctx context.Context, releaseID string) (*string, error) {
	// Try direct front cover URL first
	directURL := fmt.Sprintf("%s/release/%s/front", s.coverArtBaseURL, releaseID)

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
	metadataURL := fmt.Sprintf("%s/release/%s", s.coverArtBaseURL, releaseID)

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
