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
	client       *http.Client
	endpoint     string
	adminSecret  string
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
