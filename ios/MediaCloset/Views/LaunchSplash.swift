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
                // Icon drawn in SwiftUI to avoid bundling a separate splash image.
                ZStack {
                    // Rounded square border
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.primary, lineWidth: 6)
                        .frame(width: 128, height: 128)

                    // Vinyl + VHS motif
                    ZStack {
                        Circle()
                            .stroke(Color.primary, lineWidth: 5)
                            .frame(width: 96, height: 96)
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 88, height: 10)
                    }
                }
                .scaleEffect(appear ? 1.0 : 0.85)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)

                Text("MediaCloset")
                    .font(.system(size: 28, weight: .bold, design: .default)) // bold, sans-serif
                    .foregroundStyle(.primary)
                    .opacity(appear ? 1.0 : 0.0)
                    .offset(y: appear ? 0 : 8)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appear)
            }
            .padding(32)
        }
        .onAppear { appear = true }
    }
}
