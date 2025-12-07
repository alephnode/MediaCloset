package services

import (
	"context"
	"crypto/rand"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AuthService handles user authentication with login codes
type AuthService struct {
	hasuraClient *HasuraClient
	emailService *EmailService
	jwtSecret    string
	codeExpiry   time.Duration // Default: 5 minutes
	isDev        bool          // Skip email sending in development
}

// NewAuthService creates a new authentication service
func NewAuthService(hasuraClient *HasuraClient, emailService *EmailService, jwtSecret string, isDev bool) *AuthService {
	return &AuthService{
		hasuraClient: hasuraClient,
		emailService: emailService,
		jwtSecret:    jwtSecret,
		codeExpiry:   5 * time.Minute, // Industry standard: 5-10 minutes
		isDev:        isDev,
	}
}

// User represents a user in the system
type User struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// LoginCode represents a login code request
type LoginCode struct {
	Email     string     `json:"email"`
	Code      string     `json:"code"`
	ExpiresAt time.Time  `json:"expiresAt"`
	UsedAt    *time.Time `json:"usedAt,omitempty"`
}

// Claims represents JWT token claims
type Claims struct {
	UserID string `json:"userId"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

// RequestLoginCode generates a login code for the given email
func (a *AuthService) RequestLoginCode(ctx context.Context, email string) error {
	// Normalize email (lowercase)
	email = normalizeEmail(email)

	// Check if user exists, create if not
	_, err := a.getOrCreateUser(ctx, email)
	if err != nil {
		return fmt.Errorf("failed to get or create user: %w", err)
	}

	// Generate a 6-digit code
	code := generateLoginCode()

	// Calculate expiration time
	expiresAt := time.Now().Add(a.codeExpiry)

	// Store the login code in Hasura
	err = a.storeLoginCode(ctx, email, code, expiresAt)
	if err != nil {
		return fmt.Errorf("failed to store login code: %w", err)
	}

	if a.isDev {
		fmt.Printf("[Auth] Login code for %s: %s (expires in %v)\n", email, code, a.codeExpiry)
	}

	if a.emailService != nil {
		err = a.emailService.SendLoginCode(ctx, email, code)
		if err != nil {
			return fmt.Errorf("failed to send login code email: %w", err)
		}
	} else {
		fmt.Printf("Email service not configured, skipping email send\n")
	}

	return nil
}

// VerifyLoginCode validates a login code and returns a JWT token
func (a *AuthService) VerifyLoginCode(ctx context.Context, email string, code string) (string, *User, error) {
	// Normalize email
	email = normalizeEmail(email)

	// Verify the code
	valid, err := a.verifyLoginCode(ctx, email, code)
	if err != nil {
		return "", nil, fmt.Errorf("failed to verify login code: %w", err)
	}
	if !valid {
		return "", nil, fmt.Errorf("invalid or expired login code")
	}

	// Get user
	user, err := a.getUserByEmail(ctx, email)
	if err != nil {
		return "", nil, fmt.Errorf("failed to get user: %w", err)
	}
	if user == nil {
		return "", nil, fmt.Errorf("user not found")
	}

	// Mark code as used
	err = a.markCodeAsUsed(ctx, email, code)
	if err != nil {
		// Log but don't fail - code is already validated
		fmt.Printf("[Auth] Warning: failed to mark code as used: %v\n", err)
	}

	// Generate JWT token
	token, err := a.generateToken(user.ID, user.Email)
	if err != nil {
		return "", nil, fmt.Errorf("failed to generate token: %w", err)
	}

	return token, user, nil
}

// ValidateToken validates a JWT token and returns the user ID
func (a *AuthService) ValidateToken(tokenString string) (string, string, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Validate signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(a.jwtSecret), nil
	})

	if err != nil {
		return "", "", fmt.Errorf("failed to parse token: %w", err)
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims.UserID, claims.Email, nil
	}

	return "", "", fmt.Errorf("invalid token")
}

// GetUserByID fetches a user by ID
func (a *AuthService) GetUserByID(ctx context.Context, userID string) (*User, error) {
	query := `
		query GetUserByID($id: uuid!) {
			users_by_pk(id: $id) {
				id
				email
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetUserByID",
		Variables: map[string]interface{}{
			"id": userID,
		},
	}

	resp, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	userData, ok := resp.Data["users_by_pk"]
	if !ok || userData == nil {
		return nil, nil // User not found
	}

	userMap, ok := userData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected user data type")
	}

	user := &User{}
	if id, ok := userMap["id"].(string); ok {
		user.ID = id
	}
	if email, ok := userMap["email"].(string); ok {
		user.Email = email
	}
	if createdAt, ok := userMap["created_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			user.CreatedAt = t
		}
	}
	if updatedAt, ok := userMap["updated_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, updatedAt); err == nil {
			user.UpdatedAt = t
		}
	}

	return user, nil
}

// Private helper methods

func (a *AuthService) getOrCreateUser(ctx context.Context, email string) (*User, error) {
	// Try to get existing user
	user, err := a.getUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	if user != nil {
		return user, nil
	}

	// Create new user
	return a.createUser(ctx, email)
}

