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
    }
    
    // MARK: - Build-time Configuration
    
    /// Configuration from xcconfig files at build time
    private struct BuildConfig {
        static var graphqlEndpoint: String? {
            guard let endpoint = Bundle.main.object(forInfoDictionaryKey: "GRAPHQL_ENDPOINT") as? String,
                  !endpoint.isEmpty else {
                return nil
            }
            return endpoint
        }
        
        static var hasuraAdminSecret: String? {
            guard let secret = Bundle.main.object(forInfoDictionaryKey: "HASURA_ADMIN_SECRET") as? String,
                  !secret.isEmpty else {
                return nil
            }
            return secret
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
            return nil
        }
        
        return string
    }
    
    // MARK: - Public Interface
    
    /// Automatically stores secrets in keychain if they're available from build config
    private func storeSecretsIfAvailable() {
        if let endpoint = BuildConfig.graphqlEndpoint,
           let secret = BuildConfig.hasuraAdminSecret {
            let endpointSaved = saveToKeychain(key: "GRAPHQL_ENDPOINT", value: endpoint)
            let secretSaved = saveToKeychain(key: "HASURA_ADMIN_SECRET", value: secret)
            
            #if DEBUG
            print("[SecretsManager] Auto-stored secrets in keychain: endpoint=\(endpointSaved), secret=\(secretSaved)")
            #endif
        } else {
            #if DEBUG
            print("[SecretsManager] No secrets available from build config to store in keychain")
            print("  BuildConfig.graphqlEndpoint: \(BuildConfig.graphqlEndpoint?.description ?? "nil")")
            print("  BuildConfig.hasuraAdminSecret: \(BuildConfig.hasuraAdminSecret != nil ? "available" : "nil")")
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
        
        // 4. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No GraphQL endpoint found in any source")
        print("  Build config: \(BuildConfig.graphqlEndpoint?.description ?? "nil")")
        print("  Keychain: \(loadFromKeychain(key: "GRAPHQL_ENDPOINT")?.description ?? "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"]?.description ?? "nil")")
        assertionFailure("GRAPHQL_ENDPOINT must be configured via xcconfig files or keychain")
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
        
        // 4. No fallback - this should never happen in production
        #if DEBUG
        print("[SecretsManager] ERROR: No Hasura admin secret found in any source")
        print("  Build config: \(BuildConfig.hasuraAdminSecret != nil ? "available" : "nil")")
        print("  Keychain: \(loadFromKeychain(key: "HASURA_ADMIN_SECRET") != nil ? "available" : "nil")")
        print("  Environment: \(ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"] != nil ? "available" : "nil")")
        assertionFailure("HASURA_ADMIN_SECRET must be configured via xcconfig files or keychain")
        #endif
        
        return nil
    }
    
    /// Clears all stored secrets from the keychain
    func clearKeychainSecrets() {
        let keys = ["GRAPHQL_ENDPOINT", "HASURA_ADMIN_SECRET"]
        
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
    
    /// Returns a summary of which sources have secrets available (for debugging)
    var secretsStatus: [String: Bool] {
        return [
            "buildConfig_endpoint": BuildConfig.graphqlEndpoint != nil,
            "buildConfig_secret": BuildConfig.hasuraAdminSecret != nil,
            "keychain_endpoint": loadFromKeychain(key: "GRAPHQL_ENDPOINT") != nil,
            "keychain_secret": loadFromKeychain(key: "HASURA_ADMIN_SECRET") != nil,
            "env_endpoint": ProcessInfo.processInfo.environment["GRAPHQL_ENDPOINT"] != nil,
            "env_secret": ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"] != nil
        ]
    }
}
