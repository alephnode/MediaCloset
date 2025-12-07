package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/sesv2"
	"github.com/aws/aws-sdk-go-v2/service/sesv2/types"
)

// EmailService handles sending emails via AWS SES
type EmailService struct {
	sesClient *sesv2.Client
	fromEmail string
	appName   string
}

// NewEmailService creates a new email service with AWS SES
func NewEmailService(ctx context.Context, region, accessKeyID, secretAccessKey, fromEmail string) (*EmailService, error) {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKeyID, secretAccessKey, "")),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	return &EmailService{
		sesClient: sesv2.NewFromConfig(cfg),
		fromEmail: fromEmail,
		appName:   "MediaCloset",
	}, nil
}

// SendLoginCode sends a login code email to the user
func (e *EmailService) SendLoginCode(ctx context.Context, toEmail, code string) error {
	subject := fmt.Sprintf("Your %s login code: %s", e.appName, code)
	htmlBody := e.buildLoginCodeHTML(code)
	textBody := e.buildLoginCodeText(code)

	input := &sesv2.SendEmailInput{
		FromEmailAddress: aws.String(e.fromEmail),
		Destination: &types.Destination{
			ToAddresses: []string{toEmail},
		},
		Content: &types.EmailContent{
			Simple: &types.Message{
				Subject: &types.Content{
					Data:    aws.String(subject),
					Charset: aws.String("UTF-8"),
				},
				Body: &types.Body{
					Html: &types.Content{
						Data:    aws.String(htmlBody),
						Charset: aws.String("UTF-8"),
					},
					Text: &types.Content{
						Data:    aws.String(textBody),
						Charset: aws.String("UTF-8"),
					},
				},
			},
		},
	}

	_, err := e.sesClient.SendEmail(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	return nil
}

// buildLoginCodeHTML creates a beautiful, responsive HTML email
func (e *EmailService) buildLoginCodeHTML(code string) string {
	// Format the code with spaces for readability (e.g., "123 456")
	formattedCode := formatCodeWithSpaces(code)

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Your Login Code</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f7; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f7;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" style="max-width: 440px; background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);">
          <!-- Header -->
          <tr>
            <td style="padding: 40px 40px 24px 40px; text-align: center;">
              <div style="display: inline-block; background: linear-gradient(135deg, #6366f1 0%%, #8b5cf6 100%%); width: 56px; height: 56px; border-radius: 14px; line-height: 56px;">
                <span style="font-size: 28px;">📦</span>
              </div>
              <h1 style="margin: 20px 0 0 0; font-size: 22px; font-weight: 600; color: #1a1a1a;">%s</h1>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 0 40px;">
              <p style="margin: 0 0 24px 0; font-size: 15px; line-height: 24px; color: #666666; text-align: center;">
                Enter this code to sign in to your account. It expires in 5 minutes.
              </p>
            </td>
          </tr>
          
          <!-- Code Box -->
          <tr>
            <td style="padding: 0 40px;">
              <div style="background-color: #f8f9fa; border-radius: 12px; padding: 24px; text-align: center; border: 1px solid #e9ecef;">
                <span style="font-family: 'SF Mono', SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace; font-size: 36px; font-weight: 600; letter-spacing: 8px; color: #1a1a1a;">%s</span>
              </div>
            </td>
          </tr>
          
          <!-- Security Notice -->
          <tr>
            <td style="padding: 24px 40px 40px 40px;">
              <p style="margin: 0; font-size: 13px; line-height: 20px; color: #999999; text-align: center;">
                If you didn't request this code, you can safely ignore this email. Someone may have entered your email by mistake.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 24px 40px; border-top: 1px solid #f0f0f0; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #999999;">
                © %d %s. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`, e.appName, formattedCode, 2025, e.appName)
}

// buildLoginCodeText creates a plain text version for email clients that don't support HTML
func (e *EmailService) buildLoginCodeText(code string) string {
	return fmt.Sprintf(`%s - Your Login Code

Your verification code is: %s

This code expires in 5 minutes.

If you didn't request this code, you can safely ignore this email.

- The %s Team`, e.appName, code, e.appName)
}

// formatCodeWithSpaces adds a space in the middle of the code for readability
func formatCodeWithSpaces(code string) string {
	if len(code) <= 3 {
		return code
	}
	mid := len(code) / 2
	return strings.TrimSpace(code[:mid] + " " + code[mid:])
}
