//
//  Networking/BarcodeResponseParser.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/16/25.
//

import Foundation

struct BarcodeResponseParser {
    
    // MARK: - Parsing Methods
    
    /// Parse generic UPC/product data into album-appropriate format
    static func parseGenericProductData(_ data: [String: Any]) -> ImprovedBarcodeService.AlbumData? {
        // Extract basic product information
        guard let title = data["title"] as? String ?? data["Title"] as? String else {
            return nil
        }
        
        let brand = data["brand"] as? String ?? data["Brand"] as? String
        let description = data["description"] as? String ?? data["Description"] as? String
        let category = data["category"] as? String ?? data["Category"] as? String
        
        // Try to intelligently parse album information from product data
        var artist: String?
        var album: String?
        var year: Int?
        
        // Strategy 1: Look for music-related keywords in category
        if let category = category?.lowercased(), 
           category.contains("music") || category.contains("cd") || category.contains("album") || category.contains("vinyl") {
            
            // Try to parse "Artist - Album" format from title
            if title.contains(" - ") {
                let components = title.components(separatedBy: " - ")
                if components.count >= 2 {
                    artist = components[0].trimmingCharacters(in: .whitespaces)
                    album = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else {
                // Use brand as artist if it seems reasonable, title as album
                if let brand = brand, !isGenericBrand(brand) {
                    artist = brand
                    album = title
                } else {
                    album = title
                }
            }
        } else {
            // Not obviously a music product, return nil
            return nil
        }
        
        // Try to extract year from title or description
        year = extractYear(from: title) ?? extractYear(from: description)
        
        // Extract cover image
        var coverUrl: String?
        if let images = data["images"] as? [String], let firstImage = images.first {
            coverUrl = firstImage
        } else if let image = data["image"] as? String {
            coverUrl = image
        }
        
        return ImprovedBarcodeService.AlbumData(
            artist: artist,
            album: album,
            year: year,
            label: nil,
            genres: category != nil ? [category!] : nil,
            coverUrl: coverUrl,
            tracks: nil
        )
    }
    
    /// Parse MusicBrainz response with enhanced error handling
    static func parseMusicBrainzResponse(_ data: [String: Any]) -> ImprovedBarcodeService.AlbumData? {
        guard let releases = data["releases"] as? [[String: Any]],
              let firstRelease = releases.first else {
            return nil
        }
        
        let album = firstRelease["title"] as? String
        let date = firstRelease["date"] as? String
        let barcode = firstRelease["barcode"] as? String
        
        // Extract year from date
        var year: Int?
        if let date = date, date.count >= 4 {
            year = Int(String(date.prefix(4)))
        }
        
        // Extract artist with fallback options
        var artist: String?
        if let artistCredit = firstRelease["artist-credit"] as? [[String: Any]] {
            // Try to get the main artist
            for artistEntry in artistCredit {
                if let artistInfo = artistEntry["artist"] as? [String: Any],
                   let artistName = artistInfo["name"] as? String {
                    artist = artistName
                    break
                }
            }
        }
        
        // Extract label information
        var label: String?
        if let labelInfo = firstRelease["label-info"] as? [[String: Any]] {
            for labelEntry in labelInfo {
                if let labelData = labelEntry["label"] as? [String: Any],
                   let labelName = labelData["name"] as? String {
                    label = labelName
                    break
                }
            }
        }
        
        return ImprovedBarcodeService.AlbumData(
            artist: artist,
            album: album,
            year: year,
            label: label,
            genres: nil,
            coverUrl: nil,
            tracks: nil
        )
    }
    
    /// Parse iTunes/Apple Music response
    static func parseiTunesResponse(_ data: [String: Any]) -> ImprovedBarcodeService.AlbumData? {
        guard let results = data["results"] as? [[String: Any]],
              let firstResult = results.first else {
            return nil
        }
        
        let artist = firstResult["artistName"] as? String
        let album = firstResult["collectionName"] as? String
        let releaseDate = firstResult["releaseDate"] as? String
        let genre = firstResult["primaryGenreName"] as? String
        let coverUrl = firstResult["artworkUrl100"] as? String
        
        // Extract year from release date (format: "2023-05-15T07:00:00Z")
        var year: Int?
        if let releaseDate = releaseDate {
            year = extractYear(from: releaseDate)
        }
        
        return ImprovedBarcodeService.AlbumData(
            artist: artist,
            album: album,
            year: year,
            label: nil,
            genres: genre != nil ? [genre!] : nil,
            coverUrl: coverUrl?.replacingOccurrences(of: "100x100", with: "600x600"),
            tracks: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private static func isGenericBrand(_ brand: String) -> Bool {
        let genericBrands = [
            "unknown", "generic", "various", "various artists",
            "n/a", "not available", "tbd", "compilation"
        ]
        
        return genericBrands.contains(brand.lowercased())
    }
    
    private static func extractYear(from text: String?) -> Int? {
        guard let text = text else { return nil }
        
        // Look for 4-digit years (1900-2099)
        let yearRegex = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = yearRegex?.firstMatch(in: text, options: [], range: range) {
            let yearString = String(text[Range(match.range, in: text)!])
            return Int(yearString)
        }
        
        return nil
    }
    
    /// Validate that parsed data contains meaningful music information
    static func validateAlbumData(_ albumData: ImprovedBarcodeService.AlbumData) -> Bool {
        // Require at least artist OR album to be present
        guard albumData.artist != nil || albumData.album != nil else {
            return false
        }
        
        // Check for obviously non-music content
        let nonMusicKeywords = ["software", "hardware", "electronics", "book", "dvd", "video game"]
        
        let textToCheck = [albumData.artist, albumData.album].compactMap { $0 }.joined(separator: " ").lowercased()
        
        for keyword in nonMusicKeywords {
            if textToCheck.contains(keyword) {
                return false
            }
        }
        
        return true
    }
}