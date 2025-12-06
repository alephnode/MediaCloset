# How to Perform an API Update

This guide walks through the process of adding or updating fields in the MediaCloset backend API and consuming them in the iOS frontend.

## Overview

The MediaCloset stack consists of:
- **Database**: Neon (PostgreSQL)
- **API Layer**: Hasura GraphQL (auto-generated from database schema)
- **Backend Proxy**: Go GraphQL API (proxies Hasura + external APIs)
- **Frontend**: iOS SwiftUI app

When making schema changes, updates need to flow through each layer in the correct order.

---

## Scenarios

### Scenario 1: Adding a New Field

**Example**: Adding a `condition` field to track the physical condition of a record.

### Scenario 2: Changing a Field Type

**Example**: Converting `color_variant: String` to `color_variants: [String]` (single value → array).

### Scenario 3: Renaming a Field

**Example**: Renaming `genre` to `genres` for consistency.

---

## Step-by-Step Process

### Phase 1: Database Migration (Neon)

Database changes must happen first since Hasura auto-generates its schema from the database.

#### 1.1 Connect to Neon

Option A: Use the **Neon Console** → SQL Editor

Option B: Connect via `psql`:
```bash
psql "postgres://username:password@your-host.neon.tech/neondb?sslmode=require"
```

#### 1.2 Run Migration SQL

**Adding a new field:**
```sql
ALTER TABLE records 
ADD COLUMN condition TEXT;
```

**Adding a new array field:**
```sql
ALTER TABLE records 
ADD COLUMN tags TEXT[];
```

**Converting a field from string to array:**
```sql
-- Step 1: Add new array column
ALTER TABLE records 
ADD COLUMN color_variants TEXT[];

-- Step 2: Migrate existing data
UPDATE records 
SET color_variants = ARRAY[color_variant]
WHERE color_variant IS NOT NULL AND color_variant != '';

-- Step 3: Drop old column (use CASCADE if Hasura has dependencies)
ALTER TABLE records 
DROP COLUMN color_variant CASCADE;
```

**Renaming a field:**
```sql
ALTER TABLE records 
RENAME COLUMN old_name TO new_name;
```

#### 1.3 Refresh Hasura Metadata

After database changes:
1. Go to **Hasura Console** → **Data** tab
2. Click on the affected table (e.g., `records`)
3. Click **"Reload"** or **"Track all"** to refresh the schema
4. Verify the new/updated column appears correctly

---

### Phase 2: Update Go Backend API

#### 2.1 Update GraphQL Schema

Edit `api/internal/graph/schema.graphql`:

**For types returned by queries:**
```graphql
type Album {
  id: String!
  artist: String!
  album: String!
  # Add new field
  condition: String
  # Or change field type
  color_variants: [String!]
}
```

**For input types (mutations):**
```graphql
input SaveAlbumInput {
  artist: String!
  album: String!
  # Add new field
  condition: String
  # Or change field type  
  color_variants: [String!]
}

input UpdateAlbumInput {
  artist: String
  album: String
  # Add new field
  condition: String
  # Or change field type
  color_variants: [String!]
}
```

**For response types:**
```graphql
type SavedAlbum {
  id: Int!
  artist: String!
  album: String!
  # Add new field
  condition: String
  # Or change field type
  color_variants: [String!]
}
```

#### 2.2 Update Resolvers

Edit `api/internal/graph/schema.resolvers.go`:

**For SaveAlbum mutation:**
```go
// Build record object for Hasura
record := map[string]interface{}{
    "artist": input.Artist,
    "album":  input.Album,
}

// Handle new/updated field
if input.Condition != nil {
    record["condition"] = *input.Condition
}
// Or for arrays:
if len(input.ColorVariants) > 0 {
    record["color_variants"] = input.ColorVariants
}
```

**For UpdateAlbum mutation:**
```go
updates := make(map[string]interface{})

if input.Condition != nil {
    updates["condition"] = *input.Condition
}
// Or for arrays:
if len(input.ColorVariants) > 0 {
    updates["color_variants"] = input.ColorVariants
}
```

**For reading from Hasura responses:**
```go
// For string fields:
if condition, ok := albumData["condition"].(string); ok {
    album.Condition = &condition
}

// For array fields:
if colorVariants, ok := albumData["color_variants"].([]interface{}); ok {
    variantStrs := make([]string, 0, len(colorVariants))
    for _, v := range colorVariants {
        if variantStr, ok := v.(string); ok {
            variantStrs = append(variantStrs, variantStr)
        }
    }
    if len(variantStrs) > 0 {
        album.ColorVariants = variantStrs
    }
}
```

#### 2.3 Update Hasura Service Queries

Edit `api/internal/services/hasura.go`:

Update all relevant GraphQL queries to include the new/updated field:

```go
query := `
    query GetAllAlbums {
        records(order_by: {created_at: desc}) {
            id
            artist
            album
            condition          # Add new field
            color_variants     # Or updated field
            genres
            cover_url
        }
    }
`
```

Update queries in:
- `InsertRecord`
- `GetAllAlbums`
- `GetAlbumByID`
- `UpdateAlbum`

#### 2.4 Regenerate Go Code

```bash
cd api

# Delete generated files to force full regeneration
rm -f internal/graph/generated.go internal/graph/model/models_gen.go

# Regenerate
go run github.com/99designs/gqlgen generate

# Verify build succeeds
go build ./...
```

---

### Phase 3: Update iOS Frontend

#### 3.1 Update API Client Models

