import Foundation

// MARK: - Auth Models

/// User information returned from the API
struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Pagination Models

/// Sort field options for list queries
enum SortField: String, Codable, CaseIterable {
    case createdAt = "CREATED_AT"
    case title = "TITLE"
    case artist = "ARTIST"
    case year = "YEAR"

    var displayName: String {
        switch self {
        case .createdAt: return "Date Added"
        case .title: return "Title"
        case .artist: return "Artist"
        case .year: return "Year"
        }
    }
}

/// Sort order options
enum SortOrder: String, Codable {
    case asc = "ASC"
    case desc = "DESC"
}

/// Page info returned from paginated queries
struct PageInfo: Codable {
    let hasNextPage: Bool
    let totalCount: Int
}

/// Paginated response wrapper for movies
struct MovieConnection: Codable {
    let items: [MovieItem]
    let pageInfo: PageInfo

    struct MovieItem: Codable {
        let id: String
        let title: String
        let director: String?
        let year: Int?
        let genre: String?
        let coverUrl: String?
        let createdAt: String?
        let updatedAt: String?
    }
}

/// Paginated response wrapper for albums
struct AlbumConnection: Codable {
    let items: [AlbumItem]
    let pageInfo: PageInfo

    struct AlbumItem: Codable {
        let id: String
        let artist: String
        let album: String
        let year: Int?
        let label: String?
        let color_variants: [String]?
        let genres: [String]?
        let coverUrl: String?
        let size: Int?
        let createdAt: String?
        let updatedAt: String?

        var colorVariants: [String] { color_variants ?? [] }
    }
}

// MARK: - Vinyl Size

/// Preset vinyl record sizes for the picker UI
enum VinylSizeOption: String, CaseIterable, Identifiable {
    case seven = "7"
    case ten = "10"
    case twelve = "12"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seven: return "7\""
        case .ten: return "10\""
        case .twelve: return "12\""
        case .other: return "Other"
        }
    }

    var inches: Int? {
        switch self {
        case .seven: return 7
        case .ten: return 10
        case .twelve: return 12
        case .other: return nil
        }
    }

    /// Determines which option matches a given size value
    static func from(size: Int?) -> VinylSizeOption {
        switch size {
        case 7: return .seven
        case 10: return .ten
        case 12: return .twelve
        case .some: return .other
        case .none: return .twelve // default
        }
    }
}

// MARK: - Record Models

struct RecordListItem: Identifiable, Hashable {
    let id: String;
    let artist: String;
    let album: String;
    let year: Int?;
    let colorVariants: [String];
    let genres: [String];
    let coverUrl: String?
    let size: Int?
}

struct VHSListItem: Identifiable, Hashable {
    let id: String;
    let title: String;
    let director: String?;
    let year: Int?;
    let genre: String?;
    let coverUrl: String?
}

struct TrackRow: Identifiable {
    let id = UUID();
    var title: String = "";
    var durationSec: Int? = nil;
    var trackNo: Int? = nil
}
