//
//  MediaClosetApp.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

@main
struct MediaClosetApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var versionManager = VersionGateManager.shared
    @State private var appPhase: AppPhase = .splash

    enum AppPhase {
        case splash
        case loading
        case ready
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch appPhase {
                case .splash:
                    LaunchSplash()

                case .loading:
                    ProgressView()

                case .ready:
                    // Version gate has highest priority - checked before auth
                    switch versionManager.gateState {
                    case .checking:
                        ProgressView()

                    case .blocked:
                        ForceUpdateView(versionManager: versionManager)

                    case .offlineBlocked:
                        OfflineBlockedView()

                    case .passed, .offlineGrace:
                        // Version OK, proceed with auth-based routing
                        switch authManager.authState {
                        case .unknown:
                            ProgressView()
                        case .unauthenticated:
                            WelcomeView()
                                .environmentObject(authManager)
                        case .authenticated:
                            RootTabView()
                                .environmentObject(authManager)
                        }
                    }
                }
            }
            .onAppear {
                startLaunchSequence()
            }
        }
    }

    private func startLaunchSequence() {
        // Phase 1: Show splash for 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                appPhase = .loading
            }

            // Phase 2: Check version and auth in parallel
            Task {
                // Start both checks in parallel
                async let versionCheck: () = versionManager.checkVersion()
                async let authCheck: () = authManager.checkAuthStatus()
                // Minimum loading time for visual polish
                async let minDelay: () = Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // Wait for all to complete
                _ = await (versionCheck, authCheck, try? minDelay)

                // Phase 3: Transition to ready state
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) {
                        appPhase = .ready
                    }
                }
            }
        }
    }
}
