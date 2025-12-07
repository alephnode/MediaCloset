//
//  Services/TokenManager.swift
//  MediaCloset
//
//  Secure JWT token storage using iOS Keychain
//

import Foundation
import Security

/// Manages secure storage and retrieval of JWT tokens using iOS Keychain
final class TokenManager {
    static let shared = TokenManager()
    
    private let serviceName = "com.mediacloset.app"
    private let tokenKey = "jwt_token"
    private let userIdKey = "user_id"
    private let userEmailKey = "user_email"
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Saves the JWT token to Keychain
    /// - Parameter token: The JWT token to store
    /// - Returns: true if successful, false otherwise
    @discardableResult
    func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        // Delete any existing token first
        deleteToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        #if DEBUG
        if status != errSecSuccess {
            print("[TokenManager] Failed to save token: \(status)")
        }
        #endif
        
        return status == errSecSuccess
    }
    
    /// Retrieves the JWT token from Keychain
    /// - Returns: The stored JWT token, or nil if not found
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// Deletes the JWT token from Keychain
    @discardableResult
    func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Checks if a token exists in Keychain
    var hasToken: Bool {
        return getToken() != nil
    }
    
    // MARK: - User Info Storage
    
    /// Saves the user ID to Keychain
    @discardableResult
    func saveUserId(_ userId: String) -> Bool {
        guard let data = userId.data(using: .utf8) else { return false }
        
        deleteUserId()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    /// Retrieves the user ID from Keychain
    func getUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let userId = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return userId
    }
    
    @discardableResult
    private func deleteUserId() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userIdKey
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess || true
    }
    
    /// Saves the user email to Keychain
    @discardableResult
    func saveUserEmail(_ email: String) -> Bool {
        guard let data = email.data(using: .utf8) else { return false }
        
        deleteUserEmail()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userEmailKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    /// Retrieves the user email from Keychain
    func getUserEmail() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userEmailKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let email = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return email
    }
    
    @discardableResult
    private func deleteUserEmail() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: userEmailKey
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess || true
    }
    
    // MARK: - Clear All
    
    /// Clears all stored authentication data (token, user info)
    func clearAll() {
        deleteToken()
        deleteUserId()
        deleteUserEmail()
        
        #if DEBUG
        print("[TokenManager] Cleared all authentication data")
        #endif
    }
}
