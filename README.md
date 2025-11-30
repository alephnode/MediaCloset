# MediaCloset

A personal iOS inventory app for tracking your physical media collection (VHS tapes, records, and more).

## Overview

MediaCloset helps you catalog and organize your physical media collection with automatic metadata fetching, barcode scanning, and cover art retrieval. The app consists of:

- **iOS App**: Native SwiftUI interface for browsing and adding media to your collection
- **Go GraphQL API**: Backend service that handles business logic, external API integrations, and data persistence
- **Hasura**: GraphQL database layer for data storage and queries

## Architecture

```
MediaCloset/
├── api/              # Go GraphQL API backend
├── ios/              # iOS SwiftUI application
└── shared/           # common docs, infrastructure, etc.
```

### Technology Stack

**Backend (Go API):**
- Go 1.21+
- GraphQL (gqlgen)
- External APIs: OMDB, MusicBrainz, Discogs, iTunes
- Hasura GraphQL Engine (database layer)

**Frontend (iOS):**
- Swift 5.9+
- SwiftUI
- iOS 17.0+
- Xcode 15.0+

## Project Structure

### `/api` - Go GraphQL API

The backend API server that acts as a proxy and business logic layer between the iOS app and external services.

**Key Features:**
- Auto-fetches movie posters from OMDB
- Auto-fetches album cover art from MusicBrainz
- Barcode lookup for albums (Discogs, iTunes)
- Input validation and error handling
- GraphQL mutations and queries

**Quick Start:**

```bash
cd api

# Install dependencies
go mod download

# Set up environment variables
cp .env.example .env
# Edit .env with your API keys:
# - OMDB_API_KEY
# - DISCOGS_TOKEN
# - HASURA_ENDPOINT
# - HASURA_ADMIN_SECRET

# Run tests
go test ./...

# Build
go build -o bin/server ./cmd/server

# Run
./bin/server
# Server will start on http://localhost:8080
# GraphQL playground: http://localhost:8080/
```

**Environment Variables:**
- `OMDB_API_KEY` - API key for OMDB movie database
- `DISCOGS_TOKEN` - Personal access token for Discogs
- `HASURA_ENDPOINT` - Hasura GraphQL endpoint URL
- `HASURA_ADMIN_SECRET` - Hasura admin secret
- `PORT` - Server port (default: 8080)
- `ENVIRONMENT` - Environment name (development/production)

### `/ios` - iOS Application

Native iOS app built with SwiftUI for managing your media collection.

**Key Features:**
- Browse movies and albums
- Add new items with barcode scanning
- Automatic metadata and cover art fetching
- Search and filter your collection
- Clean, modern SwiftUI interface

**Quick Start:**

```bash
cd ios

# 1. Set up secrets
cp Configs/Secrets.xcconfig Configs/Local.secrets.xcconfig

# 2. Edit Local.secrets.xcconfig with your keys:
# OMDB_API_KEY = your_key_here
# DISCOGS_TOKEN = your_token_here
# HASURA_ENDPOINT = your_hasura_url
# HASURA_ADMIN_SECRET = your_secret
# MEDIACLOSET_API_ENDPOINT = http://localhost:8080/query

# 3. Open in Xcode
open MediaCloset.xcodeproj

# 4. Build and run (⌘R)
# Make sure the Go API server is running first!
```

**Requirements:**
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Go API server running locally or deployed

## Getting Started

### Development Setup

1. **Start the Go API server:**
   ```bash
   cd api
   cp .env.example .env
   # Edit .env with your API keys
   go run ./cmd/server
   ```

2. **Configure iOS app:**
   ```bash
   cd ios
   cp Configs/Secrets.xcconfig Configs/Local.secrets.xcconfig
   # Edit Local.secrets.xcconfig with your keys
   ```

3. **Run iOS app in Xcode:**
   ```bash
   open ios/MediaCloset.xcodeproj
   # Press ⌘R to build and run
   ```

### API Keys Required

**OMDB API Key** (for movie metadata):
- Sign up at https://www.omdbapi.com/apikey.aspx
- Free tier: 1,000 requests/day

**Discogs Personal Access Token** (for album metadata):
1. Create account at https://www.discogs.com
2. Go to Settings → Developers → Generate new token
3. Copy the personal access token

**Hasura** (database):
- Set up a Hasura instance (cloud or local)
- Get the GraphQL endpoint URL and admin secret

## GraphQL API

### Queries

**List all movies:**
```graphql
query {
  movies {
    id
    title
    director
    year
    genre
    coverUrl
  }
}
```

**List all albums:**
```graphql
query {
  albums {
    id
    artist
    album
    year
    label
    genres
    coverUrl
  }
}
```

**Lookup movie by title:**
```graphql
query {
  movieByTitle(title: "The Matrix", year: 1999) {
    title
    director
    posterUrl
    plot
  }
}
```

**Lookup album by barcode:**
```graphql
query {
  albumByBarcode(barcode: "075992739429") {
    artist
    album
    year
    genres
    coverUrl
  }
}
```

### Mutations

**Save a movie** (auto-fetches poster):
```graphql
mutation {
  saveMovie(input: {
    title: "Back to the Future"
    director: "Robert Zemeckis"
    year: 1985
    genre: "Sci-Fi"
  }) {
    success
    movie {
      id
      title
      coverUrl
    }
    error
  }
}
```

**Save an album** (auto-fetches cover art):
```graphql
mutation {
  saveAlbum(input: {
    artist: "Pink Floyd"
    album: "The Dark Side of the Moon"
    year: 1973
  }) {
    success
    album {
      id
      artist
      album
      coverUrl
    }
    error
  }
}
```

## Features

- VHS/Movie tracking with OMDB integration
- Vinyl record tracking with MusicBrainz integration
- Barcode scanning for albums (Discogs + iTunes fallback)
- Automatic cover art fetching
- Input validation and error handling
- Search and filter functionality
- iOS native interface with SwiftUI

## Development

### Running Tests

**Go API:**
```bash
cd api
go test ./...
go test ./internal/services -v  # Verbose output
```

### Building for Production

**Go API:**
```bash
cd api
go build -o bin/server ./cmd/server
./bin/server
```

**iOS App:**
1. Open in Xcode
2. Select "Any iOS Device" or your device
3. Product → Archive
4. Distribute App

## Contributing

This is a personal project, but suggestions and improvements are welcome!

## License

Private project - All rights reserved.

## Acknowledgments

- [OMDB API](https://www.omdbapi.com/) - Movie database
- [MusicBrainz](https://musicbrainz.org/) - Music metadata
- [Discogs](https://www.discogs.com/) - Music database and marketplace
- [iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/) - Apple music catalog
- [Hasura](https://hasura.io/) - GraphQL database layer
