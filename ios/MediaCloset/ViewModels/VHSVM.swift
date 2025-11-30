//
//  ViewModels/VHSVM.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation
import UIKit

@MainActor
final class VHSVM: ObservableObject {
    @Published var items: [VHSListItem] = []
    @Published var search = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    init() {
        // Listen for app becoming active to retry loading if there was a configuration error
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Always retry loading when app becomes active, especially if there was an error
            Task {
                await self?.retryLoadWithSecretRefresh()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Retries loading with secret refresh if there was a configuration error
    private func retryLoadWithSecretRefresh() async {
        // Always ensure secrets are available before retrying
        let secretsAvailable = SecretsManager.shared.ensureSecretsAvailable()
        
        #if DEBUG
        if !secretsAvailable {
            print("[VHSVM] Secrets still not available after refresh attempt")
        } else {
            print("[VHSVM] Secrets are now available, retrying load...")
        }
        #endif
        
        // Always retry loading
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Always provide a non-nil string for $pattern
        let pattern = search.isEmpty ? "%%" : "%\(search)%"

        let vars: [String: Any] = [
            "pattern": pattern,
            "limit": 50,
            "offset": 0
        ]

        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "VHSList",
                query: GQL.queryVHSList,
                variables: vars
            )

            guard let rows = res.data?["vhs"] as? [[String: Any]] else { 
                errorMessage = "No data received from server"
                return 
            }

            self.items = rows.map { r in
                VHSListItem(
                    id: r["id"] as? String ?? UUID().uuidString,
                    title: r["title"] as? String ?? "",
                    director: (r["director"] as? String) ?? "",
                    year: r["year"] as? Int,
                    genre: r["genre"] as? String,
                    coverUrl: r["cover_url"] as? String
                )
            }
        } catch {
            print("VHS fetch error:", error)
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String) async {
        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "DeleteVHS",
                query: GQL.deleteVHS,
                variables: ["id": id]
            )
            self.items.removeAll { $0.id == id }
        } catch {
            print("Delete VHS error:", error)
        }
    }
    
    /// Fetches movie data from OMDB API
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: The director name (optional, helps with disambiguation)
    ///   - year: The release year (optional, helps with disambiguation)
    /// - Returns: Dictionary containing movie data if found, nil otherwise
    func fetchMovieData(title: String, director: String? = nil, year: Int? = nil) async -> [String: Any]? {
        return await OMDBService.fetchMovieData(title: title, director: director, year: year)
    }
    
    /// Fetches movie poster URL from OMDB API
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: The director name (optional, helps with disambiguation)
    ///   - year: The release year (optional, helps with disambiguation)
    /// - Returns: The poster URL if found, nil otherwise
    func fetchMoviePosterURL(title: String, director: String? = nil, year: Int? = nil) async -> String? {
        return await OMDBService.fetchMoviePosterURL(title: title, director: director, year: year)
    }
    
    #if DEBUG
    /// Test function to debug OMDB API calls
    func testOMDBAPI() async {
        print("[VHSVM] Testing OMDB API...")
        
        // Test with Theodore Rex
        let movieData = await OMDBService.fetchMovieData(title: "Theodore Rex")
        if let data = movieData {
            print("[VHSVM] ✅ Successfully fetched Theodore Rex data:")
            print("  Title: \(data["Title"] as? String ?? "N/A")")
            print("  Year: \(data["Year"] as? String ?? "N/A")")
            print("  Director: \(data["Director"] as? String ?? "N/A")")
            print("  Poster: \(data["Poster"] as? String ?? "N/A")")
        } else {
            print("[VHSVM] ❌ Failed to fetch Theodore Rex data")
        }
        
        // Test with The Matrix
        let matrixData = await OMDBService.fetchMovieData(title: "The Matrix", year: 1999)
        if let data = matrixData {
            print("[VHSVM] ✅ Successfully fetched The Matrix data:")
            print("  Title: \(data["Title"] as? String ?? "N/A")")
            print("  Year: \(data["Year"] as? String ?? "N/A")")
            print("  Director: \(data["Director"] as? String ?? "N/A")")
            print("  Poster: \(data["Poster"] as? String ?? "N/A")")
        } else {
            print("[VHSVM] ❌ Failed to fetch The Matrix data")
        }
    }
    #endif
}
