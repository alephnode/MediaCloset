package config

import (
	"fmt"
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	Port        string
	Environment string

	// API Keys
	OMDBAPIKey      string
	DiscogsKey      string
	DiscogsSecret   string
	LastFMAPIKey    string

	// Feature flags
	EnableCache     bool
	EnableRateLimit bool
}

func Load() *Config {
	viper.AutomaticEnv()
	viper.SetConfigName(".env")
	viper.SetConfigType("env")
	viper.AddConfigPath(".")
	viper.AddConfigPath("..")
	viper.AddConfigPath("../..")

	// Set defaults
	viper.SetDefault("PORT", "8080")
	viper.SetDefault("ENVIRONMENT", "development")
	viper.SetDefault("ENABLE_CACHE", false)
	viper.SetDefault("ENABLE_RATE_LIMIT", true)

	// Read config file (optional - env vars take precedence)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("No .env file found, using environment variables")
		} else {
			log.Printf("Error reading config file: %v", err)
		}
	}

	cfg := &Config{
		Port:            viper.GetString("PORT"),
		Environment:     viper.GetString("ENVIRONMENT"),
		OMDBAPIKey:      viper.GetString("OMDB_API_KEY"),
		DiscogsKey:      viper.GetString("DISCOGS_CONSUMER_KEY"),
		DiscogsSecret:   viper.GetString("DISCOGS_CONSUMER_SECRET"),
		LastFMAPIKey:    viper.GetString("LASTFM_API_KEY"),
		EnableCache:     viper.GetBool("ENABLE_CACHE"),
		EnableRateLimit: viper.GetBool("ENABLE_RATE_LIMIT"),
	}

	// Validate required keys
	if cfg.OMDBAPIKey == "" {
		log.Fatal("OMDB_API_KEY is required")
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
