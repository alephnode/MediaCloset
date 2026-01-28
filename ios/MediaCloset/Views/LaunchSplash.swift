//
//  LaunchSplash.swift
//  MediaCloset
//
//  A lightweight SwiftUI splash used *after* Apple's static Launch Screen.
//  Shows the app icon and a bold sans-serif title with dark/light mode support.
//

import SwiftUI

struct LaunchSplash: View {
    @State private var appear = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Outlined icon matching the welcome/sign-in screen
                ZStack {
                    // Filled rounded square (outer area)
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.primary)
                        .frame(width: 128, height: 128)
                    
                    // Inner circle cutout (background color)
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 102, height: 102)
                    
                    // Vinyl record circle (outer)
                    Circle()
                        .stroke(Color.primary, lineWidth: 5)
                        .frame(width: 96, height: 96)
                    
                    // VHS inner hub circle
                    Circle()
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    // VHS rivets around the hub (12 evenly spaced)
                    ForEach(0..<12) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary)
                            .frame(width: 10, height: 5)
                            .offset(x: 24)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    
                    // Center dot
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 10, height: 10)
                }
                .scaleEffect(appear ? 1.0 : 0.8)
                .opacity(appear ? 1.0 : 0.0)
                
                Text("MediaCloset")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .opacity(appear ? 1.0 : 0.0)
                    .offset(y: appear ? 0 : 8)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appear)
        }
        .onAppear { appear = true }
    }
}
