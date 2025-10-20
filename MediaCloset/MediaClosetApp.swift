//
//  MediaClosetApp.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import SwiftUI

@main
struct MediaClosetApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    LaunchSplash()
                        .transition(.opacity)
                } else {
                    RootTabView()
                }
            }
            .onAppear {
                // Keeping splash brief per Apple's guidance
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
