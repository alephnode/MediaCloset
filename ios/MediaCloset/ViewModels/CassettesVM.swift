//
//  ViewModels/CassettesVM.swift
//  MediaCloset
//
import Foundation
import UIKit
import Combine

@MainActor
final class CassettesVM: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [CassetteListItem] = []
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
    private var hasLoadedOnce = false

    // MARK: - Debounce
    private var searchDebounceTask: Task<Void, Never>?
    private let debounceDelay: UInt64 = 300_000_000
    private let skeletonMinDuration: UInt64 = 800_000_000

    init() {
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

    func load() async {
        if hasLoadedOnce {
            await refresh()
            return
        }
        hasLoadedOnce = true
        await loadInitial()
    }

    func loadInitial() async {
        isLoading = true
        errorMessage = nil

        currentOffset = 0
        hasNextPage = true
        items = []

        defer { isLoading = false }

        async let fetch: () = fetchFirstPage()
        async let minDelay: () = Task.sleep(nanoseconds: skeletonMinDuration)
        _ = await (fetch, try? minDelay)
    }

    func refresh() async {
        guard !isLoading else { return }
        errorMessage = nil
        currentOffset = 0
        hasNextPage = true

        await fetchFirstPage()
    }

    private func fetchFirstPage() async {
        do {
            let searchTerm = search.isEmpty ? nil : search
            let connection = try await MediaClosetAPIClient.shared.fetchCassettesPaginated(
                limit: pageSize,
                offset: 0,
                sortField: sortField,
                sortOrder: sortOrder,
                search: searchTerm
            )

            items = connection.items.map { cassette in
                CassetteListItem(
                    id: cassette.id,
                    artist: cassette.artist,
                    album: cassette.album,
                    year: cassette.year,
                    genres: cassette.genres ?? [],
                    coverUrl: cassette.coverUrl,
                    tapeType: cassette.tapeType
                )
            }

            hasNextPage = connection.pageInfo.hasNextPage
            totalCount = connection.pageInfo.totalCount
            currentOffset = items.count

            #if DEBUG
            print("[CassettesVM] Loaded \(items.count) of \(totalCount) cassettes, hasNextPage: \(hasNextPage)")
            #endif
        } catch {
            print("[CassettesVM] Cassettes fetch error:", error)
            errorMessage = "Failed to load cassettes: \(error.localizedDescription)"
        }
    }

    func loadMore() async {
        guard !isLoadingMore && !isLoading && hasNextPage else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let searchTerm = search.isEmpty ? nil : search
            let connection = try await MediaClosetAPIClient.shared.fetchCassettesPaginated(
                limit: pageSize,
                offset: currentOffset,
                sortField: sortField,
                sortOrder: sortOrder,
                search: searchTerm
            )

            let newItems = connection.items.map { cassette in
                CassetteListItem(
                    id: cassette.id,
                    artist: cassette.artist,
                    album: cassette.album,
                    year: cassette.year,
                    genres: cassette.genres ?? [],
                    coverUrl: cassette.coverUrl,
                    tapeType: cassette.tapeType
                )
            }

            items.append(contentsOf: newItems)
            hasNextPage = connection.pageInfo.hasNextPage
            currentOffset = items.count

            #if DEBUG
            print("[CassettesVM] Loaded more: now \(items.count) of \(totalCount) cassettes, hasNextPage: \(hasNextPage)")
            #endif
        } catch {
            print("[CassettesVM] Load more error:", error)
        }
    }

    func searchChanged() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDelay)
                await loadInitial()
            } catch {
                // Task was cancelled
            }
        }
    }

    func sortChanged() {
        Task {
            await loadInitial()
        }
    }

    func shouldLoadMore(currentItem: CassetteListItem) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        return index >= items.count - 5 && hasNextPage && !isLoadingMore && !isLoading
    }

    func delete(id: String) async {
        do {
            let response = try await MediaClosetAPIClient.shared.deleteCassette(id: id)
            if response.success {
                items.removeAll { $0.id == id }
                totalCount -= 1
                currentOffset = items.count
                #if DEBUG
                print("[CassettesVM] Successfully deleted cassette \(id)")
                #endif
            } else {
                let errorMsg = response.error ?? "Unknown error"
                print("[CassettesVM] Failed to delete cassette: \(errorMsg)")
            }
        } catch {
            print("[CassettesVM] Delete cassette error:", error)
        }
    }

    // MARK: - Private Methods

    private func retryLoadWithSecretRefresh() async {
        let secretsAvailable = SecretsManager.shared.ensureSecretsAvailable()

        #if DEBUG
        if !secretsAvailable {
            print("[CassettesVM] Secrets still not available after refresh attempt")
        } else {
            print("[CassettesVM] Secrets are now available, retrying load...")
        }
        #endif

        await load()
    }
}
