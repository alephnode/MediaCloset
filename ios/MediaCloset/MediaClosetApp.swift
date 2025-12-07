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
    @State private var appPhase: AppPhase = .splash

    enum AppPhase {
        case splash
        case loading
        case ready
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.white.ignoresSafeArea()
                
                switch appPhase {
                case .splash:
                    LaunchSplash()
                    
                case .loading:
                    ProgressView()
                    
                case .ready:
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
            
            // Phase 2: Check auth and wait minimum time for smooth transition
            Task {
                // Start auth check
                async let authCheck: () = authManager.checkAuthStatus()
                // Minimum loading time for visual polish
                async let minDelay: () = Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Wait for both to complete
                _ = await (authCheck, try? minDelay)
                
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
