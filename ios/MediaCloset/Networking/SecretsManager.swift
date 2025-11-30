//
//  SecretsManager.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/19/25.
//

import Foundation
import Security

/// Manages secrets deletion and retrieval from multiple sources:
/// 1. Build-time environment variables (from xcconfig files)
/// 2. iOS Keychain (for detached iPhone scenarios)
/// 3. Fallback to sensible defaults
final class SecretsManager {
    static let shared = SecretsManager()
    
    private init() {
        // Automatically store secrets in keychain if they're available from build config
        storeSecretsIfAvailable()
        
        // Ensure we have secrets in keychain for future app launches
        ensureSecretsInKeychain()
        
        #if DEBUG
        print("[SecretsManager] Initialized with status:")
        let status = secretsStatus
        for (key, value) in status {
            print("  \(key): \(value)")
        }
        #endif
    }
    
    // MARK: - Build-time Configuration
    
    /// Configuration from xcconfig files at build time
    private struct BuildConfig {
        static var graphqlEndpoint: String? {
            guard let endpoint = Bundle.main.object(forInfoDictionaryKey: "GRAPHQL_ENDPOINT") as? String,
                  !endpoint.isEmpty else {
                #if DEBUG
                print("[SecretsManager] BuildConfig: No GRAPHQL_ENDPOINT found in Info.plist")
                print("[SecretsManager] Available keys in Info.plist: \(Bundle.main.infoDictionary?.keys.sorted() ?? [])")
                #endif
                return nil
            }
            #if DEBUG
            print("[SecretsManager] BuildConfig: Found GRAPHQL_ENDPOINT: \(endpoint)")
            #endif
            return endpoint
        }
        
        static var hasuraAdminSecret: String? {
            guard let secret = Bundle.main.object(forInfoDictionaryKey: "HASURA_ADMIN_SECRET") as? String,
                  !secret.isEmpty else {
                #if DEBUG
                print("[SecretsManager] BuildConfig: No HASURA_ADMIN_SECRET found in Info.plist")
                #endif
                return nil
            }
            #if DEBUG
            print("[SecretsManager] BuildConfig: Found HASURA_ADMIN_SECRET (length: \(secret.count))")
            #endif
            return secret
        }

        static var mediaClosetAPIEndpoint: String? {
            guard let endpoint = Bundle.main.object(forInfoDictionaryKey: "MEDIACLOSET_API_ENDPOINT") as? String,
                  !endpoint.isEmpty else {
                #if DEBUG
                print("[SecretsManager] BuildConfig: No MEDIACLOSET_API_ENDPOINT found in Info.plist")
                #endif
                return nil
            }
            #if DEBUG
            print("[SecretsManager] BuildConfig: Found MEDIACLOSET_API_ENDPOINT: \(endpoint)")
            #endif
            return endpoint
        }

