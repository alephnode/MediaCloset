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

        do {
            // Fetch movies from MediaCloset Go API
            let movies = try await MediaClosetAPIClient.shared.fetchMovies()

            // Filter by search text if provided
            let filteredMovies = search.isEmpty ? movies : movies.filter { movie in
                movie.title.localizedCaseInsensitiveContains(search) ||
                (movie.director?.localizedCaseInsensitiveContains(search) ?? false)
            }

            // Convert to VHSListItem
            self.items = filteredMovies.map { movie in
                VHSListItem(
                    id: movie.id,
                    title: movie.title,
                    director: movie.director ?? "",
                    year: movie.year,
                    genre: movie.genre,
                    coverUrl: movie.coverURL
                )
            }

            #if DEBUG
            print("[VHSVM] Loaded \(movies.count) movies from MediaCloset API, filtered to \(self.items.count)")
            #endif
        } catch {
            print("[VHSVM] VHS fetch error:", error)
            errorMessage = "Failed to load movies: \(error.localizedDescription)"
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
}
