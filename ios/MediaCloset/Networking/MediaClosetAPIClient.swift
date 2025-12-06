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
        var headers = [
            "Content-Type": "application/json",
            "User-Agent": "MediaCloset-iOS/1.0"
        ]

        // Add API key if available
        if let apiKey = secretsManager.mediaClosetAPIKey {
            headers["X-API-Key"] = apiKey
        } else {
            #if DEBUG
            print("[MediaClosetAPIClient] WARNING: No MediaCloset API key available, request may fail")
            #endif
        }

        return headers
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
    ///   - colorVariants: Optional color variants array
    ///   - genres: Optional genres array
    ///   - coverUrl: Optional cover URL (will be auto-fetched if not provided)
    /// - Returns: SaveAlbumResponse with success status and saved album data
    func saveAlbum(artist: String, album: String, year: Int? = nil, label: String? = nil, colorVariants: [String]? = nil, genres: [String]? = nil, coverUrl: String? = nil) async throws -> SaveAlbumResponse {
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
              color_variants
              genres
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
        if let colorVariants = colorVariants, !colorVariants.isEmpty {
            input["color_variants"] = colorVariants
        }
        if let genres = genres, !genres.isEmpty {
            input["genres"] = genres
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
        let color_variants: [String]?
        let genres: [String]?
        let coverUrl: String?

        // Convenience computed property for Swift naming conventions
        var coverURL: String? { coverUrl }
        var colorVariants: [String]? { color_variants }
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
        let color_variants: [String]?
        let genres: [String]?
        let coverUrl: String?
        let createdAt: String?
        let updatedAt: String?

        var coverURL: String? { coverUrl }
        var colorVariants: [String]? { color_variants }
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
            color_variants
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

    /// Fetches a single movie by ID
    /// - Parameter id: The movie ID
    /// - Returns: Movie if found, nil otherwise
    func fetchMovie(id: String) async throws -> Movie? {
        struct Response: Decodable {
            let movie: Movie?
        }

        let query = """
        query GetMovie($id: String!) {
          movie(id: $id) {
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

        let variables: [String: Any] = ["id": id]

        let response: Response = try await execute(
            operationName: "GetMovie",
            query: query,
            variables: variables
        )

        return response.movie
    }

    /// Fetches a single album by ID
    /// - Parameter id: The album ID
    /// - Returns: Album if found, nil otherwise
    func fetchAlbum(id: String) async throws -> Album? {
        struct Response: Decodable {
            let album: Album?
        }

        let query = """
        query GetAlbum($id: String!) {
          album(id: $id) {
            id
            artist
            album
            year
            label
            color_variants
            genres
            coverUrl
            createdAt
            updatedAt
          }
        }
        """

        let variables: [String: Any] = ["id": id]

        let response: Response = try await execute(
            operationName: "GetAlbum",
            query: query,
            variables: variables
        )

        return response.album
    }

    /// Updates an existing movie
    /// - Parameters:
    ///   - id: The movie ID
    ///   - title: Optional new title
    ///   - director: Optional new director
    ///   - year: Optional new year
    ///   - genre: Optional new genre
    ///   - coverUrl: Optional new cover URL
    /// - Returns: UpdateMovieResponse with success status and updated movie data
    func updateMovie(id: String, title: String? = nil, director: String? = nil, year: Int? = nil, genre: String? = nil, coverUrl: String? = nil) async throws -> UpdateMovieResponse {
        struct Response: Decodable {
            let updateMovie: UpdateMovieResponse
        }

        let query = """
        mutation UpdateMovie($id: String!, $input: UpdateMovieInput!) {
          updateMovie(id: $id, input: $input) {
            success
            movie {
              id
              title
              director
              year
              genre
              coverUrl
              createdAt
              updatedAt
            }
            error
          }
        }
        """

        var input: [String: Any] = [:]
        if let title = title {
            input["title"] = title
        }
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

        let variables: [String: Any] = [
            "id": id,
            "input": input
        ]

        let response: Response = try await execute(
            operationName: "UpdateMovie",
            query: query,
            variables: variables
        )

        return response.updateMovie
    }

    /// Response from updateMovie mutation
    struct UpdateMovieResponse: Decodable {
        let success: Bool
        let movie: Movie?
        let error: String?
    }

    /// Updates an existing album
    /// - Parameters:
    ///   - id: The album ID
    ///   - artist: Optional new artist
    ///   - album: Optional new album title
    ///   - year: Optional new year
    ///   - label: Optional new label
    ///   - colorVariants: Optional new color variants array
    ///   - genres: Optional new genres array
    ///   - coverUrl: Optional new cover URL
    /// - Returns: UpdateAlbumResponse with success status and updated album data
    func updateAlbum(id: String, artist: String? = nil, album: String? = nil, year: Int? = nil, label: String? = nil, colorVariants: [String]? = nil, genres: [String]? = nil, coverUrl: String? = nil) async throws -> UpdateAlbumResponse {
        struct Response: Decodable {
            let updateAlbum: UpdateAlbumResponse
        }

        let query = """
        mutation UpdateAlbum($id: String!, $input: UpdateAlbumInput!) {
          updateAlbum(id: $id, input: $input) {
            success
            album {
              id
              artist
              album
              year
              label
              color_variants
              genres
              coverUrl
              createdAt
              updatedAt
            }
            error
          }
        }
        """

        var input: [String: Any] = [:]
        if let artist = artist {
            input["artist"] = artist
        }
        if let album = album {
            input["album"] = album
        }
        if let year = year {
            input["year"] = year
        }
        if let label = label {
            input["label"] = label
        }
        if let colorVariants = colorVariants, !colorVariants.isEmpty {
            input["color_variants"] = colorVariants
        }
        if let genres = genres, !genres.isEmpty {
            input["genres"] = genres
        }
        if let coverUrl = coverUrl {
            input["coverUrl"] = coverUrl
        }

        let variables: [String: Any] = [
            "id": id,
            "input": input
        ]

        let response: Response = try await execute(
            operationName: "UpdateAlbum",
            query: query,
            variables: variables
        )

        return response.updateAlbum
    }

    /// Response from updateAlbum mutation
    struct UpdateAlbumResponse: Decodable {
        let success: Bool
        let album: Album?
        let error: String?
    }

    /// Deletes a movie by ID
    /// - Parameter id: The movie ID
    /// - Returns: DeleteResponse with success status
    func deleteMovie(id: String) async throws -> DeleteResponse {
        struct Response: Decodable {
            let deleteMovie: DeleteResponse
        }

        let query = """
        mutation DeleteMovie($id: String!) {
          deleteMovie(id: $id) {
            success
            error
          }
        }
        """

        let variables: [String: Any] = ["id": id]

        let response: Response = try await execute(
            operationName: "DeleteMovie",
            query: query,
            variables: variables
        )

        return response.deleteMovie
    }

    /// Deletes an album by ID
    /// - Parameter id: The album ID
    /// - Returns: DeleteResponse with success status
    func deleteAlbum(id: String) async throws -> DeleteResponse {
        struct Response: Decodable {
            let deleteAlbum: DeleteResponse
        }

        let query = """
        mutation DeleteAlbum($id: String!) {
          deleteAlbum(id: $id) {
            success
            error
          }
        }
        """

        let variables: [String: Any] = ["id": id]

        let response: Response = try await execute(
            operationName: "DeleteAlbum",
            query: query,
            variables: variables
        )

        return response.deleteAlbum
    }

    /// Response from delete mutations
    struct DeleteResponse: Decodable {
        let success: Bool
        let error: String?
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
