package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
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

// GetMoviesByUserID fetches all VHS movies for a specific user (via junction table)
func (h *HasuraClient) GetMoviesByUserID(ctx context.Context, userID string) ([]map[string]interface{}, error) {
	query := `
		query GetMoviesByUserID($user_id: uuid!) {
			user_vhs(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
				vhs {
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
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetMoviesByUserID",
		Variables: map[string]interface{}{
			"user_id": userID,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract user_vhs array from response
	userVHSData, ok := resp.Data["user_vhs"]
	if !ok {
		return []map[string]interface{}{}, nil // No movies found
	}

	userVHSList, ok := userVHSData.([]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected user_vhs data type")
	}

	// Extract vhs objects from user_vhs entries
	movies := make([]map[string]interface{}, 0, len(userVHSList))
	for _, entry := range userVHSList {
		if entryMap, ok := entry.(map[string]interface{}); ok {
			if vhs, ok := entryMap["vhs"].(map[string]interface{}); ok {
				movies = append(movies, vhs)
			}
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

// GetAlbumsByUserID fetches all albums for a specific user (via junction table)
func (h *HasuraClient) GetAlbumsByUserID(ctx context.Context, userID string) ([]map[string]interface{}, error) {
	query := `
		query GetAlbumsByUserID($user_id: uuid!) {
			user_records(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
				record {
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
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetAlbumsByUserID",
		Variables: map[string]interface{}{
			"user_id": userID,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	// Extract user_records array from response
	userRecordsData, ok := resp.Data["user_records"]
	if !ok {
		return []map[string]interface{}{}, nil // No albums found
	}

	userRecordsList, ok := userRecordsData.([]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected user_records data type")
	}

	// Extract record objects from user_records entries
	albums := make([]map[string]interface{}, 0, len(userRecordsList))
	for _, entry := range userRecordsList {
		if entryMap, ok := entry.(map[string]interface{}); ok {
			if record, ok := entryMap["record"].(map[string]interface{}); ok {
				albums = append(albums, record)
			}
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

// FindMovieByTitle searches for an existing movie by title, director, and year
func (h *HasuraClient) FindMovieByTitle(ctx context.Context, title string, director *string, year *int) (map[string]interface{}, error) {
	// Build where clause
	whereParts := []string{fmt.Sprintf(`title: {_eq: "%s"}`, title)}
	if director != nil && *director != "" {
		whereParts = append(whereParts, fmt.Sprintf(`director: {_eq: "%s"}`, *director))
	}
	if year != nil {
		whereParts = append(whereParts, fmt.Sprintf(`year: {_eq: %d}`, *year))
	}
	whereClause := strings.Join(whereParts, ", ")

	query := fmt.Sprintf(`
		query FindMovieByTitle {
			vhs(where: {%s}, limit: 1) {
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
	`, whereClause)

	req := GraphQLRequest{
		Query:         query,
		OperationName: "FindMovieByTitle",
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	vhsData, ok := resp.Data["vhs"]
	if !ok {
		return nil, nil // Movie not found
	}

	vhsList, ok := vhsData.([]interface{})
	if !ok || len(vhsList) == 0 {
		return nil, nil // Movie not found
	}

	if movie, ok := vhsList[0].(map[string]interface{}); ok {
		return movie, nil
	}

	return nil, nil
}

// FindRecordByArtistAlbum searches for an existing record by artist and album
func (h *HasuraClient) FindRecordByArtistAlbum(ctx context.Context, artist string, album string) (map[string]interface{}, error) {
	query := fmt.Sprintf(`
		query FindRecordByArtistAlbum {
			records(where: {artist: {_eq: "%s"}, album: {_eq: "%s"}}, limit: 1) {
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
	`, artist, album)

	req := GraphQLRequest{
		Query:         query,
		OperationName: "FindRecordByArtistAlbum",
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	recordsData, ok := resp.Data["records"]
	if !ok {
		return nil, nil // Record not found
	}

	recordsList, ok := recordsData.([]interface{})
	if !ok || len(recordsList) == 0 {
		return nil, nil // Record not found
	}

	if record, ok := recordsList[0].(map[string]interface{}); ok {
		return record, nil
	}

	return nil, nil
}

// LinkMovieToUser adds a movie to a user's collection via junction table
func (h *HasuraClient) LinkMovieToUser(ctx context.Context, userID string, vhsID string) error {
	query := `
		mutation LinkMovieToUser($user_id: uuid!, $vhs_id: uuid!) {
			insert_user_vhs_one(object: {
				user_id: $user_id
				vhs_id: $vhs_id
			}) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "LinkMovieToUser",
		Variables: map[string]interface{}{
			"user_id": userID,
			"vhs_id":  vhsID,
		},
	}

	_, err := h.Execute(ctx, req)
	if err != nil {
		// Check if it's a duplicate key error (user already has this movie)
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			return nil // Already linked, not an error
		}
		return fmt.Errorf("failed to link movie to user: %w", err)
	}

	return nil
}

// LinkRecordToUser adds a record to a user's collection via junction table
func (h *HasuraClient) LinkRecordToUser(ctx context.Context, userID string, recordID string) error {
	query := `
		mutation LinkRecordToUser($user_id: uuid!, $record_id: uuid!) {
			insert_user_records_one(object: {
				user_id: $user_id
				record_id: $record_id
			}) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "LinkRecordToUser",
		Variables: map[string]interface{}{
			"user_id":   userID,
			"record_id": recordID,
		},
	}

	_, err := h.Execute(ctx, req)
	if err != nil {
		// Check if it's a duplicate key error (user already has this record)
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			return nil // Already linked, not an error
		}
		return fmt.Errorf("failed to link record to user: %w", err)
	}

	return nil
}

// CheckMovieOwnership checks if a user has a movie in their collection
func (h *HasuraClient) CheckMovieOwnership(ctx context.Context, userID string, vhsID string) (bool, error) {
	query := `
		query CheckMovieOwnership($user_id: uuid!, $vhs_id: uuid!) {
			user_vhs(where: {user_id: {_eq: $user_id}, vhs_id: {_eq: $vhs_id}}, limit: 1) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "CheckMovieOwnership",
		Variables: map[string]interface{}{
			"user_id": userID,
			"vhs_id":  vhsID,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return false, fmt.Errorf("failed to execute query: %w", err)
	}

	userVHSData, ok := resp.Data["user_vhs"]
	if !ok {
		return false, nil
	}

	userVHSList, ok := userVHSData.([]interface{})
	if !ok || len(userVHSList) == 0 {
		return false, nil
	}

	return true, nil
}

// CheckRecordOwnership checks if a user has a record in their collection
func (h *HasuraClient) CheckRecordOwnership(ctx context.Context, userID string, recordID string) (bool, error) {
	query := `
		query CheckRecordOwnership($user_id: uuid!, $record_id: uuid!) {
			user_records(where: {user_id: {_eq: $user_id}, record_id: {_eq: $record_id}}, limit: 1) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "CheckRecordOwnership",
		Variables: map[string]interface{}{
			"user_id":   userID,
			"record_id": recordID,
		},
	}

	resp, err := h.Execute(ctx, req)
	if err != nil {
		return false, fmt.Errorf("failed to execute query: %w", err)
	}

	userRecordsData, ok := resp.Data["user_records"]
	if !ok {
		return false, nil
	}

	userRecordsList, ok := userRecordsData.([]interface{})
	if !ok || len(userRecordsList) == 0 {
		return false, nil
	}

	return true, nil
}

// UnlinkMovieFromUser removes a movie from a user's collection
func (h *HasuraClient) UnlinkMovieFromUser(ctx context.Context, userID string, vhsID string) error {
	query := `
		mutation UnlinkMovieFromUser($user_id: uuid!, $vhs_id: uuid!) {
			delete_user_vhs(where: {user_id: {_eq: $user_id}, vhs_id: {_eq: $vhs_id}}) {
				affected_rows
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "UnlinkMovieFromUser",
		Variables: map[string]interface{}{
			"user_id": userID,
			"vhs_id":  vhsID,
		},
	}

	_, err := h.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to unlink movie from user: %w", err)
	}

	return nil
}

// UnlinkRecordFromUser removes a record from a user's collection
func (h *HasuraClient) UnlinkRecordFromUser(ctx context.Context, userID string, recordID string) error {
	query := `
		mutation UnlinkRecordFromUser($user_id: uuid!, $record_id: uuid!) {
			delete_user_records(where: {user_id: {_eq: $user_id}, record_id: {_eq: $record_id}}) {
				affected_rows
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "UnlinkRecordFromUser",
		Variables: map[string]interface{}{
			"user_id":   userID,
			"record_id": recordID,
		},
	}

	_, err := h.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to unlink record from user: %w", err)
	}

	return nil
}
