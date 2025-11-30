//
//  SecretsTestView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/19/25.
//

import SwiftUI

struct SecretsTestView: View {
    @State private var secretsStatus: [String: Bool] = [:]
    @State private var apiEndpoint: String = "Loading..."
    @State private var apiKeyPreview: String = "Loading..."
    @State private var showingConnectionAlert = false
    @State private var connectionMessage = ""

    var body: some View {
        NavigationView {
            List {
                Section("Current Secrets") {
                    HStack {
                        Text("API Endpoint:")
                        Spacer()
                        Text(apiEndpoint)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("API Key:")
                        Spacer()
                        Text(apiKeyPreview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Debug Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secrets Source:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let url = SecretsManager.shared.mediaClosetAPIEndpoint {
                            Text("✅ API Endpoint available: \(url.absoluteString)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        } else {
                            Text("❌ No API endpoint available")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        }

                        if SecretsManager.shared.mediaClosetAPIKey != nil {
                            Text("✅ API key available")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        } else {
                            Text("❌ No API key available")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("Sources Status") {
                    ForEach(Array(secretsStatus.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
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

                    Button("Test API Connection") {
                        testAPIConnection()
                    }

                    Button("Clear Keychain Secrets") {
                        clearKeychain()
                    }
                    .foregroundColor(.red)
                }

                Section {
                    Text("Note: All data access now goes through the MediaCloset Go API proxy. Direct Hasura access has been removed for security.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Secrets Test")
            .onAppear {
                refreshStatus()
            }
            .alert("API Connection Test", isPresented: $showingConnectionAlert) {
                Button("OK") { }
            } message: {
                Text(connectionMessage)
            }
        }
    }

    private func refreshStatus() {
        secretsStatus = SecretsManager.shared.secretsStatus

        if let url = SecretsManager.shared.mediaClosetAPIEndpoint {
            apiEndpoint = url.absoluteString
        } else {
            apiEndpoint = "Not available"
        }

        if let key = SecretsManager.shared.mediaClosetAPIKey {
            apiKeyPreview = String(key.prefix(8)) + "..."
        } else {
            apiKeyPreview = "Not available"
        }
    }

    private func clearKeychain() {
        SecretsManager.shared.clearKeychainSecrets()
        print("✅ Cleared all secrets from keychain")
        refreshStatus()
    }

    private func testAPIConnection() {
        Task {
            let isHealthy = await MediaClosetAPIClient.shared.checkHealth()

            await MainActor.run {
                if isHealthy {
                    connectionMessage = "✅ MediaCloset API connection successful!"
                } else {
                    connectionMessage = "❌ MediaCloset API connection failed"
                }
                showingConnectionAlert = true
            }
        }
    }
}

#Preview {
    SecretsTestView()
}
