//
//  Services/ImageCache.swift
//  MediaCloset
//
//  Image caching service with memory (NSCache) and disk persistence
//

import Foundation
import SwiftUI

/// Thread-safe image cache with memory and disk layers
actor ImageCache {
    static let shared = ImageCache()
    
    // MARK: - Memory Cache
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // MARK: - Disk Cache
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Cache configuration
    private let maxMemoryCacheSize = 50 // Max number of images in memory
    private let maxDiskCacheAgeDays = 30 // Max age for disk cache entries
    
    private init() {
        // Set up memory cache limits
        memoryCache.countLimit = maxMemoryCacheSize
        
        // Set up disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clean up old cache entries on init
        Task {
            await cleanExpiredDiskCache()
        }
    }
    
    // MARK: - Public API
    
    /// Retrieves an image from cache (memory first, then disk) or fetches from URL
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Promote to memory cache
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        // 3. Fetch from network
        guard let image = await fetchImage(from: url) else {
            return nil
        }
        
        // Store in both caches
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)
        
        return image
    }
    
    /// Preloads an image into cache without returning it
    func preload(url: URL) async {
        _ = await image(for: url)
    }
    
    /// Stores an image in both memory and disk cache
    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)
    }
    
    /// Clears all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Removes a specific image from cache
    func remove(url: URL) {
        let key = cacheKey(for: url)
        memoryCache.removeObject(forKey: key as NSString)
        let fileURL = diskURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Private Helpers
    
    /// Generates a cache key from URL (SHA256 hash of URL string)
    private func cacheKey(for url: URL) -> String {
        let urlString = url.absoluteString
        // Use a simple hash for the filename
        let hash = urlString.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return String(format: "%lx", abs(hash))
    }
    
    /// Returns the disk URL for a cache key
    private func diskURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key).appendingPathExtension("jpg")
    }
    
    /// Loads image from disk cache
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    /// Saves image to disk cache
    private func saveToDisk(image: UIImage, key: String) {
        let fileURL = diskURL(for: key)
        // Use JPEG compression for smaller file sizes
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: fileURL)
    }
    
    /// Fetches image from network
    private func fetchImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            return image
        } catch {
            print("[ImageCache] Failed to fetch image: \(error)")
            return nil
        }
    }
    
    /// Removes disk cache entries older than maxDiskCacheAgeDays
    private func cleanExpiredDiskCache() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: -maxDiskCacheAgeDays,
            to: Date()
        )!
        
        for fileURL in contents {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date,
                  modDate < expirationDate else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