        static var mediaClosetAPIKey: String? {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "MEDIACLOSET_API_KEY") as? String,
                  !key.isEmpty else {
                #if DEBUG
                print("[SecretsManager] BuildConfig: No MEDIACLOSET_API_KEY found in Info.plist")
                #endif
                return nil
            }
            #if DEBUG
            print("[SecretsManager] BuildConfig: Found MEDIACLOSET_API_KEY (length: \(key.count))")
            #endif
            return key
        }
    }
    
    // MARK: - Keychain Management
    
    private let serviceName = "com.alephnode.MediaCloset.Secrets"
    
    private func saveToKeychain(key: String, value: String) -> Bool {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            #if DEBUG
            if status != errSecItemNotFound {
                print("[SecretsManager] Keychain access failed for key '\(key)' with status: \(status)")
            }
            #endif
            return nil
        }
        
        return string
    }
    
    // MARK: - Public Interface
    
    /// Automatically stores secrets in keychain if they're available from build config
    private func storeSecretsIfAvailable() {
        var storedSecrets: [String: Bool] = [:]

        if let endpoint = BuildConfig.graphqlEndpoint {
            storedSecrets["endpoint"] = saveToKeychain(key: "GRAPHQL_ENDPOINT", value: endpoint)
        }

        if let secret = BuildConfig.hasuraAdminSecret {
            storedSecrets["secret"] = saveToKeychain(key: "HASURA_ADMIN_SECRET", value: secret)
        }

        if let apiEndpoint = BuildConfig.mediaClosetAPIEndpoint {
            storedSecrets["mediaClosetAPI"] = saveToKeychain(key: "MEDIACLOSET_API_ENDPOINT", value: apiEndpoint)
        }

        if let apiKey = BuildConfig.mediaClosetAPIKey {
            storedSecrets["mediaClosetAPIKey"] = saveToKeychain(key: "MEDIACLOSET_API_KEY", value: apiKey)
        }

        #if DEBUG
        if !storedSecrets.isEmpty {
            print("[SecretsManager] Auto-stored secrets in keychain: \(storedSecrets)")
        } else {
            print("[SecretsManager] No secrets available from build config to store in keychain")
            print("  BuildConfig.graphqlEndpoint: \(BuildConfig.graphqlEndpoint?.description ?? "nil")")
            print("  BuildConfig.hasuraAdminSecret: \(BuildConfig.hasuraAdminSecret != nil ? "available" : "nil")")
            print("  BuildConfig.mediaClosetAPIEndpoint: \(BuildConfig.mediaClosetAPIEndpoint?.description ?? "nil")")
            print("  BuildConfig.mediaClosetAPIKey: \(BuildConfig.mediaClosetAPIKey != nil ? "available" : "nil")")
        }
        #endif
    }
    
    /// Ensures secrets are available in keychain for future app launches
    private func ensureSecretsInKeychain() {
        // Check if we already have secrets in keychain
        let hasEndpointInKeychain = loadFromKeychain(key: "GRAPHQL_ENDPOINT") != nil
        let hasSecretInKeychain = loadFromKeychain(key: "HASURA_ADMIN_SECRET") != nil
        let hasMediaClosetAPIInKeychain = loadFromKeychain(key: "MEDIACLOSET_API_ENDPOINT") != nil
        let hasMediaClosetAPIKeyInKeychain = loadFromKeychain(key: "MEDIACLOSET_API_KEY") != nil

        // If we don't have secrets in keychain, try to get them from build config or environment
        if !hasEndpointInKeychain || !hasSecretInKeychain || !hasMediaClosetAPIInKeychain || !hasMediaClosetAPIKeyInKeychain {
            var endpointToStore: String?
            var secretToStore: String?
            var mediaClosetAPIToStore: String?
            var mediaClosetAPIKeyToStore: String?

            // Try to get endpoint from build config first, then environment
            if !hasEndpointInKeychain {
                endpointToStore = BuildConfig.graphqlEndpoint ??
                                 ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"]
            }

            // Try to get secret from build config first, then environment
            if !hasSecretInKeychain {
                secretToStore = BuildConfig.hasuraAdminSecret ??
                               ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"]
            }

            // Try to get MediaCloset API endpoint from build config first, then environment
            if !hasMediaClosetAPIInKeychain {
                mediaClosetAPIToStore = BuildConfig.mediaClosetAPIEndpoint ??
                                       ProcessInfo.processInfo.environment["MEDIACLOSET_API_ENDPOINT"]
            }

            // Try to get MediaCloset API key from build config first, then environment
            if !hasMediaClosetAPIKeyInKeychain {
                mediaClosetAPIKeyToStore = BuildConfig.mediaClosetAPIKey ??
                                          ProcessInfo.processInfo.environment["MEDIACLOSET_API_KEY"]
            }

            // Store what we can find
            if let endpoint = endpointToStore {
                let saved = saveToKeychain(key: "GRAPHQL_ENDPOINT", value: endpoint)
                #if DEBUG
                print("[SecretsManager] Stored endpoint in keychain: \(saved)")
                #endif
            }

            if let secret = secretToStore {
                let saved = saveToKeychain(key: "HASURA_ADMIN_SECRET", value: secret)
                #if DEBUG
                print("[SecretsManager] Stored secret in keychain: \(saved)")
                #endif
            }

            if let mediaClosetAPI = mediaClosetAPIToStore {
                let saved = saveToKeychain(key: "MEDIACLOSET_API_ENDPOINT", value: mediaClosetAPI)
                #if DEBUG
                print("[SecretsManager] Stored MediaCloset API endpoint in keychain: \(saved)")
                #endif
            }

            if let mediaClosetAPIKey = mediaClosetAPIKeyToStore {
                let saved = saveToKeychain(key: "MEDIACLOSET_API_KEY", value: mediaClosetAPIKey)
                #if DEBUG
                print("[SecretsManager] Stored MediaCloset API key in keychain: \(saved)")
                #endif
            }
        } else {
            #if DEBUG
            print("[SecretsManager] Secrets already available in keychain")
            #endif
        }
    }
    
    /// Stores secrets in the iOS Keychain for offline access
    func storeSecrets(graphqlEndpoint: String, hasuraAdminSecret: String) -> Bool {
        let endpointSaved = saveToKeychain(key: "GRAPHQL_ENDPOINT", value: graphqlEndpoint)
        let secretSaved = saveToKeychain(key: "HASURA_ADMIN_SECRET", value: hasuraAdminSecret)
        
        #if DEBUG
        print("[SecretsManager] Stored secrets in keychain: endpoint=\(endpointSaved), secret=\(secretSaved)")
        #endif
        
        return endpointSaved && secretSaved
    }

    /// Retrieves the GraphQL endpoint from the most appropriate source
    var graphqlEndpoint: URL? {
        // 1. Try build-time configuration first
        if let endpoint = BuildConfig.graphqlEndpoint,
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using GraphQL endpoint from build config: \(endpoint)")
            #endif
            return url
        }
        
        // 2. Fall back to keychain
        if let endpoint = loadFromKeychain(key: "GRAPHQL_ENDPOINT"),
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using GraphQL endpoint from keychain: \(endpoint)")
            #endif
            return url
        }
        
        // 3. Fall back to environment variable (for development)
        if let endpoint = ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"],
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using GraphQL endpoint from environment: \(endpoint)")
            #endif
            return url
        }
        
        // 4. Hardcoded fallback for development (from Local.secrets.xcconfig)
        #if DEBUG
        let fallbackEndpoint = "https://polite-herring-80.hasura.app/v1/graphql"
        if let url = URL(string: fallbackEndpoint) {
            print("[SecretsManager] Using hardcoded fallback GraphQL endpoint: \(fallbackEndpoint)")
            return url
        }
        #endif
        
        // 5. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No GraphQL endpoint found in any source")
        print("  Build config: \(BuildConfig.graphqlEndpoint?.description ?? "nil")")
        print("  Keychain: \(loadFromKeychain(key: "GRAPHQL_ENDPOINT")?.description ?? "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"]?.description ?? "nil")")
        print("[SecretsManager] WARNING: GRAPHQL_ENDPOINT must be configured via xcconfig files or keychain")
        #endif
        
        return nil
    }
    
    /// Retrieves the Hasura admin secret from the most appropriate source
    var hasuraAdminSecret: String? {
        // 1. Try build-time configuration first
        if let secret = BuildConfig.hasuraAdminSecret {
            #if DEBUG
            print("[SecretsManager] Using Hasura admin secret from build config")
            #endif
            return secret
        }
        
        // 2. Fall back to keychain
        if let secret = loadFromKeychain(key: "HASURA_ADMIN_SECRET") {
            #if DEBUG
            print("[SecretsManager] Using Hasura admin secret from keychain")
            #endif
            return secret
        }
        
        // 3. Fall back to environment variable (for development)
        if let secret = ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"] {
            #if DEBUG
            print("[SecretsManager] Using Hasura admin secret from environment")
            #endif
            return secret
        }
        
        // 4. No hardcoded fallback for admin secret (security requirement)
        
        // 5. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No Hasura admin secret found in any source")
        print("  Build config: \(BuildConfig.hasuraAdminSecret != nil ? "available" : "nil")")
        print("  Keychain: \(loadFromKeychain(key: "HASURA_ADMIN_SECRET") != nil ? "available" : "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"] != nil ? "available" : "nil")")
        print("[SecretsManager] WARNING: HASURA_ADMIN_SECRET must be configured via xcconfig files or keychain")
        #endif
        
        return nil
    }

    /// Retrieves the MediaCloset Go API endpoint from the most appropriate source
    var mediaClosetAPIEndpoint: URL? {
        // 1. Try build-time configuration first
        if let endpoint = BuildConfig.mediaClosetAPIEndpoint,
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API endpoint from build config: \(endpoint)")
            #endif
            return url
        }

        // 2. Fall back to keychain
        if let endpoint = loadFromKeychain(key: "MEDIACLOSET_API_ENDPOINT"),
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API endpoint from keychain: \(endpoint)")
            #endif
            return url
        }

        // 3. Fall back to environment variable (for development)
        if let endpoint = ProcessInfo.processInfo.environment["MEDIACLOSET_API_ENDPOINT"],
           let url = URL(string: endpoint) {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API endpoint from environment: \(endpoint)")
            #endif
            return url
        }

        // 4. Hardcoded fallback for development
        #if DEBUG
        let fallbackEndpoint = "http://localhost:8080/query"
        if let url = URL(string: fallbackEndpoint) {
            print("[SecretsManager] Using hardcoded fallback MediaCloset API endpoint: \(fallbackEndpoint)")
            return url
        }
        #endif

        // 5. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No MediaCloset API endpoint found in any source")
        print("  Build config: \(BuildConfig.mediaClosetAPIEndpoint?.description ?? "nil")")
        print("  Keychain: \(loadFromKeychain(key: "MEDIACLOSET_API_ENDPOINT")?.description ?? "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["MEDIACLOSET_API_ENDPOINT"]?.description ?? "nil")")
        print("[SecretsManager] WARNING: MEDIACLOSET_API_ENDPOINT must be configured via xcconfig files or keychain")
        #endif

        return nil
    }

    /// Retrieves the MediaCloset API key from the most appropriate source
    var mediaClosetAPIKey: String? {
        // 1. Try build-time configuration first
        if let key = BuildConfig.mediaClosetAPIKey {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API key from build config")
            #endif
            return key
        }

        // 2. Fall back to keychain
        if let key = loadFromKeychain(key: "MEDIACLOSET_API_KEY") {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API key from keychain")
            #endif
            return key
        }

        // 3. Fall back to environment variable (for development)
        if let key = ProcessInfo.processInfo.environment["MEDIACLOSET_API_KEY"] {
            #if DEBUG
            print("[SecretsManager] Using MediaCloset API key from environment")
            #endif
            return key
        }

        // 4. No hardcoded fallback for API key (security requirement)

        // 5. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No MediaCloset API key found in any source")
        print("  Build config: \(BuildConfig.mediaClosetAPIKey != nil ? "available" : "nil")")
        print("  Keychain: \(loadFromKeychain(key: "MEDIACLOSET_API_KEY") != nil ? "available" : "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["MEDIACLOSET_API_KEY"] != nil ? "available" : "nil")")
        print("[SecretsManager] WARNING: MEDIACLOSET_API_KEY must be configured via xcconfig files or keychain")
        #endif

        return nil
    }
    
    /// Clears all stored secrets from the keychain
    func clearKeychainSecrets() {
        let keys = ["GRAPHQL_ENDPOINT", "HASURA_ADMIN_SECRET", "MEDIACLOSET_API_ENDPOINT", "MEDIACLOSET_API_KEY"]

        for key in keys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key
            ]

            SecItemDelete(query as CFDictionary)
        }

        #if DEBUG
        print("[SecretsManager] Cleared all secrets from keychain")
        #endif
    }
    
    /// Forces a refresh of secrets from build configuration to keychain
    func refreshSecretsFromBuildConfig() {
        #if DEBUG
        print("[SecretsManager] Force refreshing secrets from build config")
        #endif
        storeSecretsIfAvailable()
    }
    
    /// Forces a complete refresh of secrets from all available sources
    func refreshSecretsFromAllSources() {
        #if DEBUG
        print("[SecretsManager] Force refreshing secrets from all sources")
        #endif
        
        // Clear existing keychain entries
        clearKeychainSecrets()
        
        // Try to store from build config first
        storeSecretsIfAvailable()
        
        // Then ensure we have what we can get from any source
        ensureSecretsInKeychain()
        
        #if DEBUG
        print("[SecretsManager] Refresh complete. New status:")
        let status = secretsStatus
        for (key, value) in status {
            print("  \(key): \(value)")
        }
        #endif
    }
    
    /// Manually sets secrets (for testing/debugging purposes)
    func setSecretsManually(graphqlEndpoint: String, hasuraAdminSecret: String) -> Bool {
        #if DEBUG
        print("[SecretsManager] Manually setting secrets")
        #endif
        return storeSecrets(graphqlEndpoint: graphqlEndpoint, hasuraAdminSecret: hasuraAdminSecret)
    }
    
    /// Checks if we have all required secrets and attempts to load them if missing
    func ensureSecretsAvailable() -> Bool {
        let hasEndpoint = graphqlEndpoint != nil
        let hasSecret = hasuraAdminSecret != nil
        let hasMediaClosetAPI = mediaClosetAPIEndpoint != nil
        let hasMediaClosetAPIKey = mediaClosetAPIKey != nil

        if !hasEndpoint || !hasSecret || !hasMediaClosetAPI || !hasMediaClosetAPIKey {
            #if DEBUG
            print("[SecretsManager] Missing secrets, attempting to refresh...")
            #endif
            refreshSecretsFromAllSources()

            // Check again after refresh
            return graphqlEndpoint != nil && hasuraAdminSecret != nil && mediaClosetAPIEndpoint != nil && mediaClosetAPIKey != nil
        }

        return true
    }
    
    /// Returns a summary of which sources have secrets available (for debugging)
    var secretsStatus: [String: Bool] {
        return [
            "buildConfig_endpoint": BuildConfig.graphqlEndpoint != nil,
            "buildConfig_secret": BuildConfig.hasuraAdminSecret != nil,
            "buildConfig_mediaClosetAPI": BuildConfig.mediaClosetAPIEndpoint != nil,
            "buildConfig_mediaClosetAPIKey": BuildConfig.mediaClosetAPIKey != nil,
            "keychain_endpoint": loadFromKeychain(key: "GRAPHQL_ENDPOINT") != nil,
            "keychain_secret": loadFromKeychain(key: "HASURA_ADMIN_SECRET") != nil,
            "keychain_mediaClosetAPI": loadFromKeychain(key: "MEDIACLOSET_API_ENDPOINT") != nil,
            "keychain_mediaClosetAPIKey": loadFromKeychain(key: "MEDIACLOSET_API_KEY") != nil,
            "env_endpoint": ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"] != nil,
            "env_secret": ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"] != nil,
            "env_mediaClosetAPI": ProcessInfo.processInfo.environment["MEDIACLOSET_API_ENDPOINT"] != nil,
            "env_mediaClosetAPIKey": ProcessInfo.processInfo.environment["MEDIACLOSET_API_KEY"] != nil
        ]
    }
    
    /// Returns helpful instructions for fixing configuration issues
    var configurationHelp: String {
        var help = "Configuration Help:\n\n"

        if BuildConfig.graphqlEndpoint == nil {
            help += "• GraphQL endpoint not found in build configuration.\n"
            help += "  Check that Local.secrets.xcconfig is properly configured.\n\n"
        }

        if BuildConfig.hasuraAdminSecret == nil {
            help += "• Hasura admin secret not found in build configuration.\n"
            help += "  Check that Local.secrets.xcconfig contains HASURA_ADMIN_SECRET.\n\n"
        }

        if BuildConfig.mediaClosetAPIEndpoint == nil {
            help += "• MediaCloset API endpoint not found in build configuration.\n"
            help += "  Check that Local.secrets.xcconfig contains MEDIACLOSET_API_ENDPOINT.\n\n"
        }

        if BuildConfig.mediaClosetAPIKey == nil {
            help += "• MediaCloset API key not found in build configuration.\n"
            help += "  Check that Local.secrets.xcconfig contains MEDIACLOSET_API_KEY.\n\n"
        }

        if loadFromKeychain(key: "GRAPHQL_ENDPOINT") == nil && loadFromKeychain(key: "HASURA_ADMIN_SECRET") == nil && loadFromKeychain(key: "MEDIACLOSET_API_ENDPOINT") == nil && loadFromKeychain(key: "MEDIACLOSET_API_KEY") == nil {
            help += "• No secrets found in keychain.\n"
            help += "  Try rebuilding the app or use the 'Set Secrets Manually' option in Debug tab.\n\n"
        }

        help += "Steps to fix:\n"
        help += "1. Ensure Local.secrets.xcconfig exists with GRAPHQL_ENDPOINT, HASURA_ADMIN_SECRET, MEDIACLOSET_API_ENDPOINT, and MEDIACLOSET_API_KEY\n"
        help += "2. Clean and rebuild the project\n"
        help += "3. Or use the Debug tab to set secrets manually\n"
        help += "4. The app will automatically retry when reopened"

        return help
    }
}
