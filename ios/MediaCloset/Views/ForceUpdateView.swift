//
//  Views/ForceUpdateView.swift
//  MediaCloset
//
//  Blocking view shown when app version is below minimum required
//

import SwiftUI

struct ForceUpdateView: View {
    @ObservedObject var versionManager: VersionGateManager

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Warning icon
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.orange)

                Text("Update Required")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text(versionManager.updateMessage.isEmpty
                     ? "Please update to the latest version to continue using MediaCloset."
                     : versionManager.updateMessage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

                Spacer()

                // Update button
                if versionManager.storeURL != nil {
                    Button {
                        versionManager.openAppStore()
                    } label: {
                        Text("Update Now")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                Text("MediaCloset")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled(true)
    }
}

/// View shown when app is offline and grace period has expired
struct OfflineBlockedView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Offline icon
                Image(systemName: "wifi.slash")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.secondary)

                Text("Connection Required")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text("Please connect to the internet to verify your app version and continue using MediaCloset.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

                Spacer()

                Text("MediaCloset")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled(true)
    }
}

#Preview("Force Update") {
    ForceUpdateView(versionManager: VersionGateManager.shared)
}

#Preview("Offline Blocked") {
    OfflineBlockedView()
}
