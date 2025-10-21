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
    @State private var manualEndpoint = ""
    @State private var manualSecret = ""
    @State private var manualOMDBKey = ""
    @State private var showingManualInput = false
    
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
                    
                    Button("Set Secrets Manually") {
                        showingManualInput = true
                    }
                    
                    Button("Set OMDB Key Only") {
                        // User needs to enter their API key manually
                        showingManualInput = true
                        refreshStatus()
                    }
                    
                    Button("Test OMDB API") {
                        Task {
                            let vhsVM = VHSVM()
                            await vhsVM.testOMDBAPI()
                        }
                    }
                    
                    Button("Clear Keychain Secrets", role: .destructive) {
                        showingClearAlert = true
                    }
                }
                
                Section("Current Values") {
                    if let endpoint = SecretsManager.shared.graphqlEndpoint {
                        VStack(alignment: .leading) {
                            Text("GraphQL Endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(endpoint.absoluteString)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(nil)
                        }
                    }
                    
                    if let secret = SecretsManager.shared.hasuraAdminSecret {
                        VStack(alignment: .leading) {
                            Text("Hasura Admin Secret")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(secret.prefix(8)) + "...")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    if let omdbKey = SecretsManager.shared.omdbApiKey {
                        VStack(alignment: .leading) {
                            Text("OMDB API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(omdbKey.prefix(8)) + "...")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                Section("Configuration Help") {
                    Text(SecretsManager.shared.configurationHelp)
                        .font(.system(.caption, design: .monospaced))
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
            .alert("Set Secrets Manually", isPresented: $showingManualInput) {
                TextField("GraphQL Endpoint", text: $manualEndpoint)
                SecureField("Hasura Admin Secret", text: $manualSecret)
                TextField("OMDB API Key", text: $manualOMDBKey)
                Button("Cancel", role: .cancel) { }
                Button("Set") {
                    if !manualEndpoint.isEmpty && !manualSecret.isEmpty {
                        _ = SecretsManager.shared.setSecretsManually(
                            graphqlEndpoint: manualEndpoint,
                            hasuraAdminSecret: manualSecret
                        )
                    }
                    if !manualOMDBKey.isEmpty {
                        _ = SecretsManager.shared.storeOMDBKey(manualOMDBKey)
                    }
                    refreshStatus()
                    manualEndpoint = ""
                    manualSecret = ""
                    manualOMDBKey = ""
                }
            } message: {
                Text("Enter the GraphQL endpoint, Hasura admin secret, and OMDB API key manually for testing. All secrets will be stored securely in the keychain.")
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
