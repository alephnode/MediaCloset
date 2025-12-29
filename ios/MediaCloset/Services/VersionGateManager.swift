//
//  Services/VersionGateManager.swift
//  MediaCloset
//
//  Manages app version checking and forced update blocking
//

import Foundation
import SwiftUI

/// Represents the result of a version gate check
enum VersionGateState: Equatable {
    case checking           // Initial state, checking version
    case passed             // Version is supported, allow app
    case blocked(message: String, storeURL: URL?)  // Version too old, block app
    case offlineGrace       // Offline but within grace period
    case offlineBlocked     // Offline and grace period expired
}

/// Manages version checking and forced update blocking
/// Caches version check results for offline resilience
@MainActor
final class VersionGateManager: ObservableObject {
    static let shared = VersionGateManager()

    @Published private(set) var gateState: VersionGateState = .checking
    @Published private(set) var updateMessage: String = ""
    @Published private(set) var storeURL: URL?

    // Cache keys
    private let lastCheckDateKey = "VersionGate.lastCheckDate"
    private let lastMinimumVersionKey = "VersionGate.lastMinimumVersion"
    private let lastCheckPassedKey = "VersionGate.lastCheckPassed"
    private let lastUpdateMessageKey = "VersionGate.lastUpdateMessage"
    private let lastStoreURLKey = "VersionGate.lastStoreURL"

    // Grace periods (in seconds)
    private let freshCacheThreshold: TimeInterval = 24 * 60 * 60  // 24 hours
    private let maxGracePeriod: TimeInterval = 48 * 60 * 60       // 48 hours

    private init() {}

    // MARK: - Public Methods

    /// Checks the app version against the backend minimum version
    /// Uses cached results for offline resilience
    func checkVersion() async {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        #if DEBUG
        print("[VersionGateManager] Current app version: \(currentVersion)")
        #endif

        // Check if we have a fresh cached result
        if let cachedResult = getCachedResult() {
            let cacheAge = Date().timeIntervalSince(cachedResult.checkDate)

            if cacheAge < freshCacheThreshold && cachedResult.passed {
                #if DEBUG
                print("[VersionGateManager] Using fresh cache (age: \(Int(cacheAge/3600))h) - passed")
                #endif
                gateState = .passed
                return
            }
        }

        // Try to fetch from network
        do {
            let config = try await MediaClosetAPIClient.shared.fetchAppVersionConfig()

            let isSupported = isVersionSupported(currentVersion, minimum: config.minimumIOSVersion)

            // Cache the result
            cacheResult(
                passed: isSupported,
                minimumVersion: config.minimumIOSVersion,
                updateMessage: config.updateMessage,
                storeURL: config.storeURL
            )

            if isSupported {
                #if DEBUG
                print("[VersionGateManager] Version check passed (current: \(currentVersion), minimum: \(config.minimumIOSVersion))")
                #endif
                gateState = .passed
            } else {
                #if DEBUG
                print("[VersionGateManager] Version check FAILED (current: \(currentVersion), minimum: \(config.minimumIOSVersion))")
                #endif
                updateMessage = config.updateMessage
                storeURL = URL(string: config.storeURL)
                gateState = .blocked(message: config.updateMessage, storeURL: URL(string: config.storeURL))
            }

        } catch {
            #if DEBUG
            print("[VersionGateManager] Network error: \(error)")
            #endif

            // Handle offline scenario with grace period
            handleOfflineScenario()
        }
    }

    /// Opens the App Store to update the app
    func openAppStore() {
        guard let url = storeURL else {
            #if DEBUG
            print("[VersionGateManager] No App Store URL available")
            #endif
            return
        }

        #if DEBUG
        print("[VersionGateManager] Opening App Store: \(url)")
        #endif

        UIApplication.shared.open(url)
    }

    // MARK: - Private Methods

    /// Compares semantic versions
    /// - Returns: true if current >= minimum
    private func isVersionSupported(_ current: String, minimum: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimum.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentParts.count, minimumParts.count) {
            let c = i < currentParts.count ? currentParts[i] : 0
            let m = i < minimumParts.count ? minimumParts[i] : 0

            if c < m { return false }
            if c > m { return true }
        }

        return true // Equal versions
    }

    /// Handles offline scenarios using cached data
    private func handleOfflineScenario() {
        guard let cachedResult = getCachedResult() else {
            // No cache, must block
            #if DEBUG
            print("[VersionGateManager] No cache available, blocking app")
            #endif
            gateState = .offlineBlocked
            return
        }

        let cacheAge = Date().timeIntervalSince(cachedResult.checkDate)

        if cacheAge > maxGracePeriod {
            // Cache too old, must block
            #if DEBUG
            print("[VersionGateManager] Cache expired (\(Int(cacheAge/3600))h old), blocking app")
            #endif
            gateState = .offlineBlocked
            return
        }

        if cachedResult.passed {
            // Within grace period and last check passed
            #if DEBUG
            print("[VersionGateManager] Using cached pass (age: \(Int(cacheAge/3600))h)")
            #endif
            gateState = .offlineGrace
        } else {
            // Last check failed, block regardless of cache age
            #if DEBUG
            print("[VersionGateManager] Cached check failed, blocking app")
            #endif
            updateMessage = cachedResult.updateMessage ?? "Please update to continue using MediaCloset."
            storeURL = cachedResult.storeURL.flatMap { URL(string: $0) }
            gateState = .blocked(message: updateMessage, storeURL: storeURL)
        }
    }

    // MARK: - Cache Management

    private struct CachedResult {
        let checkDate: Date
        let minimumVersion: String
        let passed: Bool
        let updateMessage: String?
        let storeURL: String?
    }

    private func getCachedResult() -> CachedResult? {
        let defaults = UserDefaults.standard

        guard let checkDate = defaults.object(forKey: lastCheckDateKey) as? Date,
              let minimumVersion = defaults.string(forKey: lastMinimumVersionKey) else {
            return nil
        }

        return CachedResult(
            checkDate: checkDate,
            minimumVersion: minimumVersion,
            passed: defaults.bool(forKey: lastCheckPassedKey),
            updateMessage: defaults.string(forKey: lastUpdateMessageKey),
            storeURL: defaults.string(forKey: lastStoreURLKey)
        )
    }

    private func cacheResult(passed: Bool, minimumVersion: String, updateMessage: String, storeURL: String) {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: lastCheckDateKey)
        defaults.set(minimumVersion, forKey: lastMinimumVersionKey)
        defaults.set(passed, forKey: lastCheckPassedKey)
        defaults.set(updateMessage, forKey: lastUpdateMessageKey)
        defaults.set(storeURL, forKey: lastStoreURLKey)

        #if DEBUG
        print("[VersionGateManager] Cached version check result (passed: \(passed))")
        #endif
    }
}
