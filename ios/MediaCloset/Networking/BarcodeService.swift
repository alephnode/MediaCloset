//
//  Networking/BarcodeService.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import Foundation
import AVFoundation

struct BarcodeService {
    
    // MARK: - Public Interface
    
    /// Scans a barcode and returns the decoded string
    /// - Parameter barcodeString: The scanned barcode string
    /// - Returns: The decoded barcode value
    static func decodeBarcode(_ barcodeString: String) -> String {
        return barcodeString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Looks up album information from a barcode using MusicBrainz
    /// - Parameters:
    ///   - barcode: The barcode string (UPC/EAN)
    ///   - timeout: Request timeout in seconds (default: 5.0)
    /// - Returns: Dictionary containing album data if found, nil otherwise
    static func lookupAlbumByBarcode(_ barcode: String, timeout: TimeInterval = 5.0) async -> [String: Any]? {
        // Try multiple approaches for album barcode lookup
        
        // 1. Try MusicBrainz with exact barcode
        if let musicBrainzData = await searchReleaseByBarcode(barcode: barcode, timeout: timeout) {
            return musicBrainzData
        }
        
        // 2. Try MusicBrainz with cleaned barcode (remove leading zeros, etc.)
        let cleanedBarcode = cleanBarcode(barcode)
        if cleanedBarcode != barcode {
            if let musicBrainzData = await searchReleaseByBarcode(barcode: cleanedBarcode, timeout: timeout) {
                return musicBrainzData
            }
        }
        
        // 3. Try UPC Database as fallback
        if let upcData = await lookupFromUPCDatabase(barcode: barcode, timeout: timeout) {
            return upcData
        }
        
        #if DEBUG
        print("[BarcodeService] No album data found for barcode: \(barcode)")
        #endif
        return nil
    }
    
    /// Looks up movie information from a barcode
    /// - Parameters:
    ///   - barcode: The barcode string (UPC/EAN)
    ///   - timeout: Request timeout in seconds (default: 5.0)
    /// - Returns: Dictionary containing movie data if found, nil otherwise
    static func lookupMovieByBarcode(_ barcode: String, timeout: TimeInterval = 5.0) async -> [String: Any]? {
        // Try multiple approaches for movie barcode lookup
        
        // 1. Try UPC Database (free service)
        if let upcData = await lookupFromUPCDatabase(barcode: barcode, timeout: timeout) {
            return upcData
        }
        
        // 2. Try to extract basic info from barcode format
        if let basicData = extractBasicInfoFromBarcode(barcode) {
            return basicData
        }
        
        #if DEBUG
        print("[BarcodeService] No movie data found for barcode: \(barcode)")
        #endif
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Searches for a release using MusicBrainz API by barcode
    private static func searchReleaseByBarcode(barcode: String, timeout: TimeInterval) async -> [String: Any]? {
        // Try multiple search strategies
        let searchQueries = [
            "barcode:\(barcode)",           // Exact barcode match
            "catno:\(barcode)",             // Catalog number match
            "barcode:\"\(barcode)\"",       // Quoted barcode match
        ]
        
        for query in searchQueries {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            guard let url = URL(string: "https://musicbrainz.org/ws/2/release/?query=\(encodedQuery)&fmt=json") else {
                continue
            }
            
            if let result = await performMusicBrainzSearch(url: url, timeout: timeout) {
                return result
            }
        }
        
        return nil
    }
    
    /// Performs a single MusicBrainz search
    private static func performMusicBrainzSearch(url: URL, timeout: TimeInterval) async -> [String: Any]? {
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let releases = json["releases"] as? [[String: Any]],
                  let firstRelease = releases.first else {
                return nil
            }
            
            #if DEBUG
            print("[BarcodeService] Found release in MusicBrainz")
            #endif
            
            // Extract relevant information from the release
            var albumData: [String: Any] = [:]
            
            if let title = firstRelease["title"] as? String {
                albumData["album"] = title
            }
            
            if let date = firstRelease["date"] as? String {
                // Extract year from date (format: YYYY-MM-DD or YYYY)
                let yearString = String(date.prefix(4))
                if let year = Int(yearString) {
                    albumData["year"] = year
                }
            }
            
            // Get artist information
            if let artistCredit = firstRelease["artist-credit"] as? [[String: Any]],
               let firstArtist = artistCredit.first,
               let artist = firstArtist["artist"] as? [String: Any],
               let artistName = artist["name"] as? String {
                albumData["artist"] = artistName
            }
            
            // Get label information
            if let labelInfo = firstRelease["label-info"] as? [[String: Any]],
               let firstLabel = labelInfo.first,
               let label = firstLabel["label"] as? [String: Any],
               let labelName = label["name"] as? String {
                albumData["label"] = labelName
            }
            
            // Get catalog number
            if let catalogNumber = firstRelease["catalog-number"] as? String {
                albumData["catalog_number"] = catalogNumber
            }
            
            // Get country
            if let country = firstRelease["country"] as? String {
                albumData["country"] = country
            }
            
            // Get barcode
            if let barcode = firstRelease["barcode"] as? String {
                albumData["upc"] = barcode
            }
            
            // Get release ID for cover art lookup
            if let releaseId = firstRelease["id"] as? String {
                albumData["release_id"] = releaseId
                
                // Try to get cover art URL
                if let coverUrl = await fetchCoverArtURL(releaseId: releaseId, timeout: timeout) {
                    albumData["cover_url"] = coverUrl
                }
            }
            
            return albumData
            
        } catch {
            #if DEBUG
            print("[BarcodeService] MusicBrainz search error: \(error)")
            #endif
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
            #if DEBUG
            print("[BarcodeService] Cover art error: \(error)")
            #endif
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
            #if DEBUG
            print("[BarcodeService] Cover art metadata error: \(error)")
            #endif
            return nil
        }
    }
    
    /// Looks up product information from UPC Database
    private static func lookupFromUPCDatabase(barcode: String, timeout: TimeInterval) async -> [String: Any]? {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(barcode)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let firstItem = items.first else {
                return nil
            }
            
            var movieData: [String: Any] = [:]
            
            if let title = firstItem["title"] as? String {
                movieData["Title"] = title
            }
            
            if let brand = firstItem["brand"] as? String {
                movieData["Brand"] = brand
            }
            
            if let category = firstItem["category"] as? String {
                movieData["Category"] = category
            }
            
            if let description = firstItem["description"] as? String {
                movieData["Description"] = description
            }
            
            if let image = firstItem["images"] as? [String], let firstImage = image.first {
                movieData["Poster"] = firstImage
            }
            
            #if DEBUG
            print("[BarcodeService] Found UPC data for barcode: \(barcode)")
            #endif
            
            return movieData
            
        } catch {
            #if DEBUG
            print("[BarcodeService] UPC Database lookup error: \(error)")
            #endif
            return nil
        }
    }
    
    /// Extracts basic information from barcode format
    private static func extractBasicInfoFromBarcode(_ barcode: String) -> [String: Any]? {
        // For now, just return the barcode as a reference
        // This could be enhanced to extract more information from known barcode formats
        return [
            "Barcode": barcode,
            "Note": "Barcode scanned - please enter movie details manually"
        ]
    }
    
    /// Cleans barcode by removing leading zeros and formatting
    private static func cleanBarcode(_ barcode: String) -> String {
        // Remove leading zeros
        let cleaned = barcode.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        
        // If we removed everything, return original
        if cleaned.isEmpty {
            return barcode
        }
        
        return cleaned
    }
}
