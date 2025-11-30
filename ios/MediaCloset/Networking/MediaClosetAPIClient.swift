//
//  Networking/MediaClosetAPIClient.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/29/25.
//

import Foundation

/// Errors that can occur when using the MediaCloset API
enum MediaClosetAPIError: Error {
    case configurationError(String)
    case networkError(Error)
    case parsingError(String)
    case noData
}

/// Client for the MediaCloset Go GraphQL API
final class MediaClosetAPIClient {
    static let shared = MediaClosetAPIClient()
    private let secretsManager = SecretsManager.shared

    private init() {}

    /// The MediaCloset API endpoint URL
    var endpointURL: URL? {
        guard let url = secretsManager.mediaClosetAPIEndpoint else {
            #if DEBUG
            print("[MediaClosetAPIClient] ERROR: No MediaCloset API endpoint available. Secrets status:")
            let status = secretsManager.secretsStatus
            for (key, value) in status {
                print("  \(key): \(value)")
            }
            print("[MediaClosetAPIClient] WARNING: MEDIACLOSET_API_ENDPOINT must be configured. Please set up xcconfig files properly.")
            #endif
            return nil
        }
        return url
    }

    /// Headers for MediaCloset API requests
    private var headers: [String: String] {
        return [
            "Content-Type": "application/json",
            "User-Agent": "MediaCloset-iOS/1.0"
        ]
    }

    // MARK: - GraphQL Response Types

    struct GraphQLResponse<T: Decodable>: Decodable {
        let data: T?
        let errors: [GraphQLResponseError]?
    }

    struct GraphQLResponseError: Decodable {
        let message: String
        let path: [String]?
    }

    // MARK: - Data Models

    /// Movie metadata from the API
    struct MovieData: Decodable {
        let title: String?
        let year: Int?
        let director: String?
        let genre: String?
        let posterUrl: String?
        let plot: String?
        let source: String?

        // Convenience computed property for Swift naming conventions
        var posterURL: String? { posterUrl }
    }

    /// Album metadata from the API
    struct AlbumData: Decodable {
        let artist: String?
        let album: String?
        let year: Int?
        let label: String?
        let genres: [String]?
        let coverUrl: String?
        let source: String?

        // Convenience computed property for Swift naming conventions
        var coverURL: String? { coverUrl }
    }

    // MARK: - Private Methods

