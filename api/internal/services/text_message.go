package services

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sns/types"
)

// TextMessageService handles sending SMS messages via AWS SNS
type TextMessageService struct {
	snsClient *sns.Client
	appName   string
}

// NewTextMessageService creates a new text message service with AWS SNS
func NewTextMessageService(ctx context.Context, region, accessKeyID, secretAccessKey string) (*TextMessageService, error) {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKeyID, secretAccessKey, "")),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	return &TextMessageService{
		snsClient: sns.NewFromConfig(cfg),
		appName:   "MediaCloset",
	}, nil
}

// SendLoginCode sends a login code via SMS to the user's phone number
func (t *TextMessageService) SendLoginCode(ctx context.Context, phoneNumber, code string) error {
	message := t.buildLoginCodeMessage(code)

	input := &sns.PublishInput{
		PhoneNumber: aws.String(phoneNumber),
		Message:     aws.String(message),
		MessageAttributes: map[string]types.MessageAttributeValue{
			"AWS.SNS.SMS.SMSType": {
				DataType:    aws.String("String"),
				StringValue: aws.String("Transactional"),
			},
			"AWS.SNS.SMS.SenderID": {
				DataType:    aws.String("String"),
				StringValue: aws.String("MediaCloset"),
			},
		},
	}

	_, err := t.snsClient.Publish(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to send SMS: %w", err)
	}

	return nil
}

// buildLoginCodeMessage creates a concise SMS message for login codes
func (t *TextMessageService) buildLoginCodeMessage(code string) string {
	// Format the code with a space for readability (e.g., "123 456")
	formattedCode := formatCodeWithSpaces(code)

	// Keep SMS messages short and to the point
	return fmt.Sprintf("%s code: %s\n\nExpires in 5 minutes. If you didn't request this, ignore this message.", t.appName, formattedCode)
}
