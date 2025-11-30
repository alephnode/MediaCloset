//
//  ViewModels/RecordsVM.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation
import UIKit

@MainActor
final class RecordsVM: ObservableObject {
    @Published var items: [RecordListItem] = []
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
            print("[RecordsVM] Secrets still not available after refresh attempt")
        } else {
            print("[RecordsVM] Secrets are now available, retrying load...")
        }
        #endif
        
        // Always retry loading
        await load()
    }

    func load() async {
        isLoading = true;
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Fetch albums from MediaCloset Go API
            let albums = try await MediaClosetAPIClient.shared.fetchAlbums()

            // Filter by search text if provided
            let filteredAlbums = search.isEmpty ? albums : albums.filter { album in
                album.artist.localizedCaseInsensitiveContains(search) ||
                album.album.localizedCaseInsensitiveContains(search) ||
                (album.genres?.contains { $0.localizedCaseInsensitiveContains(search) } ?? false)
            }

            // Convert to RecordListItem
            items = filteredAlbums.map { album in
                RecordListItem(
                    id: album.id,
                    artist: album.artist,
                    album: album.album,
                    year: album.year,
                    colorVariant: album.label, // Using label field for color variant
                    genres: album.genres ?? [],
                    coverUrl: album.coverURL
                )
            }

            #if DEBUG
            print("[RecordsVM] Loaded \(albums.count) albums from MediaCloset API, filtered to \(items.count)")
            #endif
        } catch {
            print("[RecordsVM] Records fetch error:", error)
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
        }
    }


    func delete(id: String) async {
        do {
            _ = try await GraphQLHTTPClient.shared.execute(
                operationName: "DeleteRecord",
                query: GQL.deleteRecord,
                variables: ["id": id] as [String: Any]
            )
            items.removeAll { $0.id == id }
        } catch {
            print("Delete error:", error)
        }
    }
}