    /// Executes a GraphQL query against the MediaCloset API
    private func execute<T: Decodable>(
        operationName: String,
        query: String,
        variables: [String: Any]? = nil
    ) async throws -> T {
        guard let url = endpointURL else {
            throw MediaClosetAPIError.configurationError("MediaCloset API endpoint not configured")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let body: [String: Any] = [
            "operationName": operationName,
            "query": query,
            "variables": variables ?? [:]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("[MediaClosetAPIClient] Executing \(operationName)")
        if let vars = variables {
            print("[MediaClosetAPIClient] Variables: \(vars)")
        }
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("[MediaClosetAPIClient] HTTP Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[MediaClosetAPIClient] Response: \(responseString)")
            }
            #endif

            let graphQLResponse = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)

            if let errors = graphQLResponse.errors, !errors.isEmpty {
                let errorMessages = errors.map { $0.message }.joined(separator: ", ")
                #if DEBUG
                print("[MediaClosetAPIClient] GraphQL errors: \(errorMessages)")
                #endif
                throw MediaClosetAPIError.parsingError("GraphQL errors: \(errorMessages)")
            }

            guard let result = graphQLResponse.data else {
                throw MediaClosetAPIError.noData
            }

            return result
        } catch let error as MediaClosetAPIError {
            throw error
        } catch {
            #if DEBUG
            print("[MediaClosetAPIClient] Network error: \(error)")
            #endif
            throw MediaClosetAPIError.networkError(error)
        }
    }

    // MARK: - Mutation Response Types

    /// Response from saveMovie mutation
    struct SaveMovieResponse: Decodable {
        let success: Bool
        let movie: SavedMovie?
        let error: String?
    }

    struct SavedMovie: Decodable {
        let id: Int
        let title: String
        let director: String?
        let year: Int?
        let genre: String?
        let coverUrl: String?

        // Convenience computed property for Swift naming conventions
        var coverURL: String? { coverUrl }
    }

    // MARK: - Public API Methods

    /// Saves a movie to the database (auto-fetches poster if not provided)
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: Optional director name
    ///   - year: Optional release year
    ///   - genre: Optional genre
    ///   - coverUrl: Optional cover URL (will be auto-fetched if not provided)
    /// - Returns: SaveMovieResponse with success status and saved movie data
    func saveMovie(title: String, director: String? = nil, year: Int? = nil, genre: String? = nil, coverUrl: String? = nil) async throws -> SaveMovieResponse {
        struct Response: Decodable {
            let saveMovie: SaveMovieResponse
        }

        let query = """
        mutation SaveMovie($input: SaveMovieInput!) {
          saveMovie(input: $input) {
            success
            movie {
              id
              title
              director
              year
              genre
              coverUrl
            }
            error
          }
        }
        """

        var input: [String: Any] = ["title": title]
        if let director = director {
            input["director"] = director
        }
        if let year = year {
            input["year"] = year
        }
        if let genre = genre {
            input["genre"] = genre
        }
        if let coverUrl = coverUrl {
            input["coverUrl"] = coverUrl
        }

        let variables: [String: Any] = ["input": input]

        let response: Response = try await execute(
            operationName: "SaveMovie",
            query: query,
            variables: variables
        )

        return response.saveMovie
    }

    /// Fetches movie metadata by title
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: Optional director name for disambiguation
    ///   - year: Optional release year for disambiguation
    /// - Returns: MovieData if found, nil otherwise
    func fetchMovieByTitle(title: String, director: String? = nil, year: Int? = nil) async throws -> MovieData? {
        struct Response: Decodable {
            let movieByTitle: MovieData?
        }

        let query = """
        query MovieByTitle($title: String!, $director: String, $year: Int) {
          movieByTitle(title: $title, director: $director, year: $year) {
            title
            year
            director
            genre
            posterUrl
            plot
            source
          }
        }
        """

        var variables: [String: Any] = ["title": title]
        if let director = director {
            variables["director"] = director
        }
        if let year = year {
            variables["year"] = year
        }

        let response: Response = try await execute(
            operationName: "MovieByTitle",
            query: query,
            variables: variables
        )

        return response.movieByTitle
    }

    /// Saves an album to the database (auto-fetches cover if not provided)
    /// - Parameters:
    ///   - artist: The artist name
    ///   - album: The album title
    ///   - year: Optional release year
    ///   - label: Optional record label
    ///   - genre: Optional genre
    ///   - coverUrl: Optional cover URL (will be auto-fetched if not provided)
    /// - Returns: SaveAlbumResponse with success status and saved album data
    func saveAlbum(artist: String, album: String, year: Int? = nil, label: String? = nil, genre: String? = nil, coverUrl: String? = nil) async throws -> SaveAlbumResponse {
        struct Response: Decodable {
            let saveAlbum: SaveAlbumResponse
        }

        let query = """
        mutation SaveAlbum($input: SaveAlbumInput!) {
          saveAlbum(input: $input) {
            success
            album {
              id
              artist
              album
              year
              label
              genre
              coverUrl
            }
            error
          }
        }
        """

        var input: [String: Any] = [
            "artist": artist,
            "album": album
        ]
        if let year = year {
            input["year"] = year
        }
        if let label = label {
            input["label"] = label
        }
        if let genre = genre {
            input["genre"] = genre
        }
        if let coverUrl = coverUrl {
            input["coverUrl"] = coverUrl
        }

        let variables: [String: Any] = ["input": input]

        let response: Response = try await execute(
            operationName: "SaveAlbum",
            query: query,
            variables: variables
        )

        return response.saveAlbum
    }

    /// Response from saveAlbum mutation
    struct SaveAlbumResponse: Decodable {
        let success: Bool
        let album: SavedAlbum?
        let error: String?
    }

    struct SavedAlbum: Decodable {
        let id: Int
        let artist: String
        let album: String
        let year: Int?
        let label: String?
        let genre: String?
        let coverUrl: String?

        // Convenience computed property for Swift naming conventions
        var coverURL: String? { coverUrl }
    }

    /// Fetches album metadata by artist and title
    /// - Parameters:
    ///   - artist: The artist name
    ///   - album: The album title
    /// - Returns: AlbumData if found, nil otherwise
    func fetchAlbumByArtistAndTitle(artist: String, album: String) async throws -> AlbumData? {
        struct Response: Decodable {
            let albumByArtistAndTitle: AlbumData?
        }

        let query = """
        query AlbumByArtistAndTitle($artist: String!, $album: String!) {
          albumByArtistAndTitle(artist: $artist, album: $album) {
            artist
            album
            year
            label
            genres
            coverUrl
            source
          }
        }
        """

        let variables: [String: Any] = [
            "artist": artist,
            "album": album
        ]

        let response: Response = try await execute(
            operationName: "AlbumByArtistAndTitle",
            query: query,
            variables: variables
        )

        return response.albumByArtistAndTitle
    }

    /// Fetches album metadata by barcode (UPC)
    /// - Parameter barcode: The barcode/UPC
    /// - Returns: AlbumData if found, nil otherwise
    func fetchAlbumByBarcode(barcode: String) async throws -> AlbumData? {
        struct Response: Decodable {
            let albumByBarcode: AlbumData?
        }

        let query = """
        query AlbumByBarcode($barcode: String!) {
          albumByBarcode(barcode: $barcode) {
            artist
            album
            year
            label
            genres
            coverUrl
            source
          }
        }
        """

        let variables: [String: Any] = ["barcode": barcode]

        let response: Response = try await execute(
            operationName: "AlbumByBarcode",
            query: query,
            variables: variables
        )

        return response.albumByBarcode
    }

    /// Fetches movie metadata by barcode (UPC)
    /// - Parameter barcode: The barcode/UPC
    /// - Returns: MovieData if found, nil otherwise
    /// - Note: This is currently not implemented on the backend
    func fetchMovieByBarcode(barcode: String) async throws -> MovieData? {
        struct Response: Decodable {
            let movieByBarcode: MovieData?
        }

        let query = """
        query MovieByBarcode($barcode: String!) {
          movieByBarcode(barcode: $barcode) {
            title
            year
            director
            genre
            posterUrl
            plot
            source
          }
        }
        """

        let variables: [String: Any] = ["barcode": barcode]

        let response: Response = try await execute(
            operationName: "MovieByBarcode",
            query: query,
            variables: variables
        )

        return response.movieByBarcode
    }

    // MARK: - List Queries

    /// Movie record from database
    struct Movie: Decodable {
        let id: String
        let title: String
        let director: String?
        let year: Int?
        let genre: String?
        let coverUrl: String?
        let createdAt: String?
        let updatedAt: String?

        var coverURL: String? { coverUrl }
    }

    /// Album record from database
    struct Album: Decodable {
        let id: String
        let artist: String
        let album: String
        let year: Int?
        let label: String?
        let genres: [String]?
        let coverUrl: String?
        let createdAt: String?
        let updatedAt: String?

        var coverURL: String? { coverUrl }
    }

    /// Fetches all movies from the database
    /// - Returns: Array of Movie records
    func fetchMovies() async throws -> [Movie] {
        struct Response: Decodable {
            let movies: [Movie]
        }

        let query = """
        query GetMovies {
          movies {
            id
            title
            director
            year
            genre
            coverUrl
            createdAt
            updatedAt
          }
        }
        """

        let response: Response = try await execute(
            operationName: "GetMovies",
            query: query
        )

        return response.movies
    }

    /// Fetches all albums from the database
    /// - Returns: Array of Album records
    func fetchAlbums() async throws -> [Album] {
        struct Response: Decodable {
            let albums: [Album]
        }

        let query = """
        query GetAlbums {
          albums {
            id
            artist
            album
            year
            label
            genres
            coverUrl
            createdAt
            updatedAt
          }
        }
        """

        let response: Response = try await execute(
            operationName: "GetAlbums",
            query: query
        )

        return response.albums
    }

    /// Checks if the API is healthy and reachable
    /// - Returns: true if the API is healthy, false otherwise
    func checkHealth() async -> Bool {
        struct HealthResponse: Decodable {
            let health: Health
        }

        struct Health: Decodable {
            let status: String
            let version: String
            let uptime: Int
        }

        let query = """
        query Health {
          health {
            status
            version
            uptime
          }
        }
        """

        do {
            let response: HealthResponse = try await execute(
                operationName: "Health",
                query: query
            )

            #if DEBUG
            print("[MediaClosetAPIClient] Health check: \(response.health.status)")
            print("[MediaClosetAPIClient] Server version: \(response.health.version)")
            print("[MediaClosetAPIClient] Server uptime: \(response.health.uptime)s")
            #endif

            return response.health.status == "ok"
        } catch {
            #if DEBUG
            print("[MediaClosetAPIClient] Health check failed: \(error)")
            #endif
            return false
        }
    }
}
