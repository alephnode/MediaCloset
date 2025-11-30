//
//  SecretsTestView.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/19/25.
//

import SwiftUI

struct SecretsTestView: View {
    @State private var secretsStatus: [String: Bool] = [:]
    @State private var endpoint: String = "Loading..."
    @State private var secretPreview: String = "Loading..."
    @State private var manualEndpoint: String = ""
    @State private var manualSecret: String = ""
    @State private var showingManualInput = false
    @State private var showingConnectionAlert = false
    @State private var connectionMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Secrets") {
                    HStack {
                        Text("GraphQL Endpoint:")
                        Spacer()
                        Text(endpoint)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Admin Secret:")
                        Spacer()
                        Text(secretPreview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Debug Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secrets Source:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let url = SecretsManager.shared.graphqlEndpoint {
                            Text("✅ Endpoint available: \(url.absoluteString)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        } else {
                            Text("❌ No endpoint available")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        
                        if SecretsManager.shared.hasuraAdminSecret != nil {
                            Text("✅ Admin secret available")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        } else {
                            Text("❌ No admin secret available")
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
                    
                    Button("Store Current Secrets in Keychain") {
                        storeSecretsInKeychain()
                    }
                    
                    Button("Manually Store Secrets") {
                        showingManualInput = true
                    }
                    
                    Button("Test API Connection") {
                        testAPIConnection()
                    }
                }
            }
            .navigationTitle("Secrets Test")
            .onAppear {
                refreshStatus()
            }
            .sheet(isPresented: $showingManualInput) {
                NavigationView {
                    Form {
                        Section("GraphQL Endpoint") {
                            TextField("https://your-api.com/v1/graphql", text: $manualEndpoint)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Section("Hasura Admin Secret") {
                            SecureField("Enter admin secret", text: $manualSecret)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .navigationTitle("Store Secrets")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingManualInput = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Store") {
                                storeManualSecrets()
                                showingManualInput = false
                            }
                            .disabled(manualEndpoint.isEmpty || manualSecret.isEmpty)
                        }
                    }
                }
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
        
        if let url = SecretsManager.shared.graphqlEndpoint {
            endpoint = url.absoluteString
        } else {
            endpoint = "Not available"
        }
        
        if let secret = SecretsManager.shared.hasuraAdminSecret {
            secretPreview = String(secret.prefix(8)) + "..."
        } else {
            secretPreview = "Not available"
        }
    }
    
    private func storeSecretsInKeychain() {
        if let endpoint = SecretsManager.shared.graphqlEndpoint?.absoluteString,
           let secret = SecretsManager.shared.hasuraAdminSecret {
            let success = SecretsManager.shared.storeSecrets(
                graphqlEndpoint: endpoint,
                hasuraAdminSecret: secret
            )
            
            if success {
                print("✅ Successfully stored secrets in keychain")
            } else {
                print("❌ Failed to store secrets in keychain")
            }
            
            refreshStatus()
        }
    }
    
    private func storeManualSecrets() {
        let success = SecretsManager.shared.storeSecrets(
            graphqlEndpoint: manualEndpoint,
            hasuraAdminSecret: manualSecret
        )

        if success {
            print("✅ Successfully stored manual secrets in keychain")
            manualEndpoint = ""
            manualSecret = ""
        } else {
            print("❌ Failed to store manual secrets in keychain")
        }

        refreshStatus()
    }
    
    private func testAPIConnection() {
        Task {
            do {
                let response = try await GraphQLHTTPClient.shared.execute(
                    operationName: "TestConnection",
                    query: "{ __typename }"
                )
                
                await MainActor.run {
                    if response.errors != nil && !response.errors!.isEmpty {
                        connectionMessage = "❌ API connection failed with errors: \(response.errors!)"
                    } else {
                        connectionMessage = "✅ API connection successful!"
                    }
                    showingConnectionAlert = true
                }
            } catch {
                await MainActor.run {
                    connectionMessage = "❌ API connection failed with error: \(error.localizedDescription)"
                    showingConnectionAlert = true
                }
            }
        }
    }
}

#Preview {
    SecretsTestView()
}
