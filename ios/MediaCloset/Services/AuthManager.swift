//
//  Services/AuthManager.swift
//  MediaCloset
//
//  Central authentication state management
//

import Foundation
import SwiftUI

/// Represents the current authentication state of the app
enum AuthState: Equatable {
    case unknown        // Initial state, checking for stored token
    case unauthenticated // No valid token, show welcome/login
    case authenticated   // Valid token, show main app
}

/// Central manager for authentication state
/// Observed by the app to determine which view to show
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let tokenManager = TokenManager.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Checks authentication status on app launch
    /// Validates stored token with the backend
    func checkAuthStatus() async {
        guard tokenManager.hasToken else {
            authState = .unauthenticated
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Validate token by calling the `me` query
        do {
            let user = try await MediaClosetAPIClient.shared.fetchCurrentUser()
            if let user = user {
                currentUser = user
                authState = .authenticated
                
                #if DEBUG
                let identifier = user.email ?? user.phoneNumber ?? user.id
                print("[AuthManager] Token valid, user: \(identifier)")
                #endif
            } else {
                // Token invalid or expired
                await logout()
            }
        } catch {
            #if DEBUG
            print("[AuthManager] Token validation failed: \(error)")
            #endif
            // Token invalid, clear it
            await logout()
        }
    }
    
    // MARK: - Email Authentication
    
    /// Requests a login code to be sent to the email
    /// - Parameter email: User's email address
    /// - Returns: Success message or throws error
    func requestLoginCode(email: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let response = try await MediaClosetAPIClient.shared.requestLoginCode(email: email)
        
        if response.success {
            return response.message ?? "Login code sent to your email"
        } else {
            let error = response.error ?? "Failed to send login code"
            errorMessage = error
            throw AuthError.requestFailed(error)
        }
    }
    
    /// Verifies the login code sent via email and completes authentication
    /// - Parameters:
    ///   - email: User's email address
    ///   - code: 6-digit verification code
    func verifyLoginCode(email: String, code: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let response = try await MediaClosetAPIClient.shared.verifyLoginCode(email: email, code: code)
        
        guard response.success else {
            let error = response.error ?? "Invalid or expired code"
            errorMessage = error
            throw AuthError.verificationFailed(error)
        }
        
        guard let token = response.token else {
            errorMessage = "No token received"
            throw AuthError.noToken
        }
        
        // Store token and user info
        tokenManager.saveToken(token)
        
        if let user = response.user {
            currentUser = user
            tokenManager.saveUserId(user.id)
            if let email = user.email {
                tokenManager.saveUserEmail(email)
            }
        }
        
        #if DEBUG
        print("[AuthManager] Login successful for: \(email)")
        #endif
    }
    
    // MARK: - Phone Authentication
    
    /// Requests a login code to be sent via SMS
    /// - Parameter phoneNumber: User's phone number in E.164 format (e.g., +15551234567)
    /// - Returns: Success message or throws error
    func requestLoginCodeByPhone(phoneNumber: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let response = try await MediaClosetAPIClient.shared.requestLoginCodeByPhone(phoneNumber: phoneNumber)
        
        if response.success {
            return response.message ?? "Login code sent to your phone"
        } else {
            let error = response.error ?? "Failed to send login code"
            errorMessage = error
            throw AuthError.requestFailed(error)
        }
    }
    
    /// Verifies the login code sent via SMS and completes authentication
    /// - Parameters:
    ///   - phoneNumber: User's phone number in E.164 format
    ///   - code: 6-digit verification code
    func verifyLoginCodeByPhone(phoneNumber: String, code: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let response = try await MediaClosetAPIClient.shared.verifyLoginCodeByPhone(phoneNumber: phoneNumber, code: code)
        
        guard response.success else {
            let error = response.error ?? "Invalid or expired code"
            errorMessage = error
            throw AuthError.verificationFailed(error)
        }
        
        guard let token = response.token else {
            errorMessage = "No token received"
            throw AuthError.noToken
        }
        
        // Store token and user info
        tokenManager.saveToken(token)
        
        if let user = response.user {
            currentUser = user
            tokenManager.saveUserId(user.id)
            if let email = user.email {
                tokenManager.saveUserEmail(email)
            }
            // Note: Could also store phone number if needed
        }
        
        #if DEBUG
        print("[AuthManager] Login successful for phone: \(phoneNumber)")
        #endif
    }
    
    /// Sets the auth state to authenticated (called after success animation)
    func completeAuthentication() {
        authState = .authenticated
    }
    
    /// Logs out the current user and returns to welcome screen
    func logout() async {
        tokenManager.clearAll()
        currentUser = nil
        authState = .unauthenticated
        
        #if DEBUG
        print("[AuthManager] User logged out")
        #endif
    }
    
    // MARK: - Error Types
    
    enum AuthError: LocalizedError {
        case requestFailed(String)
        case verificationFailed(String)
        case noToken
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .requestFailed(let message):
                return message
            case .verificationFailed(let message):
                return message
            case .noToken:
                return "Authentication failed. Please try again."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
}
