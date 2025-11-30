//
//  Repositories/MediaImageRepository.swift
//  MediaCloset
//
//  Alternative Repository Pattern approach
//

import Foundation
import SwiftUI

protocol MediaImageRepositoryProtocol {
    func getCoverImage(for mediaItem: MediaItem) async throws -> UIImage?
    func cacheCoverImage(_ image: UIImage, for mediaItem: MediaItem) async
}

final class MediaImageRepository: MediaImageRepositoryProtocol {
    private let remoteDataSource: MediaImageService
    private let localDataSource: LocalImageCache
    
    init(
        remoteDataSource: MediaImageService = MediaImageService(),
        localDataSource: LocalImageCache = LocalImageCache()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }
    
    func getCoverImage(for mediaItem: MediaItem) async throws -> UIImage? {
        // Try local cache first
        if let cachedImage = await localDataSource.getImage(for: mediaItem) {
            return cachedImage
        }
        
        // Fetch from remote APIs
        let image = try await remoteDataSource.fetchCoverImage(for: mediaItem)
        
        // Cache locally
        if let image = image {
            await localDataSource.cache(image, for: mediaItem)
        }
        
        return image
    }
    
    func cacheCoverImage(_ image: UIImage, for mediaItem: MediaItem) async {
        await localDataSource.cache(image, for: mediaItem)
    }
}

protocol LocalImageCache {
    func getImage(for mediaItem: MediaItem) async -> UIImage?
    func cache(_ image: UIImage, for mediaItem: MediaItem) async
}