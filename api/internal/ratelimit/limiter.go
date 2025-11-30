package ratelimit

import (
	"context"
	"time"

	"golang.org/x/time/rate"
)

// ServiceLimiter manages rate limits for different external APIs
type ServiceLimiter struct {
	musicBrainz *rate.Limiter
}

// NewServiceLimiter creates a new rate limiter with appropriate limits for each service
func NewServiceLimiter() *ServiceLimiter {
	return &ServiceLimiter{
		// MusicBrainz API allows 1 request per second
		musicBrainz: rate.NewLimiter(rate.Every(1*time.Second), 1),
	}
}

// WaitMusicBrainz blocks until the MusicBrainz rate limit allows a request
// Returns an error if the context is canceled
func (sl *ServiceLimiter) WaitMusicBrainz(ctx context.Context) error {
	return sl.musicBrainz.Wait(ctx)
}

// AllowMusicBrainz checks if a MusicBrainz request can proceed without blocking
// Returns true if allowed, false otherwise
func (sl *ServiceLimiter) AllowMusicBrainz() bool {
	return sl.musicBrainz.Allow()
}
