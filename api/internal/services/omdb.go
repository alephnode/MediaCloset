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

// OMDBService handles requests to the OMDB API (Open Movie Database)
type OMDBService struct {
	client  *http.Client
	apiKey  string
	baseURL string
}

// NewOMDBService creates a new OMDB API client
func NewOMDBService(apiKey string) *OMDBService {
	return &OMDBService{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		apiKey:  apiKey,
		baseURL: "https://www.omdbapi.com",
	}
}

// OMDBResponse represents the JSON response from OMDB API
type OMDBResponse struct {
	Title    string `json:"Title"`
	Year     string `json:"Year"`
	Director string `json:"Director"`
	Genre    string `json:"Genre"`
	Plot     string `json:"Plot"`
	Poster   string `json:"Poster"`
	Response string `json:"Response"` // "True" or "False"
	Error    string `json:"Error"`    // Error message if Response is "False"
}

// SearchMovie searches for a movie by title, with optional director and year filters
func (s *OMDBService) SearchMovie(ctx context.Context, title string, director *string, year *int) (*model.MovieData, error) {
	// Build query parameters
	params := url.Values{}
	params.Set("apikey", s.apiKey)
	params.Set("t", title)
	params.Set("plot", "short")

	if year != nil {
		params.Set("y", fmt.Sprintf("%d", *year))
	}

	// Build URL
	apiURL := fmt.Sprintf("%s/?%s", s.baseURL, params.Encode())

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

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	// Parse JSON
	var omdbResp OMDBResponse
	if err := json.Unmarshal(body, &omdbResp); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	// Check for API errors
	if omdbResp.Response == "False" {
		if omdbResp.Error != "" {
			return nil, fmt.Errorf("OMDB API error: %s", omdbResp.Error)
		}
		return nil, fmt.Errorf("OMDB API returned no results")
	}

	// Validate director if provided (simple case-insensitive contains check)
	if director != nil && *director != "" {
		if !strings.Contains(strings.ToLower(omdbResp.Director), strings.ToLower(*director)) &&
			!strings.Contains(strings.ToLower(*director), strings.ToLower(omdbResp.Director)) {
			// Log mismatch but still return result (same behavior as Swift version)
			fmt.Printf("Director mismatch: expected '%s', got '%s'\n", *director, omdbResp.Director)
		}
	}

	// Convert to GraphQL model
	movieData := &model.MovieData{
		Title:  omdbResp.Title,
		Source: "omdb",
	}

	// Parse year (OMDB returns as string, potentially with range like "2001-2003")
	if omdbResp.Year != "" {
		var parsedYear int
		// Try to parse the first 4 digits as year
		if _, err := fmt.Sscanf(omdbResp.Year, "%d", &parsedYear); err == nil {
			movieData.Year = &parsedYear
		}
	}

	// Optional fields
	if omdbResp.Director != "" {
		movieData.Director = &omdbResp.Director
	}
	if omdbResp.Genre != "" {
		movieData.Genre = &omdbResp.Genre
	}
	if omdbResp.Plot != "" {
		movieData.Plot = &omdbResp.Plot
	}
	if omdbResp.Poster != "" && omdbResp.Poster != "N/A" {
		movieData.PosterURL = &omdbResp.Poster
	}

	return movieData, nil
}

// FetchMoviePosterURL is a convenience method that just returns the poster URL
func (s *OMDBService) FetchMoviePosterURL(ctx context.Context, title string, director *string, year *int) (*string, error) {
	movieData, err := s.SearchMovie(ctx, title, director, year)
	if err != nil {
		return nil, err
	}
	return movieData.PosterURL, nil
}
