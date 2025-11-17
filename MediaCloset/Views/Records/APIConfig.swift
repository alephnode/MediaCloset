//
//  Configuration/APIConfig.swift
//  MediaCloset
//
//  Created by Stephen Ward on 11/16/25.
//

import Foundation

struct APIConfig {
    
    // MARK: - API Keys and Configuration
    
    /// Discogs API configuration
    /// To get better results, register for a free Discogs API key at:
    /// https://www.discogs.com/developers/#page:authentication
    struct Discogs {
        static let consumerKey = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_KEY"] as? String ?? ""
        static let consumerSecret = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_SECRET"] as? String ?? ""
        static let baseURL = "https://api.discogs.com"
        
        static var isConfigured: Bool {
            return !consumerKey.isEmpty && !consumerSecret.isEmpty
        }
        
        static var headers: [String: String] {
            var headers = ["User-Agent": "MediaCloset/1.0 +https://github.com/yourusername/mediacloset"]
            
            if isConfigured {
                let credentials = "\(consumerKey):\(consumerSecret)"
                if let credentialsData = credentials.data(using: .utf8) {
                    let base64Credentials = credentialsData.base64EncodedString()
                    headers["Authorization"] = "Basic \(base64Credentials)"
                }
            }
            
            return headers
        }
    }
    
    /// Last.fm API configuration
    /// Register for a free Last.fm API key at:
    /// https://www.last.fm/api
    struct LastFM {
        static let apiKey = "YOUR_LASTFM_API_KEY"
        static let baseURL = "https://ws.audioscrobbler.com/2.0"
        
        static var isConfigured: Bool {
            return apiKey != "YOUR_LASTFM_API_KEY"
        }
    }
    
    /// Spotify Web API configuration (optional, for enhanced results)
    /// Register for Spotify Web API at:
    /// https://developer.spotify.com/web-api/
    struct Spotify {
        static let clientId = "YOUR_SPOTIFY_CLIENT_ID"
        static let clientSecret = "YOUR_SPOTIFY_CLIENT_SECRET"
        static let baseURL = "https://api.spotify.com/v1"
        
        static var isConfigured: Bool {
            return clientId != "YOUR_SPOTIFY_CLIENT_ID" && 
                   clientSecret != "YOUR_SPOTIFY_CLIENT_SECRET"
        }
    }
    
    // MARK: - Timeout Configuration
    
    static let defaultTimeout: TimeInterval = 8.0
    static let perServiceTimeout: TimeInterval = 2.0
    static let maxRetries = 2
    
    // MARK: - Rate Limiting
    
    static let requestDelay: TimeInterval = 1.0 // Delay between API calls
    
    // MARK: - Validation
    
    /// Check if any premium APIs are configured
    static var hasPremiumAPIs: Bool {
        return Discogs.isConfigured || LastFM.isConfigured || Spotify.isConfigured
    }
    
    /// Get list of configured services
    static var configuredServices: [String] {
        var services: [String] = ["iTunes Search", "MusicBrainz"]
        
        if Discogs.isConfigured { services.append("Discogs") }
        if LastFM.isConfigured { services.append("Last.fm") }
        if Spotify.isConfigured { services.append("Spotify") }
        
        return services
    }
}