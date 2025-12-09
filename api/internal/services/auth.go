package services

import (
	"context"
	"crypto/rand"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AuthService handles user authentication with login codes
type AuthService struct {
	hasuraClient       *HasuraClient
	emailService       *EmailService
	textMessageService *TextMessageService
	jwtSecret          string
	codeExpiry         time.Duration // Default: 5 minutes
	isDev              bool          // Skip email/SMS sending in development
}

// NewAuthService creates a new authentication service
func NewAuthService(hasuraClient *HasuraClient, emailService *EmailService, textMessageService *TextMessageService, jwtSecret string, isDev bool) *AuthService {
	return &AuthService{
		hasuraClient:       hasuraClient,
		emailService:       emailService,
		textMessageService: textMessageService,
		jwtSecret:          jwtSecret,
		codeExpiry:         5 * time.Minute, // Industry standard: 5-10 minutes
		isDev:              isDev,
	}
}

// User represents a user in the system
type User struct {
	ID          string    `json:"id"`
	Email       string    `json:"email"`
	PhoneNumber *string   `json:"phoneNumber,omitempty"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// LoginCode represents a login code request
type LoginCode struct {
	Email       string     `json:"email,omitempty"`
	PhoneNumber string     `json:"phoneNumber,omitempty"`
	Code        string     `json:"code"`
	ExpiresAt   time.Time  `json:"expiresAt"`
	UsedAt      *time.Time `json:"usedAt,omitempty"`
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
	_, err := a.getOrCreateUserByEmail(ctx, email)
	if err != nil {
		return fmt.Errorf("failed to get or create user: %w", err)
	}

	// Generate a 6-digit code
	code := generateLoginCode()

	// Calculate expiration time
	expiresAt := time.Now().Add(a.codeExpiry)

	// Store the login code in Hasura
	err = a.storeLoginCodeByEmail(ctx, email, code, expiresAt)
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

// RequestLoginCodeByPhone generates a login code for the given phone number
func (a *AuthService) RequestLoginCodeByPhone(ctx context.Context, phoneNumber string) error {
	// Normalize phone number (E.164 format)
	phoneNumber = normalizePhoneNumber(phoneNumber)

	if !isValidPhoneNumber(phoneNumber) {
		return fmt.Errorf("invalid phone number format, expected E.164 format (e.g., +15551234567)")
	}

	// Check if user exists by phone, create if not
	_, err := a.getOrCreateUserByPhone(ctx, phoneNumber)
	if err != nil {
		return fmt.Errorf("failed to get or create user: %w", err)
	}

	// Generate a 6-digit code
	code := generateLoginCode()

	// Calculate expiration time
	expiresAt := time.Now().Add(a.codeExpiry)

	// Store the login code in Hasura
	err = a.storeLoginCodeByPhone(ctx, phoneNumber, code, expiresAt)
	if err != nil {
		return fmt.Errorf("failed to store login code: %w", err)
	}

	if a.isDev {
		fmt.Printf("[Auth] Login code for %s: %s (expires in %v)\n", phoneNumber, code, a.codeExpiry)
	}

	if a.textMessageService != nil {
		err = a.textMessageService.SendLoginCode(ctx, phoneNumber, code)
		if err != nil {
			return fmt.Errorf("failed to send login code SMS: %w", err)
		}
	} else {
		fmt.Printf("Text message service not configured, skipping SMS send\n")
	}

	return nil
}

// VerifyLoginCode validates a login code and returns a JWT token
func (a *AuthService) VerifyLoginCode(ctx context.Context, email string, code string) (string, *User, error) {
	// Normalize email
	email = normalizeEmail(email)

	// Verify the code
	valid, err := a.verifyLoginCodeByEmail(ctx, email, code)
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
	err = a.markCodeAsUsedByEmail(ctx, email, code)
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

// VerifyLoginCodeByPhone validates a login code sent via SMS and returns a JWT token
func (a *AuthService) VerifyLoginCodeByPhone(ctx context.Context, phoneNumber string, code string) (string, *User, error) {
	// Normalize phone number
	phoneNumber = normalizePhoneNumber(phoneNumber)

	// Verify the code
	valid, err := a.verifyLoginCodeByPhone(ctx, phoneNumber, code)
	if err != nil {
		return "", nil, fmt.Errorf("failed to verify login code: %w", err)
	}
	if !valid {
		return "", nil, fmt.Errorf("invalid or expired login code")
	}

	// Get user
	user, err := a.getUserByPhone(ctx, phoneNumber)
	if err != nil {
		return "", nil, fmt.Errorf("failed to get user: %w", err)
	}
	if user == nil {
		return "", nil, fmt.Errorf("user not found")
	}

	// Mark code as used
	err = a.markCodeAsUsedByPhone(ctx, phoneNumber, code)
	if err != nil {
		// Log but don't fail - code is already validated
		fmt.Printf("[Auth] Warning: failed to mark code as used: %v\n", err)
	}

	// Generate JWT token - use email if available, otherwise use phone as identifier
	email := ""
	if user.Email != "" {
		email = user.Email
	} else if user.PhoneNumber != nil {
		email = *user.PhoneNumber // Use phone as fallback identifier
	}

	token, err := a.generateToken(user.ID, email)
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
				phone_number
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

	return parseUserFromMap(userData)
}

// Private helper methods

func (a *AuthService) getOrCreateUserByEmail(ctx context.Context, email string) (*User, error) {
	// Try to get existing user
	user, err := a.getUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	if user != nil {
		return user, nil
	}

	// Create new user with email
	return a.createUserWithEmail(ctx, email)
}

func (a *AuthService) getOrCreateUserByPhone(ctx context.Context, phoneNumber string) (*User, error) {
	// Try to get existing user by phone
	user, err := a.getUserByPhone(ctx, phoneNumber)
	if err != nil {
		return nil, err
	}
	if user != nil {
		return user, nil
	}

	// Create new user with phone number
	return a.createUserWithPhone(ctx, phoneNumber)
}

func (a *AuthService) getUserByEmail(ctx context.Context, email string) (*User, error) {
	query := `
		query GetUserByEmail($email: String!) {
			users(where: {email: {_eq: $email}}, limit: 1) {
				id
				email
				phone_number
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

	return parseUserFromMap(usersList[0])
}

func (a *AuthService) getUserByPhone(ctx context.Context, phoneNumber string) (*User, error) {
	query := `
		query GetUserByPhone($phone_number: String!) {
			users(where: {phone_number: {_eq: $phone_number}}, limit: 1) {
				id
				email
				phone_number
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "GetUserByPhone",
		Variables: map[string]interface{}{
			"phone_number": phoneNumber,
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

	return parseUserFromMap(usersList[0])
}

func (a *AuthService) createUserWithEmail(ctx context.Context, email string) (*User, error) {
	query := `
		mutation CreateUserWithEmail($email: String!) {
			insert_users_one(object: {email: $email}) {
				id
				email
				phone_number
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "CreateUserWithEmail",
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

	return parseUserFromMap(userData)
}

func (a *AuthService) createUserWithPhone(ctx context.Context, phoneNumber string) (*User, error) {
	query := `
		mutation CreateUserWithPhone($phone_number: String!) {
			insert_users_one(object: {phone_number: $phone_number}) {
				id
				email
				phone_number
				created_at
				updated_at
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "CreateUserWithPhone",
		Variables: map[string]interface{}{
			"phone_number": phoneNumber,
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

	return parseUserFromMap(userData)
}

func (a *AuthService) storeLoginCodeByEmail(ctx context.Context, email string, code string, expiresAt time.Time) error {
	query := `
		mutation StoreLoginCodeByEmail($email: String!, $code: String!, $expires_at: timestamptz!) {
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
		OperationName: "StoreLoginCodeByEmail",
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

func (a *AuthService) storeLoginCodeByPhone(ctx context.Context, phoneNumber string, code string, expiresAt time.Time) error {
	query := `
		mutation StoreLoginCodeByPhone($phone_number: String!, $code: String!, $expires_at: timestamptz!) {
			insert_login_codes_one(object: {
				phone_number: $phone_number
				code: $code
				expires_at: $expires_at
			}) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "StoreLoginCodeByPhone",
		Variables: map[string]interface{}{
			"phone_number": phoneNumber,
			"code":         code,
			"expires_at":   expiresAt.Format(time.RFC3339),
		},
	}

	_, err := a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to store login code: %w", err)
	}

	return nil
}

func (a *AuthService) verifyLoginCodeByEmail(ctx context.Context, email string, code string) (bool, error) {
	query := `
		query VerifyLoginCodeByEmail($email: String!, $code: String!) {
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
		OperationName: "VerifyLoginCodeByEmail",
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

func (a *AuthService) verifyLoginCodeByPhone(ctx context.Context, phoneNumber string, code string) (bool, error) {
	query := `
		query VerifyLoginCodeByPhone($phone_number: String!, $code: String!) {
			login_codes(
				where: {
					phone_number: {_eq: $phone_number}
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
		OperationName: "VerifyLoginCodeByPhone",
		Variables: map[string]interface{}{
			"phone_number": phoneNumber,
			"code":         code,
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

func (a *AuthService) markCodeAsUsedByEmail(ctx context.Context, email string, code string) error {
	query := `
		mutation MarkCodeAsUsedByEmail($email: String!, $code: String!) {
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
		OperationName: "MarkCodeAsUsedByEmail",
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

func (a *AuthService) markCodeAsUsedByPhone(ctx context.Context, phoneNumber string, code string) error {
	query := `
		mutation MarkCodeAsUsedByPhone($phone_number: String!, $code: String!) {
			update_login_codes(
				where: {
					phone_number: {_eq: $phone_number}
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
		OperationName: "MarkCodeAsUsedByPhone",
		Variables: map[string]interface{}{
			"phone_number": phoneNumber,
			"code":         code,
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

func normalizePhoneNumber(phoneNumber string) string {
	// Remove all non-digit characters except leading +
	phoneNumber = strings.TrimSpace(phoneNumber)

	// Keep the leading + if present, then only digits
	hasPlus := strings.HasPrefix(phoneNumber, "+")

	// Remove all non-digits
	digitsOnly := regexp.MustCompile(`\D`).ReplaceAllString(phoneNumber, "")

	// Add back the + if it was there
	if hasPlus {
		return "+" + digitsOnly
	}

	// If no + but starts with country code, add it
	// Assume US/Canada if 10 digits without country code
	if len(digitsOnly) == 10 {
		return "+1" + digitsOnly
	}

	// Otherwise return with + prefix
	return "+" + digitsOnly
}

func isValidPhoneNumber(phoneNumber string) bool {
	// E.164 format: + followed by 10-15 digits
	// Examples: +15551234567, +447911123456
	e164Regex := regexp.MustCompile(`^\+[1-9]\d{9,14}$`)
	return e164Regex.MatchString(phoneNumber)
}

// parseUserFromMap extracts a User from a map[string]interface{}
func parseUserFromMap(data interface{}) (*User, error) {
	userMap, ok := data.(map[string]interface{})
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
	if phoneNumber, ok := userMap["phone_number"].(string); ok {
		user.PhoneNumber = &phoneNumber
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

// LinkPhoneToUser links a phone number to an existing user account
func (a *AuthService) LinkPhoneToUser(ctx context.Context, userID string, phoneNumber string) error {
	phoneNumber = normalizePhoneNumber(phoneNumber)

	if !isValidPhoneNumber(phoneNumber) {
		return fmt.Errorf("invalid phone number format")
	}

	// Check if phone number is already in use
	existingUser, err := a.getUserByPhone(ctx, phoneNumber)
	if err != nil {
		return fmt.Errorf("failed to check existing phone: %w", err)
	}
	if existingUser != nil && existingUser.ID != userID {
		return fmt.Errorf("phone number already in use by another account")
	}

	query := `
		mutation LinkPhoneToUser($user_id: uuid!, $phone_number: String!) {
			update_users_by_pk(
				pk_columns: {id: $user_id}
				_set: {phone_number: $phone_number}
			) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "LinkPhoneToUser",
		Variables: map[string]interface{}{
			"user_id":      userID,
			"phone_number": phoneNumber,
		},
	}

	_, err = a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to link phone to user: %w", err)
	}

	return nil
}

// LinkEmailToUser links an email to an existing user account
func (a *AuthService) LinkEmailToUser(ctx context.Context, userID string, email string) error {
	email = normalizeEmail(email)

	// Check if email is already in use
	existingUser, err := a.getUserByEmail(ctx, email)
	if err != nil {
		return fmt.Errorf("failed to check existing email: %w", err)
	}
	if existingUser != nil && existingUser.ID != userID {
		return fmt.Errorf("email already in use by another account")
	}

	query := `
		mutation LinkEmailToUser($user_id: uuid!, $email: String!) {
			update_users_by_pk(
				pk_columns: {id: $user_id}
				_set: {email: $email}
			) {
				id
			}
		}
	`

	req := GraphQLRequest{
		Query:         query,
		OperationName: "LinkEmailToUser",
		Variables: map[string]interface{}{
			"user_id": userID,
			"email":   email,
		},
	}

	_, err = a.hasuraClient.Execute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to link email to user: %w", err)
	}

	return nil
}
