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
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    LaunchSplash()
                        .transition(.opacity)
                } else {
                    // Show view based on auth state
                    switch authManager.authState {
                    case .unknown:
                        // Still checking auth status
                        ZStack {
                            Color.white.ignoresSafeArea()
                            ProgressView()
                        }
                    case .unauthenticated:
                        WelcomeView()
                            .environmentObject(authManager)
                            .transition(.opacity)
                    case .authenticated:
                        RootTabView()
                            .environmentObject(authManager)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: authManager.authState)
            .onAppear {
                // Keeping splash brief per Apple's guidance
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                    // Check auth status after splash
                    Task {
                        await authManager.checkAuthStatus()
                    }
                }
            }
        }
    }
}
