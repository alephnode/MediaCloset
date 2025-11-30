//
//  Networking/OMDBService.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//

import Foundation

struct OMDBService {
    
    // MARK: - Public Interface
    
    /// Fetches movie poster URL from OMDB API
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: The director name (optional, helps with disambiguation)
    ///   - year: The release year (optional, helps with disambiguation)
    ///   - timeout: Request timeout in seconds (default: 3.0)
    /// - Returns: The poster URL if found, nil otherwise
    static func fetchMoviePosterURL(title: String, director: String? = nil, year: Int? = nil, timeout: TimeInterval = 3.0) async -> String? {
        // First, search for the movie using the OMDB API
        guard let movieData = await searchMovie(title: title, director: director, year: year, timeout: timeout) else {
            return nil
        }
        
        // Extract poster URL from the response
        return movieData["Poster"] as? String
    }
    
    /// Fetches complete movie data from OMDB API
    /// - Parameters:
    ///   - title: The movie title
    ///   - director: The director name (optional, helps with disambiguation)
    ///   - year: The release year (optional, helps with disambiguation)
    ///   - timeout: Request timeout in seconds (default: 3.0)
    /// - Returns: Dictionary containing movie data if found, nil otherwise
    static func fetchMovieData(title: String, director: String? = nil, year: Int? = nil, timeout: TimeInterval = 3.0) async -> [String: Any]? {
        return await searchMovie(title: title, director: director, year: year, timeout: timeout)
    }
    
    // MARK: - Private Methods
    
    /// Searches for a movie using OMDB API
    private static func searchMovie(title: String, director: String?, year: Int?, timeout: TimeInterval) async -> [String: Any]? {
        // Get API key from SecretsManager
        guard let apiKey = SecretsManager.shared.omdbApiKey else {
            #if DEBUG
            print("[OMDBService] No API key available")
            #endif
            return nil
        }
        
        #if DEBUG
        print("[OMDBService] Searching for movie: '\(title)' with director: '\(director ?? "none")' and year: \(year?.description ?? "none")")
        print("[OMDBService] Using API key: \(String(apiKey.prefix(8)))...")
        #endif
        
        // URL encode the title
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // Build URL with API key and title
        var urlString = "https://www.omdbapi.com/?apikey=\(apiKey)&t=\(encodedTitle)&plot=short"
        
        // Add year parameter if provided
        if let year = year {
            urlString += "&y=\(year)"
        }
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("[OMDBService] Failed to create URL: \(urlString)")
            #endif
            return nil
        }
        
        #if DEBUG
        print("[OMDBService] Making request to: \(urlString)")
        #endif
        
        var request = URLRequest(url: url)
        request.setValue("MediaCloset/1.0 (https://github.com/yourusername/mediacloset)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("[OMDBService] HTTP Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[OMDBService] Raw response: \(responseString)")
            }
            #endif
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                print("[OMDBService] Failed to parse JSON response")
                #endif
                return nil
            }
            
            // Check for API errors
            if let response = json["Response"] as? String, response == "False" {
                if let error = json["Error"] as? String {
                    #if DEBUG
                    print("[OMDBService] API Error: \(error)")
                    #endif
                }
                return nil
            }
            
            #if DEBUG
            print("[OMDBService] Successfully parsed movie data for: \(json["Title"] as? String ?? "Unknown")")
            #endif
            
            // If director was provided, try to match it for better accuracy
            if let providedDirector = director, !providedDirector.isEmpty {
                if let movieDirector = json["Director"] as? String {
                    // Simple director matching - could be improved with fuzzy matching
                    if !movieDirector.lowercased().contains(providedDirector.lowercased()) &&
                       !providedDirector.lowercased().contains(movieDirector.lowercased()) {
                        #if DEBUG
                        print("[OMDBService] Director mismatch: expected '\(providedDirector)', got '\(movieDirector)'")
                        #endif
                        // Still return the result, but log the mismatch
                    }
                }
            }
            
            return json
            
        } catch {
            #if DEBUG
            print("[OMDBService] Network error: \(error)")
            #endif
            return nil
        }
    }
}