Edit `ios/MediaCloset/Networking/MediaClosetAPIClient.swift`:

**Update struct definitions:**
```swift
struct Album: Decodable {
    let id: String
    let artist: String
    let album: String
    let condition: String?           // New field
    let color_variants: [String]?    // Or updated field type
    
    // Convenience computed property
    var colorVariants: [String]? { color_variants }
}

struct SavedAlbum: Decodable {
    let id: Int
    let artist: String
    let album: String
    let condition: String?
    let color_variants: [String]?
    
    var colorVariants: [String]? { color_variants }
}
```

**Update function signatures:**
```swift
func saveAlbum(
    artist: String, 
    album: String, 
    condition: String? = nil,           // New parameter
    colorVariants: [String]? = nil,     // Or updated type
    // ... other parameters
) async throws -> SaveAlbumResponse
```

**Update GraphQL queries in the function bodies:**
```swift
let query = """
mutation SaveAlbum($input: SaveAlbumInput!) {
  saveAlbum(input: $input) {
    success
    album {
      id
      artist
      album
      condition
      color_variants
    }
    error
  }
}
"""
```

**Update input building:**
```swift
var input: [String: Any] = [...]

if let condition = condition {
    input["condition"] = condition
}
// Or for arrays:
if let colorVariants = colorVariants, !colorVariants.isEmpty {
    input["color_variants"] = colorVariants
}
```

#### 3.2 Update Data Models

Edit `ios/MediaCloset/Models/Models.swift`:

```swift
struct RecordListItem: Identifiable, Hashable {
    let id: String
    let artist: String
    let album: String
    let condition: String?          // New field
    let colorVariants: [String]     // Or updated type
    // ...
}
```

#### 3.3 Update ViewModels

Edit `ios/MediaCloset/ViewModels/RecordsVM.swift`:

```swift
items = filteredAlbums.map { album in
    RecordListItem(
        id: album.id,
        artist: album.artist,
        album: album.album,
        condition: album.condition,
        colorVariants: album.colorVariants ?? [],
        // ...
    )
}
```

#### 3.4 Update Views

**List Views** (`RecordListView.swift`):
```swift
// Display new/updated field in list items
Text(item.colorVariants.joined(separator: ", "))
```

**Detail Views** (`RecordDetailView.swift`):
```swift
if let colorVariants = obj["color_variants"] as? [String], !colorVariants.isEmpty {
    Text("Colors: \(colorVariants.joined(separator: ", "))")
}
```

**Form Views** (`RecordFormView.swift`, `RecordEditView.swift`):
```swift
// State variable for comma-separated input
@State private var colorVariantsCSV = ""

// Text field
TextField("Color variants (comma-separated)", text: $colorVariantsCSV)

// Convert to array when saving
let colorVariantsArray: [String]? = colorVariantsCSV.isEmpty ? nil : colorVariantsCSV
    .split(separator: ",")
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty }
```

#### 3.5 Update Legacy GQL Queries (if applicable)

Edit `ios/MediaCloset/Networking/GQL.swift` if direct Hasura queries are still used:

```swift
static let queryRecords = """
query Records(...) {
  records(...) {
    id artist album condition color_variants genres cover_url
  }
}
"""
```

---

## Deployment Order

Execute these steps in order to avoid breaking the app:

### 1. Database First
- Run migration SQL in Neon
- Refresh Hasura metadata
- Test queries in Hasura Console

### 2. Deploy Backend API
- Commit and push Go API changes
- Deploy to Railway (or your hosting platform)
- Verify API health endpoint responds

### 3. Deploy/Build iOS App
- Build and test locally
- Deploy via TestFlight or App Store

---

## Rollback Procedures

### Database Rollback

**Remove a new column:**
```sql
ALTER TABLE records DROP COLUMN condition;
```

**Revert array back to string:**
```sql
-- Add back original column
ALTER TABLE records ADD COLUMN color_variant TEXT;

-- Migrate data (take first array element)
UPDATE records 
SET color_variant = color_variants[1]
WHERE color_variants IS NOT NULL AND array_length(color_variants, 1) > 0;

-- Drop array column
ALTER TABLE records DROP COLUMN color_variants CASCADE;
```

### API Rollback
- Revert Git commits
- Redeploy previous version

### iOS Rollback
- Revert Git commits
- Rebuild and redeploy

---

## Testing Checklist

- [ ] Database migration completes without errors
- [ ] Hasura Console shows correct schema
- [ ] Go API builds successfully
- [ ] Go API health check passes after deployment
- [ ] iOS app compiles without errors
- [ ] New/updated field displays correctly in list views
- [ ] New/updated field displays correctly in detail views
- [ ] New/updated field can be edited in form views
- [ ] Saving new records works
- [ ] Updating existing records works
- [ ] Existing data displays correctly after migration

---

## Common Issues

### "Cannot drop column... other objects depend on it"
Use `CASCADE` when dropping columns that Hasura has dependencies on:
```sql
ALTER TABLE records DROP COLUMN old_column CASCADE;
```
Then refresh Hasura metadata.

### "Field not found" errors in iOS
Ensure the field name in Swift matches the GraphQL response exactly (usually `snake_case` from the database).

### gqlgen fails to generate
- Ensure the schema.graphql syntax is valid
- Check that resolver code matches the new schema
- Delete generated files and regenerate fresh

### iOS decoding errors
Ensure optional fields use `?` in Swift structs:
```swift
let newField: String?  // Optional
let newField: [String]?  // Optional array
```
