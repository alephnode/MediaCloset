//
//  SecretsDebugView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/19/25.
//

import SwiftUI

#if DEBUG
struct SecretsDebugView: View {
    @State private var secretsStatus: [String: Bool] = [:]
    @State private var showingClearAlert = false

    var body: some View {
        NavigationView {
            List {
                Section("Secrets Status") {
                    ForEach(Array(secretsStatus.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Image(systemName: secretsStatus[key] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(secretsStatus[key] == true ? .green : .red)
                        }
                    }
                }

                Section("Actions") {
                    Button("Refresh Status") {
                        refreshStatus()
                    }

                    Button("Refresh Secrets from Build Config") {
                        SecretsManager.shared.refreshSecretsFromBuildConfig()
                        refreshStatus()
                    }

                    Button("Refresh from All Sources") {
                        SecretsManager.shared.refreshSecretsFromAllSources()
                        refreshStatus()
                    }

                    Button("Clear Keychain Secrets", role: .destructive) {
                        showingClearAlert = true
                    }
                }

                Section("Current Values") {
                    if let endpoint = SecretsManager.shared.mediaClosetAPIEndpoint {
                        VStack(alignment: .leading) {
                            Text("MediaCloset API Endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(endpoint.absoluteString)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(nil)
                        }
                    }

                    if let key = SecretsManager.shared.mediaClosetAPIKey {
                        VStack(alignment: .leading) {
                            Text("MediaCloset API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(key.prefix(8)) + "...")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                Section("Configuration Help") {
                    Text(SecretsManager.shared.configurationHelp)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Section {
                    Text("Note: All data access now goes through the MediaCloset Go API proxy. Direct Hasura access has been removed for security.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Secrets Debug")
            .onAppear {
                refreshStatus()
            }
            .alert("Clear Keychain Secrets", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    SecretsManager.shared.clearKeychainSecrets()
                    refreshStatus()
                }
            } message: {
                Text("This will remove all secrets from the iOS Keychain. The app will need to be rebuilt to restore secrets from the xcconfig files.")
            }
        }
    }

    private func refreshStatus() {
        secretsStatus = SecretsManager.shared.secretsStatus
    }
}

#Preview {
    SecretsDebugView()
}
#endif
