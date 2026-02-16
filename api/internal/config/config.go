package config

import (
	"fmt"
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	Port        string
	Environment string

	HasuraEndpoint    string
	HasuraAdminSecret string

	APIKey        string // API key for client authentication (legacy, can be removed later)
	OMDBAPIKey    string
	DiscogsKey    string
	DiscogsSecret string
	LastFMAPIKey  string

	// Auth
	JWTSecret string // Secret key for JWT token signing

	// AWS SES Email
	AWSRegion          string
	AWSAccessKeyID     string
	AWSSecretAccessKey string
	AWSSESFromEmail    string // Verified sender email in SES

	// AWS S3 Image Uploads
	S3Bucket    string
	S3URLPrefix string // Public URL base, e.g. https://bucket.s3.amazonaws.com

	// Feature flags
	EnableCache     bool
	EnableRateLimit bool

	// App version gating (forced updates)
	MinimumIOSVersion  string
	ForceUpdateMessage string
	AppStoreURL        string
}

func Load() *Config {
	viper.AutomaticEnv()
	viper.SetConfigName(".env")
	viper.SetConfigType("env")
	viper.AddConfigPath(".")
	viper.AddConfigPath("..")
	viper.AddConfigPath("../..")

	viper.SetDefault("PORT", "8080")
	viper.SetDefault("ENVIRONMENT", "development")
	viper.SetDefault("ENABLE_CACHE", false)
	viper.SetDefault("ENABLE_RATE_LIMIT", true)
	viper.SetDefault("AWS_REGION", "us-east-1")

	// App version gating defaults
	viper.SetDefault("MINIMUM_IOS_VERSION", "1.0.0")
	viper.SetDefault("FORCE_UPDATE_MESSAGE", "Please update to the latest version to continue using MediaCloset.")
	viper.SetDefault("APP_STORE_URL", "")

	// Read config file (optional - env vars take precedence)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("No .env file found, using environment variables")
		} else {
			log.Printf("Error reading config file: %v", err)
		}
	}

	cfg := &Config{
		Port:               viper.GetString("PORT"),
		Environment:        viper.GetString("ENVIRONMENT"),
		HasuraEndpoint:     viper.GetString("HASURA_ENDPOINT"),
		HasuraAdminSecret:  viper.GetString("HASURA_ADMIN_SECRET"),
		APIKey:             viper.GetString("API_KEY"),
		OMDBAPIKey:         viper.GetString("OMDB_API_KEY"),
		DiscogsKey:         viper.GetString("DISCOGS_CONSUMER_KEY"),
		DiscogsSecret:      viper.GetString("DISCOGS_CONSUMER_SECRET"),
		LastFMAPIKey:       viper.GetString("LASTFM_API_KEY"),
		JWTSecret:          viper.GetString("JWT_SECRET"),
		AWSRegion:          viper.GetString("AWS_REGION"),
		AWSAccessKeyID:     viper.GetString("AWS_ACCESS_KEY_ID"),
		AWSSecretAccessKey: viper.GetString("AWS_SECRET_ACCESS_KEY"),
		AWSSESFromEmail:    viper.GetString("AWS_SES_FROM_EMAIL"),
		S3Bucket:           viper.GetString("S3_BUCKET"),
		S3URLPrefix:        viper.GetString("S3_URL_PREFIX"),
		EnableCache:        viper.GetBool("ENABLE_CACHE"),
		EnableRateLimit:    viper.GetBool("ENABLE_RATE_LIMIT"),

		MinimumIOSVersion:  viper.GetString("MINIMUM_IOS_VERSION"),
		ForceUpdateMessage: viper.GetString("FORCE_UPDATE_MESSAGE"),
		AppStoreURL:        viper.GetString("APP_STORE_URL"),
	}

	if cfg.APIKey == "" {
		log.Fatal("API_KEY is required")
	}
	if cfg.OMDBAPIKey == "" {
		log.Fatal("OMDB_API_KEY is required")
	}
	if cfg.HasuraEndpoint == "" {
		log.Fatal("HASURA_ENDPOINT is required")
	}
	if cfg.HasuraAdminSecret == "" {
		log.Fatal("HASURA_ADMIN_SECRET is required")
	}
	if cfg.JWTSecret == "" {
		log.Fatal("JWT_SECRET is required")
	}

	log.Printf("Config loaded: environment=%s, port=%s", cfg.Environment, cfg.Port)
	return cfg
}

func (c *Config) IsDevelopment() bool {
	return c.Environment == "development"
}

func (c *Config) GetServerAddress() string {
	return fmt.Sprintf(":%s", c.Port)
}
