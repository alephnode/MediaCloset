import Foundation

// MARK: - Auth Models

/// User information returned from the API
struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let createdAt: String?
    let updatedAt: String?
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
