//
//  EnvironmentManager.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/19/25.
//

import Foundation

/// Manages different app environments and their configurations
enum AppEnvironment: String, CaseIterable {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
    
    /// Current environment based on build configuration
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    /// Display name for the current environment
    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
    
    /// Whether this is a production environment
    var isProduction: Bool {
        return self == .production
    }
    
    /// Whether debug features should be enabled
    var allowsDebugFeatures: Bool {
        return !isProduction
    }
}

/// Configuration values that vary by environment
struct EnvironmentConfig {
    let environment: AppEnvironment
    let graphqlEndpoint: String
    let hasuraAdminSecret: String
    let enableAnalytics: Bool
    let enableCrashReporting: Bool
    let logLevel: LogLevel
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    /// Default configuration for each environment
    /// Note: Actual secrets should come from xcconfig files or keychain, not hardcoded here
    static func defaultConfig(for environment: AppEnvironment) -> EnvironmentConfig {
        switch environment {
        case .development:
            return EnvironmentConfig(
                environment: .development,
                graphqlEndpoint: "", // Will be loaded from xcconfig/keychain
                hasuraAdminSecret: "", // Will be loaded from xcconfig/keychain
                enableAnalytics: false,
                enableCrashReporting: false,
                logLevel: .debug
            )
        case .staging:
            return EnvironmentConfig(
                environment: .staging,
                graphqlEndpoint: "", // Will be loaded from xcconfig/keychain
                hasuraAdminSecret: "", // Will be loaded from xcconfig/keychain
                enableAnalytics: true,
                enableCrashReporting: true,
                logLevel: .info
            )
        case .production:
            return EnvironmentConfig(
                environment: .production,
                graphqlEndpoint: "", // Will be loaded from xcconfig/keychain
                hasuraAdminSecret: "", // Will be loaded from xcconfig/keychain
                enableAnalytics: true,
                enableCrashReporting: true,
                logLevel: .warning
            )
        }
    }
}
