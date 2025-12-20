//
//  ViewModels/RecordsVM.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation
import UIKit
import Combine

@MainActor
final class RecordsVM: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [RecordListItem] = []
    @Published var search = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var sortField: SortField = .createdAt
    @Published var sortOrder: SortOrder = .desc

    // MARK: - Pagination State
    private var hasNextPage = true
    private var totalCount = 0
    private var currentOffset = 0
    private let pageSize = 25

    // MARK: - Debounce
    private var searchDebounceTask: Task<Void, Never>?
    private let debounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

    init() {
        // Listen for app becoming active to retry loading if there was a configuration error
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.retryLoadWithSecretRefresh()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        searchDebounceTask?.cancel()
    }

    // MARK: - Public Methods

    /// Performs initial load or refresh - clears existing data and fetches first page
    func load() async {
        await loadInitial()
    }

    /// Loads the first page of data (used for initial load and pull-to-refresh)
    func loadInitial() async {
        isLoading = true
        errorMessage = nil

        // Reset pagination state
        currentOffset = 0
        hasNextPage = true
        items = []

        defer { isLoading = false }

        do {
            let searchTerm = search.isEmpty ? nil : search
            let connection = try await MediaClosetAPIClient.shared.fetchAlbumsPaginated(
                limit: pageSize,
                offset: 0,
                sortField: sortField,
                sortOrder: sortOrder,
                search: searchTerm
            )

            items = connection.items.map { album in
                RecordListItem(
                    id: album.id,
                    artist: album.artist,
                    album: album.album,
                    year: album.year,
                    colorVariants: album.colorVariants,
                    genres: album.genres ?? [],
                    coverUrl: album.coverUrl
                )
            }

            hasNextPage = connection.pageInfo.hasNextPage
            totalCount = connection.pageInfo.totalCount
            currentOffset = items.count

            #if DEBUG
            print("[RecordsVM] Loaded \(items.count) of \(totalCount) albums, hasNextPage: \(hasNextPage)")
            #endif
        } catch {
            print("[RecordsVM] Records fetch error:", error)
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
        }
    }

    /// Loads the next page of data (for infinite scroll)
    func loadMore() async {
        guard !isLoadingMore && !isLoading && hasNextPage else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let searchTerm = search.isEmpty ? nil : search
            let connection = try await MediaClosetAPIClient.shared.fetchAlbumsPaginated(
                limit: pageSize,
                offset: currentOffset,
                sortField: sortField,
                sortOrder: sortOrder,
                search: searchTerm
            )

            let newItems = connection.items.map { album in
                RecordListItem(
                    id: album.id,
                    artist: album.artist,
                    album: album.album,
                    year: album.year,
                    colorVariants: album.colorVariants,
                    genres: album.genres ?? [],
                    coverUrl: album.coverUrl
                )
            }

            items.append(contentsOf: newItems)
            hasNextPage = connection.pageInfo.hasNextPage
            currentOffset = items.count

            #if DEBUG
            print("[RecordsVM] Loaded more: now \(items.count) of \(totalCount) albums, hasNextPage: \(hasNextPage)")
            #endif
        } catch {
            print("[RecordsVM] Load more error:", error)
        }
    }

    /// Called when search text changes - debounces and triggers a new search
    func searchChanged() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDelay)
                await loadInitial()
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    /// Called when sort options change - triggers a new load
    func sortChanged() {
        Task {
            await loadInitial()
        }
    }

    /// Check if we should load more (called when item appears)
    func shouldLoadMore(currentItem: RecordListItem) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        // Load more when we're 5 items from the end
        return index >= items.count - 5 && hasNextPage && !isLoadingMore && !isLoading
    }

    /// Deletes an album by ID
    func delete(id: String) async {
        do {
            let response = try await MediaClosetAPIClient.shared.deleteAlbum(id: id)
            if response.success {
                items.removeAll { $0.id == id }
                totalCount -= 1
                currentOffset = items.count
                #if DEBUG
                print("[RecordsVM] Successfully deleted album \(id)")
                #endif
            } else {
                let errorMsg = response.error ?? "Unknown error"
                print("[RecordsVM] Failed to delete album: \(errorMsg)")
            }
        } catch {
            print("[RecordsVM] Delete album error:", error)
        }
    }

    // MARK: - Private Methods

    private func retryLoadWithSecretRefresh() async {
        let secretsAvailable = SecretsManager.shared.ensureSecretsAvailable()

        #if DEBUG
        if !secretsAvailable {
            print("[RecordsVM] Secrets still not available after refresh attempt")
        } else {
            print("[RecordsVM] Secrets are now available, retrying load...")
        }
        #endif

        await load()
    }
}
