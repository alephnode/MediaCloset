package graph

import (
	"mediacloset/api/internal/config"
	"mediacloset/api/internal/ratelimit"
	"mediacloset/api/internal/services"
	"time"
)

// This file will not be regenerated automatically.
//
// It serves as dependency injection for your app, add any dependencies you require
// here.

type Resolver struct {
	Config          *config.Config
	OMDBService     *services.OMDBService
	MusicBrainz     *services.MusicBrainzService
	Discogs         *services.DiscogsService
	ITunes          *services.ITunesService
	BarcodeService  *services.BarcodeService
	RateLimiter     *ratelimit.ServiceLimiter
	ServerStartTime time.Time
}