func (a *AuthService) getUserByEmail(ctx context.Context, email string) (*User, error) {
	query := `
		query GetUserByEmail($email: String!) {
			users(where: {email: {_eq: $email}}, limit: 1) {
				id
				email
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetUserByEmail",
		Variables: map[string]interface{}{
			"email": email,
		},
	}

	resp, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	usersData, ok := resp.Data["users"]
	if !ok {
		return nil, nil
	}

	usersList, ok := usersData.([]interface{})
	if !ok || len(usersList) == 0 {
		return nil, nil
	}

	userMap, ok := usersList[0].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected user data type")
	}

	user := &User{}
	if id, ok := userMap["id"].(string); ok {
		user.ID = id
	}
	if email, ok := userMap["email"].(string); ok {
		user.Email = email
	}
	if createdAt, ok := userMap["created_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			user.CreatedAt = t
		}
	}
	if updatedAt, ok := userMap["updated_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, updatedAt); err == nil {
			user.UpdatedAt = t
		}
	}

	return user, nil
}

func (a *AuthService) createUser(ctx context.Context, email string) (*User, error) {
	query := `
		mutation CreateUser($email: String!) {
			insert_users_one(object: {email: $email}) {
				id
				email
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "CreateUser",
		Variables: map[string]interface{}{
			"email": email,
		},
	}

	resp, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute mutation: %w", err)
	}

	userData, ok := resp.Data["insert_users_one"]
	if !ok || userData == nil {
		return nil, fmt.Errorf("failed to create user")
	}

	userMap, ok := userData.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("unexpected user data type")
	}

	user := &User{}
	if id, ok := userMap["id"].(string); ok {
		user.ID = id
	}
	if email, ok := userMap["email"].(string); ok {
		user.Email = email
	}
	if createdAt, ok := userMap["created_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			user.CreatedAt = t
		}
	}
	if updatedAt, ok := userMap["updated_at"].(string); ok {
		if t, err := time.Parse(time.RFC3339, updatedAt); err == nil {
			user.UpdatedAt = t
		}
	}

	return user, nil
}

func (a *AuthService) storeLoginCode(ctx context.Context, email string, code string, expiresAt time.Time) error {
	query := `
		mutation StoreLoginCode($email: String!, $code: String!, $expires_at: timestamptz!) {
			insert_login_codes_one(object: {
				email: $email
				code: $code
				expires_at: $expires_at
			}) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "StoreLoginCode",
		Variables: map[string]interface{}{
			"email":      email,
			"code":       code,
			"expires_at": expiresAt.Format(time.RFC3339),
		},
	}

	_, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to store login code: %w", err)
	}

	return nil
}

func (a *AuthService) verifyLoginCode(ctx context.Context, email string, code string) (bool, error) {
	query := `
		query VerifyLoginCode($email: String!, $code: String!) {
			login_codes(
				where: {
					email: {_eq: $email}
					code: {_eq: $code}
					expires_at: {_gt: "now()"}
					used_at: {_is_null: true}
				}
				limit: 1
				order_by: {created_at: desc}
			) {
				id
				expires_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "VerifyLoginCode",
		Variables: map[string]interface{}{
			"email": email,
			"code":  code,
		},
	}

	resp, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return false, fmt.Errorf("failed to execute query: %w", err)
	}

	codesData, ok := resp.Data["login_codes"]
	if !ok {
		return false, nil
	}

	codesList, ok := codesData.([]interface{})
	if !ok || len(codesList) == 0 {
		return false, nil
	}

	// Code is valid
	return true, nil
}

func (a *AuthService) markCodeAsUsed(ctx context.Context, email string, code string) error {
	query := `
		mutation MarkCodeAsUsed($email: String!, $code: String!) {
			update_login_codes(
				where: {
					email: {_eq: $email}
					code: {_eq: $code}
				}
				_set: {used_at: "now()"}
			) {
				affected_rows
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "MarkCodeAsUsed",
		Variables: map[string]interface{}{
			"email": email,
			"code":  code,
		},
	}

	_, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to mark code as used: %w", err)
	}

	return nil
}

func (a *AuthService) generateToken(userID string, email string) (string, error) {
	expirationTime := time.Now().Add(24 * time.Hour) // Token expires in 24 hours

	claims := &Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "mediacloset",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(a.jwtSecret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// Helper functions

func generateLoginCode() string {
	// Generate a 6-digit code (000000-999999)
	// Use crypto/rand for secure random number generation
	bytes := make([]byte, 4)
	rand.Read(bytes)
	// Convert bytes to a number and take modulo 1000000
	codeNum := uint32(bytes[0])<<24 | uint32(bytes[1])<<16 | uint32(bytes[2])<<8 | uint32(bytes[3])
	return fmt.Sprintf("%06d", codeNum%1000000)
}

func normalizeEmail(email string) string {
	// Simple normalization: lowercase and trim
	// In production, you might want more sophisticated email validation
	email = strings.ToLower(email)
	email = strings.TrimSpace(email)
	return email
}
