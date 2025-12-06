package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// HasuraClient handles requests to Hasura GraphQL API
type HasuraClient struct {
	client      *http.Client
	endpoint    string
	adminSecret string
}

// NewHasuraClient creates a new Hasura client
func NewHasuraClient(endpoint, adminSecret string) *HasuraClient {
	return &HasuraClient{
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		endpoint:    endpoint,
		adminSecret: adminSecret,
	}
}

// GraphQLRequest represents a GraphQL request body
type GraphQLRequest struct {
	Query         string                 `json:"query"`
	OperationName string                 `json:"operationName,omitempty"`
	Variables     map[string]interface{} `json:"variables,omitempty"`
}

// GraphQLResponse represents a GraphQL response
type GraphQLResponse struct {
	Data   map[string]interface{}   `json:"data,omitempty"`
	Errors []map[string]interface{} `json:"errors,omitempty"`
}

// Execute executes a GraphQL query/mutation against Hasura
func (h *HasuraClient) Execute(ctx context.Context, req GraphQLRequest) (*GraphQLResponse, error) {
	// Marshal request to JSON
	reqBody, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create HTTP request
	httpReq, err := http.NewRequestWithContext(ctx, "POST", h.endpoint, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Add headers
	httpReq.Header.Set("Content-Type", "application/json")
	if h.adminSecret != "" {
		httpReq.Header.Set("x-hasura-admin-secret", h.adminSecret)
	}

	// Execute request
	resp, err := h.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	// Read response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(respBody))
	}

	// Parse response
	var graphQLResp GraphQLResponse
	if err := json.Unmarshal(respBody, &graphQLResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	// Check for GraphQL errors
	if len(graphQLResp.Errors) > 0 {
		return &graphQLResp, fmt.Errorf("GraphQL errors: %v", graphQLResp.Errors)
	}

	return &graphQLResp, nil
}

// InsertVHS inserts a new VHS record into Hasura
func (h *HasuraClient) InsertVHS(ctx context.Context, vhs map[string]interface{}) (string, error) {
	query := `
		mutation InsertVHS($object: vhs_insert_input!) {
			insert_vhs_one(object: $object) {
				id
				title
				director
				year
				genre
				cover_url
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "InsertVHS",
		Variables: map[string]interface{}{
			"object": vhs,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return "", err
	}

	// Extract the inserted VHS ID
	if insertData, ok := resp.Data["insert_vhs_one"].(map[string]interface{}); ok {
		if id, ok := insertData["id"].(string); ok {
			return id, nil
		}
	}

	return "", fmt.Errorf("failed to extract VHS ID from response")
}

// InsertRecord inserts a new record into Hasura
func (h *HasuraClient) InsertRecord(ctx context.Context, record map[string]interface{}) (string, error) {
	query := `
		mutation InsertRecord($object: records_insert_input!) {
			insert_records_one(object: $object) {
				id
				artist
				album
				year
				label
				color_variants
				genres
				cover_url
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "InsertRecord",
		Variables: map[string]interface{}{
			"object": record,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return "", err
	}

	// Extract the inserted record ID
	if insertData, ok := resp.Data["insert_records_one"].(map[string]interface{}); ok {
		if id, ok := insertData["id"].(string); ok {
			return id, nil
		}
	}

	return "", fmt.Errorf("failed to extract record ID from response")
}

// GetAllMovies fetches all VHS movies from Hasura
func (h *HasuraClient) GetAllMovies(ctx context.Context) ([]map[string]interface{}, error) {
	query := `
		query GetAllMovies {
			vhs(order_by: {created_at: desc}) {
				id
				title
				director
				year
				genre
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetAllMovies",
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract vhs array from response
	vhsData, ok := resp.Data["vhs"]
	if !ok {
		return []map[string]interface{}{}, nil // No movies found
	}

	vhsList, ok := vhsData.([]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected vhs data type")
	}

	// Convert to []map[string]interface{}
	movies := make([]map[string]interface{}, 0, len(vhsList))
	for _, v := range vhsList {
		if movie, ok := v.(map[string]interface{}); ok {
			movies = append(movies, movie)
		}
	}

	return movies, nil
}

// GetAllAlbums fetches all records/albums from Hasura
func (h *HasuraClient) GetAllAlbums(ctx context.Context) ([]map[string]interface{}, error) {
	query := `
		query GetAllAlbums {
			records(order_by: {created_at: desc}) {
				id
				artist
				album
				year
				label
				color_variants
				genres
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetAllAlbums",
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract records array from response
	recordsData, ok := resp.Data["records"]
	if !ok {
		return []map[string]interface{}{}, nil // No albums found
	}

	recordsList, ok := recordsData.([]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected records data type")
	}

	// Convert to []map[string]interface{}
	albums := make([]map[string]interface{}, 0, len(recordsList))
	for _, r := range recordsList {
		if album, ok := r.(map[string]interface{}); ok {
			albums = append(albums, album)
		}
	}

	return albums, nil
}

// GetMovieByID fetches a single movie by ID from Hasura
func (h *HasuraClient) GetMovieByID(ctx context.Context, id string) (map[string]interface{}, error) {
	query := `
		query GetMovieByID($id: uuid!) {
			vhs_by_pk(id: $id) {
				id
				title
				director
				year
				genre
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetMovieByID",
		Variables: map[string]interface{}{
			"id": id,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract vhs_by_pk from response
	movieData, ok := resp.Data["vhs_by_pk"]
	if !ok || movieData == nil {
		return nil, nil // Movie not found
	}

	movie, ok := movieData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected movie data type")
	}

	return movie, nil
}

// GetAlbumByID fetches a single album by ID from Hasura
func (h *HasuraClient) GetAlbumByID(ctx context.Context, id string) (map[string]interface{}, error) {
	query := `
		query GetAlbumByID($id: uuid!) {
			records_by_pk(id: $id) {
				id
				artist
				album
				year
				label
				color_variants
				genres
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetAlbumByID",
		Variables: map[string]interface{}{
			"id": id,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract records_by_pk from response
	albumData, ok := resp.Data["records_by_pk"]
	if !ok || albumData == nil {
		return nil, nil // Album not found
	}

	album, ok := albumData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected album data type")
	}

	return album, nil
}

// UpdateMovie updates an existing movie in Hasura
func (h *HasuraClient) UpdateMovie(ctx context.Context, id string, updates map[string]interface{}) (map[string]interface{}, error) {
	query := `
		mutation UpdateMovie($id: uuid!, $updates: vhs_set_input!) {
			update_vhs_by_pk(pk_columns: {id: $id}, _set: $updates) {
				id
				title
				director
				year
				genre
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "UpdateMovie",
		Variables: map[string]interface{}{
			"id":      id,
			"updates": updates,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute mutation: %w", err)
	}

	// Extract update_vhs_by_pk from response
	movieData, ok := resp.Data["update_vhs_by_pk"]
	if !ok || movieData == nil {
		return nil, fmt.Errorf("movie not found or update failed")
	}

	movie, ok := movieData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected movie data type")
	}

	return movie, nil
}

// UpdateAlbum updates an existing album in Hasura
func (h *HasuraClient) UpdateAlbum(ctx context.Context, id string, updates map[string]interface{}) (map[string]interface{}, error) {
	query := `
		mutation UpdateAlbum($id: uuid!, $updates: records_set_input!) {
			update_records_by_pk(pk_columns: {id: $id}, _set: $updates) {
				id
				artist
				album
				year
				label
				color_variants
				genres
				cover_url
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "UpdateAlbum",
		Variables: map[string]interface{}{
			"id":      id,
			"updates": updates,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute mutation: %w", err)
	}

	// Extract update_records_by_pk from response
	albumData, ok := resp.Data["update_records_by_pk"]
	if !ok || albumData == nil {
		return nil, fmt.Errorf("album not found or update failed")
	}

	album, ok := albumData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected album data type")
	}

	return album, nil
}

// DeleteMovie deletes a movie from Hasura
func (h *HasuraClient) DeleteMovie(ctx context.Context, id string) error {
	query := `
		mutation DeleteMovie($id: uuid!) {
			delete_vhs_by_pk(id: $id) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "DeleteMovie",
		Variables: map[string]interface{}{
			"id": id,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to execute mutation: %w", err)
	}

	// Check if deletion was successful
	deleteData, ok := resp.Data["delete_vhs_by_pk"]
	if !ok || deleteData == nil {
		return fmt.Errorf("movie not found or delete failed")
	}

	return nil
}

// DeleteAlbum deletes an album from Hasura
func (h *HasuraClient) DeleteAlbum(ctx context.Context, id string) error {
	query := `
		mutation DeleteAlbum($id: uuid!) {
			delete_records_by_pk(id: $id) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "DeleteAlbum",
		Variables: map[string]interface{}{
			"id": id,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to execute mutation: %w", err)
	}

	// Check if deletion was successful
	deleteData, ok := resp.Data["delete_records_by_pk"]
	if !ok || deleteData == nil {
		return fmt.Errorf("album not found or delete failed")
	}

	return nil
}
