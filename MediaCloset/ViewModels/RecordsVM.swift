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

        // Always send a non-null pattern; "%%" matches all
        let pattern = search.isEmpty ? "%%" : "%\(search)%"

        let vars: [String: Any] = [
            "pattern": pattern as String,
            "limit": 50 as Int,
            "offset": 0 as Int
        ]

        do {
            let res = try await GraphQLHTTPClient.shared.execute(
                operationName: "Records",
                query: GQL.queryRecords,
                variables: vars
            )
            guard let rows = res.data?["records"] as? [[String: Any]] else { return }
            items = rows.map { r in
                RecordListItem(
                    id: r["id"] as? String ?? UUID().uuidString,
                    artist: r["artist"] as? String ?? "",
                    album: r["album"] as? String ?? "",
                    year: r["year"] as? Int,
                    colorVariant: r["color_variant"] as? String,
                    genres: r["genres"] as? [String] ?? [],
                    coverUrl: r["cover_url"] as? String
                )
            }
        } catch {
            print("Records fetch error:", error)
            if case GraphQLError.configurationError(let message) = error {
                errorMessage = "Configuration Error: \(message)"
            } else {
                errorMessage = "Failed to load records: \(error.localizedDescription)"
            }
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

