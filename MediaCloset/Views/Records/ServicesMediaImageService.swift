//
//  Services/MediaImageService.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/25/25.
//

import Foundation
import SwiftUI

/// Service responsible for fetching and caching media cover images from various APIs
@MainActor
final class MediaImageService: ObservableObject {
    
    // MARK: - Properties
    
    private let imageCache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared
    private var activeTasks: [String: Task<UIImage?, Error>] = [:]
    
    // MARK: - Public Interface
    
    /// Fetch cover image for a media item, trying multiple APIs with fallback
    func fetchCoverImage(for mediaItem: MediaItem) async throws -> UIImage? {
        let cacheKey = generateCacheKey(for: mediaItem)
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Check for existing task to prevent duplicate requests
        if let existingTask = activeTasks[cacheKey] {
            return try await existingTask.value
        }
        
        // Create new fetch task
        let task = Task<UIImage?, Error> {
            defer { activeTasks.removeValue(forKey: cacheKey) }
            
            // Try APIs in order of preference/quality
            let apiStrategies: [APIStrategy] = [
                SpotifyAPIStrategy(),
                DiscogsAPIStrategy(),
                LastFMAPIStrategy(),
                iTunesAPIStrategy(),
                MusicBrainzAPIStrategy()
            ]
            
            for strategy in apiStrategies {
                if await strategy.isAvailable() {
                    do {
                        if let imageURL = try await strategy.fetchImageURL(for: mediaItem) {
                            let image = try await downloadImage(from: imageURL)
                            
                            // Cache the result
                            imageCache.setObject(image, forKey: cacheKey as NSString)
                            
                            // Store in database for persistence
                            await persistImageReference(imageURL: imageURL, for: mediaItem)
                            
                            return image
                        }
                    } catch {
                        print("Failed to fetch from \(strategy.serviceName): \(error)")
                        // Continue to next API
                    }
                    
                    // Rate limiting between API calls
                    try await Task.sleep(nanoseconds: UInt64(APIConfig.requestDelay * 1_000_000_000))
                }
            }
            
            return nil // No image found from any service
        }
        
        activeTasks[cacheKey] = task
        return try await task.value
    }
    
    // MARK: - Private Helpers
    
    private func generateCacheKey(for mediaItem: MediaItem) -> String {
        return "\(mediaItem.artist)-\(mediaItem.title)-\(mediaItem.year ?? 0)"
    }
    
    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await session.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw MediaImageError.invalidImageData
        }
        
        return image
    }
    
    private func persistImageReference(imageURL: URL, for mediaItem: MediaItem) async {
        // Update your database with the image URL
        // This depends on your data persistence layer (Core Data, SwiftData, etc.)
        mediaItem.coverImageURL = imageURL.absoluteString
        // Save context here
    }
}

// MARK: - API Strategy Protocol

protocol APIStrategy {
    var serviceName: String { get }
    func isAvailable() async -> Bool
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL?
}

// MARK: - API Strategy Implementations

struct SpotifyAPIStrategy: APIStrategy {
    let serviceName = "Spotify"
    
    func isAvailable() async -> Bool {
        return APIConfig.Spotify.isConfigured
    }
    
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL? {
        // Implement Spotify API call
        // Return the cover image URL if found
        return nil
    }
}

struct DiscogsAPIStrategy: APIStrategy {
    let serviceName = "Discogs"
    
    func isAvailable() async -> Bool {
        return APIConfig.Discogs.isConfigured
    }
    
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL? {
        // Implement Discogs API call
        return nil
    }
}

struct LastFMAPIStrategy: APIStrategy {
    let serviceName = "Last.fm"
    
    func isAvailable() async -> Bool {
        return APIConfig.LastFM.isConfigured
    }
    
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL? {
        // Implement Last.fm API call
        return nil
    }
}

struct iTunesAPIStrategy: APIStrategy {
    let serviceName = "iTunes"
    
    func isAvailable() async -> Bool {
        return true // Always available
    }
    
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL? {
        // Implement iTunes Search API call
        return nil
    }
}

struct MusicBrainzAPIStrategy: APIStrategy {
    let serviceName = "MusicBrainz"
    
    func isAvailable() async -> Bool {
        return true // Always available
    }
    
    func fetchImageURL(for mediaItem: MediaItem) async throws -> URL? {
        // Implement MusicBrainz API call
        return nil
    }
}

// MARK: - Errors

enum MediaImageError: LocalizedError {
    case invalidImageData
    case noImageFound
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data received"
        case .noImageFound:
            return "No cover image found for this media"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - MediaItem Protocol (Placeholder)

protocol MediaItem {
    var artist: String { get }
    var title: String { get }
    var year: Int? { get }
    var coverImageURL: String? { get set }
}