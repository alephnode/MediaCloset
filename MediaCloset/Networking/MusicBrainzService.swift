//
//  Networking/MusicBrainzService.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import Foundation

struct MusicBrainzService {
    
    // MARK: - Public Interface
    
    /// Fetches album art URL from MusicBrainz cover art API
    /// - Parameters:
    ///   - artist: The artist name
    ///   - album: The album title
    ///   - timeout: Request timeout in seconds (default: 3.0)
    /// - Returns: The cover art URL if found, nil otherwise
    static func fetchAlbumArtURL(artist: String, album: String, timeout: TimeInterval = 3.0) async -> String? {
        // First, search for the release using the MusicBrainz API
        guard let releaseId = await searchRelease(artist: artist, album: album, timeout: timeout) else {
            return nil
        }
        
        // Then fetch the cover art URL using the cover art API
        return await fetchCoverArtURL(releaseId: releaseId, timeout: timeout)
    }
    
    // MARK: - Private Methods
    
    /// Searches for a release using MusicBrainz API
    private static func searchRelease(artist: String, album: String, timeout: TimeInterval) async -> String? {
        // Create search query URL
        let query = "release:\"\(album)\" AND artist:\"\(artist)\""
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://musicbrainz.org/ws/2/release/?query=\(encodedQuery)&fmt=json") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let releases = json["releases"] as? [[String: Any]],
                  let firstRelease = releases.first,
                  let releaseId = firstRelease["id"] as? String else {
                return nil
            }
            
            return releaseId
        } catch {
            print("MusicBrainz search error: \(error)")
            return nil
        }
    }
    
    /// Fetches cover art URL from MusicBrainz cover art API
    private static func fetchCoverArtURL(releaseId: String, timeout: TimeInterval) async -> String? {
        guard let url = URL(string: "https://coverartarchive.org/release/\(releaseId)/front") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if we got a successful response
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let imageUrl = httpResponse.url?.absoluteString {
                return imageUrl
            }
            
            // If direct image request fails, try the metadata API
            return await fetchCoverArtFromMetadata(releaseId: releaseId, timeout: timeout)
            
        } catch {
            print("MusicBrainz cover art error: \(error)")
            return nil
        }
    }
    
    /// Fetches cover art URL from MusicBrainz cover art metadata API
    private static func fetchCoverArtFromMetadata(releaseId: String, timeout: TimeInterval) async -> String? {
        guard let url = URL(string: "https://coverartarchive.org/release/\(releaseId)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let images = json["images"] as? [[String: Any]],
                  let firstImage = images.first,
                  let imageUrl = firstImage["image"] as? String else {
                return nil
            }
            
            return imageUrl
        } catch {
            print("MusicBrainz metadata error: \(error)")
            return nil
        }
    }
}
