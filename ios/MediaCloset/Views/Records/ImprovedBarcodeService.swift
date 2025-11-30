//
//  Networking/ImprovedBarcodeService.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/16/25.
//

import Foundation

struct ImprovedBarcodeService {
    
    // MARK: - Album Data Structure
    
    struct AlbumData {
        let artist: String?
        let album: String?
        let year: Int?
        let label: String?
        let genres: [String]?
        let coverUrl: String?
        let tracks: [TrackData]?
        
        struct TrackData {
            let title: String
            let trackNumber: Int?
            let durationSeconds: Int?
        }
        
        // Convert to dictionary format expected by RecordFormView
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [:]
            
            if let artist = artist { dict["artist"] = artist }
            if let album = album { dict["album"] = album }
            if let year = year { dict["year"] = year }
            if let label = label { dict["label"] = label }
            if let genres = genres { dict["genres"] = genres }
            if let coverUrl = coverUrl { dict["cover_url"] = coverUrl }
            if let tracks = tracks {
                dict["tracks"] = tracks.map { track in
                    [
                        "title": track.title,
                        "track_no": track.trackNumber as Any,
                        "duration_sec": track.durationSeconds as Any
                    ]
                }
            }
            
            return dict
        }
    }
    
    // MARK: - Public Interface
    
    /// Enhanced album lookup using multiple music-specific APIs
    static func lookupAlbumByBarcode(_ barcode: String, timeout: TimeInterval = 8.0) async -> AlbumData? {
        #if DEBUG
        print("[ImprovedBarcodeService] Looking up barcode: \(barcode)")
        #endif
        
        // Try services in order of reliability for music data
        let services: [(String, (String, TimeInterval) async -> AlbumData?)] = [
            ("Discogs", lookupFromDiscogs),
            ("iTunes Search", lookupFromiTunes),
            ("Last.fm", lookupFromLastFM),
            ("MusicBrainz Enhanced", lookupFromMusicBrainzEnhanced),
            ("AudioDB", lookupFromAudioDB)
        ]
        
        for (serviceName, serviceMethod) in services {
            #if DEBUG
            print("[ImprovedBarcodeService] Trying \(serviceName)...")
            #endif
            
            if let albumData = await serviceMethod(barcode, timeout / Double(services.count)) {
                #if DEBUG
                print("[ImprovedBarcodeService] Found data from \(serviceName)")
                #endif
                return albumData
            }
        }
        
        #if DEBUG
        print("[ImprovedBarcodeService] No album data found for barcode: \(barcode)")
        #endif
        return nil
    }
    
    // MARK: - Service Implementations
    
    /// Discogs API - Excellent music database with barcode support
    private static func lookupFromDiscogs(barcode: String, timeout: TimeInterval) async -> AlbumData? {
        // Check if Discogs API credentials are configured
        guard APIConfig.Discogs.isConfigured else {
            #if DEBUG
            print("[ImprovedBarcodeService] Discogs API credentials not configured - skipping")
            #endif
            return nil
        }
        
        guard let url = URL(string: "\(APIConfig.Discogs.baseURL)/database/search?barcode=\(barcode)&type=release") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        
        // Apply configured headers (including authentication)
        for (key, value) in APIConfig.Discogs.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first else {
                return nil
            }
            
            let title = firstResult["title"] as? String
            let year = firstResult["year"] as? Int
            let label = (firstResult["label"] as? [String])?.first
            let genres = firstResult["genre"] as? [String]
            let styles = firstResult["style"] as? [String]
            let coverUrl = firstResult["cover_image"] as? String
            
            // Extract artist and album from combined title if available
            var artist: String?
            var album: String?
            
            if let title = title {
                if title.contains(" - ") {
                    let components = title.components(separatedBy: " - ")
                    if components.count >= 2 {
                        artist = components[0].trimmingCharacters(in: .whitespaces)
                        album = components[1].trimmingCharacters(in: .whitespaces)
                    }
                } else {
                    // If no separator, use the whole title as album
                    album = title
                }
            }
            
            // Combine genres and styles
            var allGenres: [String] = []
            if let genres = genres { allGenres.append(contentsOf: genres) }
            if let styles = styles { allGenres.append(contentsOf: styles) }
            
            #if DEBUG
            print("[ImprovedBarcodeService] Discogs found: \(title ?? "Unknown")")
            #endif
            
            return AlbumData(
                artist: artist,
                album: album,
                year: year,
                label: label,
                genres: allGenres.isEmpty ? nil : Array(Set(allGenres)), // Remove duplicates
                coverUrl: coverUrl,
                tracks: nil
            )
            
        } catch {
            #if DEBUG
            print("[ImprovedBarcodeService] Discogs error: \(error)")
            #endif
            return nil
        }
    }
    
    /// iTunes Search API - Apple's music database
    private static func lookupFromiTunes(barcode: String, timeout: TimeInterval) async -> AlbumData? {
        // iTunes doesn't directly support barcode search, but we can try UPC as a term
        guard let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedBarcode)&entity=album&limit=5") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first else {
                return nil
            }
            
            let artist = firstResult["artistName"] as? String
            let album = firstResult["collectionName"] as? String
            let releaseDate = firstResult["releaseDate"] as? String
            let genre = firstResult["primaryGenreName"] as? String
            let coverUrl = firstResult["artworkUrl100"] as? String
            
            // Extract year from release date
            var year: Int?
            if let releaseDate = releaseDate {
                let yearString = String(releaseDate.prefix(4))
                year = Int(yearString)
            }
            
            return AlbumData(
                artist: artist,
                album: album,
                year: year,
                label: nil,
                genres: genre != nil ? [genre!] : nil,
                coverUrl: coverUrl?.replacingOccurrences(of: "100x100", with: "600x600"),
                tracks: nil
            )
            
        } catch {
            #if DEBUG
            print("[ImprovedBarcodeService] iTunes error: \(error)")
            #endif
            return nil
        }
    }
    
    /// Last.fm API - Music database with extensive metadata
    private static func lookupFromLastFM(barcode: String, timeout: TimeInterval) async -> AlbumData? {
        // Note: Last.fm doesn't have direct barcode search, but this shows the pattern
        // You'd need to implement a two-step process: barcode -> album title -> Last.fm search
        
        // For now, return nil as Last.fm requires additional implementation
        return nil
    }
    
    /// Enhanced MusicBrainz with better error handling and data extraction
    private static func lookupFromMusicBrainzEnhanced(barcode: String, timeout: TimeInterval) async -> AlbumData? {
        let searchQueries = [
            "barcode:\(barcode)",
            "catno:\(barcode)",
            cleanBarcode(barcode)
        ]
        
        for query in searchQueries {
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://musicbrainz.org/ws/2/release/?query=\(encodedQuery)&fmt=json&inc=artists+labels+recordings") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = timeout / Double(searchQueries.count)
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let releases = json["releases"] as? [[String: Any]],
                      let firstRelease = releases.first else {
                    continue
                }
                
                let album = firstRelease["title"] as? String
                let date = firstRelease["date"] as? String
                let country = firstRelease["country"] as? String
                let releaseBarcode = firstRelease["barcode"] as? String
                
                // Extract year from date
                var year: Int?
                if let date = date, date.count >= 4 {
                    year = Int(String(date.prefix(4)))
                }
                
                // Extract artist
                var artist: String?
                if let artistCredit = firstRelease["artist-credit"] as? [[String: Any]],
                   let firstArtist = artistCredit.first,
                   let artistInfo = firstArtist["artist"] as? [String: Any] {
                    artist = artistInfo["name"] as? String
                }
                
                // Extract label
                var label: String?
                if let labelInfo = firstRelease["label-info"] as? [[String: Any]],
                   let firstLabel = labelInfo.first,
                   let labelData = firstLabel["label"] as? [String: Any] {
                    label = labelData["name"] as? String
                }
                
                // Get cover art
                var coverUrl: String?
                if let releaseId = firstRelease["id"] as? String {
                    coverUrl = await fetchMusicBrainzCoverArt(releaseId: releaseId, timeout: timeout / 2)
                }
                
                return AlbumData(
                    artist: artist,
                    album: album,
                    year: year,
                    label: label,
                    genres: nil,
                    coverUrl: coverUrl,
                    tracks: nil
                )
                
            } catch {
                #if DEBUG
                print("[ImprovedBarcodeService] MusicBrainz enhanced error: \(error)")
                #endif
                continue
            }
        }
        
        return nil
    }
    
    /// AudioDB - Alternative music database
    private static func lookupFromAudioDB(barcode: String, timeout: TimeInterval) async -> AlbumData? {
        // AudioDB doesn't have direct barcode search in the free tier
        // This would require a two-step process or paid tier
        return nil
    }
    
    // MARK: - Helper Methods
    
    private static func fetchMusicBrainzCoverArt(releaseId: String, timeout: TimeInterval) async -> String? {
        guard let url = URL(string: "https://coverartarchive.org/release/\(releaseId)/front") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let imageUrl = httpResponse.url?.absoluteString {
                return imageUrl
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private static func cleanBarcode(_ barcode: String) -> String {
        // Remove leading zeros and clean up barcode format
        var cleaned = barcode.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        
        if cleaned.isEmpty {
            return barcode
        }
        
        return cleaned
    }
}
