package services

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
)

// S3Service handles generating presigned URLs for image uploads
type S3Service struct {
	presignClient *s3.PresignClient
	bucket        string
	urlPrefix     string
}

// NewS3Service creates a new S3 service for presigned URL generation
func NewS3Service(ctx context.Context, region, accessKeyID, secretAccessKey, bucket, urlPrefix string) (*S3Service, error) {
	cfg, err := awsconfig.LoadDefaultConfig(ctx,
		awsconfig.WithRegion(region),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKeyID, secretAccessKey, "")),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := s3.NewFromConfig(cfg)
	presignClient := s3.NewPresignClient(client)

	return &S3Service{
		presignClient: presignClient,
		bucket:        bucket,
		urlPrefix:     urlPrefix,
	}, nil
}

// GenerateUploadURL creates a presigned PUT URL for uploading an image.
// Returns the presigned upload URL and the final public image URL.
func (s *S3Service) GenerateUploadURL(ctx context.Context, userID, contentType string) (uploadURL string, imageURL string, err error) {
	ext := "jpg"
	if contentType == "image/png" {
		ext = "png"
	} else if contentType == "image/webp" {
		ext = "webp"
	}

	objectKey := fmt.Sprintf("covers/%s/%s.%s", userID, uuid.New().String(), ext)

	presignResult, err := s.presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(objectKey),
		ContentType: aws.String(contentType),
	}, s3.WithPresignExpires(5*time.Minute))
	if err != nil {
		return "", "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	imageURL = fmt.Sprintf("%s/%s", s.urlPrefix, objectKey)

	return presignResult.URL, imageURL, nil
}
