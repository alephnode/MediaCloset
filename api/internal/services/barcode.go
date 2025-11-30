package services

import (
	"context"
	"fmt"
	"regexp"
	"strings"

	"mediacloset/api/internal/graph/model"
)

// BarcodeService orchestrates barcode lookups across multiple services
type BarcodeService struct {
	discogs     *DiscogsService
	itunes      *ITunesService
	musicBrainz *MusicBrainzService
	omdb        *OMDBService
}

// NewBarcodeService creates a new barcode orchestration service
func NewBarcodeService(
	discogs *DiscogsService,
	itunes *ITunesService,
	musicBrainz *MusicBrainzService,
	omdb *OMDBService,
) *BarcodeService {
	return &BarcodeService{
		discogs:     discogs,
		itunes:      itunes,
		musicBrainz: musicBrainz,
		omdb:        omdb,
	}
}

// LookupAlbum attempts to find album data by barcode using multiple services
// Services are tried in order of reliability for music data:
// 1. Discogs (if configured) - Best music database
// 2. iTunes - Good fallback, no auth required
// 3. MusicBrainz - Comprehensive but may require multiple lookups
func (s *BarcodeService) LookupAlbum(ctx context.Context, barcode string) (*model.AlbumData, error) {
	// Clean the barcode
	cleanedBarcode := cleanBarcode(barcode)

	// Try each service in order
	services := []struct {
		name string
		fn   func(context.Context, string) (*model.AlbumData, error)
	}{
		{"Discogs", s.tryDiscogs},
		{"iTunes", s.tryITunes},
		{"MusicBrainz", s.tryMusicBrainz},
	}

	var lastErr error
	for _, service := range services {
		// Try with original barcode
		if data, err := service.fn(ctx, barcode); err == nil && data != nil {
			fmt.Printf("[BarcodeService] Found album via %s (original barcode)\n", service.name)
			return data, nil
		} else if err != nil {
			lastErr = err
		}

		// Try with cleaned barcode if different
		if cleanedBarcode != barcode {
			if data, err := service.fn(ctx, cleanedBarcode); err == nil && data != nil {
				fmt.Printf("[BarcodeService] Found album via %s (cleaned barcode)\n", service.name)
				return data, nil
			} else if err != nil {
				lastErr = err
			}
		}
	}

	if lastErr != nil {
		return nil, fmt.Errorf("no album found for barcode %s: %w", barcode, lastErr)
	}
	return nil, fmt.Errorf("no album found for barcode %s", barcode)
}

// LookupMovie attempts to find movie data by barcode
// For movies, we primarily use OMDB
func (s *BarcodeService) LookupMovie(ctx context.Context, barcode string) (*model.MovieData, error) {
	// For now, movie barcode lookup is not implemented
	// This would require a UPC database or similar service
	return nil, fmt.Errorf("movie barcode lookup not yet implemented")
}

// tryDiscogs attempts to lookup via Discogs
func (s *BarcodeService) tryDiscogs(ctx context.Context, barcode string) (*model.AlbumData, error) {
	if !s.discogs.IsConfigured() {
		return nil, fmt.Errorf("Discogs not configured")
	}
	return s.discogs.SearchByBarcode(ctx, barcode)
}

// tryITunes attempts to lookup via iTunes
func (s *BarcodeService) tryITunes(ctx context.Context, barcode string) (*model.AlbumData, error) {
	return s.itunes.SearchByBarcode(ctx, barcode)
}

// tryMusicBrainz attempts to lookup via MusicBrainz
func (s *BarcodeService) tryMusicBrainz(ctx context.Context, barcode string) (*model.AlbumData, error) {
	// MusicBrainz barcode search is more complex - we need to search releases by barcode
	// then fetch additional metadata

	// This is a simplified version - full implementation would search MusicBrainz
	// release database by barcode and then fetch cover art

	// For now, return nil to fall through to other services
	return nil, fmt.Errorf("MusicBrainz barcode search not yet implemented")
}

// cleanBarcode removes common formatting and leading zeros from barcodes
func cleanBarcode(barcode string) string {
	// Remove whitespace
	cleaned := strings.TrimSpace(barcode)

	// Remove common separators
	cleaned = strings.ReplaceAll(cleaned, "-", "")
	cleaned = strings.ReplaceAll(cleaned, " ", "")

	// Remove non-numeric characters for UPC/EAN
	re := regexp.MustCompile(`[^0-9]`)
	cleaned = re.ReplaceAllString(cleaned, "")

	// Remove leading zeros (but keep at least one digit)
	cleaned = strings.TrimLeft(cleaned, "0")
	if cleaned == "" {
		cleaned = "0"
	}

	return cleaned
}
