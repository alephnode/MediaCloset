//
//  Views/Profile/ProfileView.swift
//  MediaCloset
//
//  User profile and settings view with logout
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section {
                    if let user = authManager.currentUser {
                        HStack(spacing: 16) {
                            // Avatar circle with initial
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 60, height: 60)
                                
                                Text(avatarInitial(for: user))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayIdentifier)
                                    .font(.headline)
                                
                                if let createdAt = user.createdAt {
                                    Text("Member since \(formatDate(createdAt))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Account")
                }
                
                // App info section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                #if DEBUG
                // Debug section (only in debug builds)
                Section {
                    NavigationLink {
                        SecretsTestView()
                    } label: {
                        Label("API Debug", systemImage: "wrench.and.screwdriver")
                    }
                } header: {
                    Text("Developer")
                }
                #endif
                
                // Sign out section - Apple convention: destructive action at bottom
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func avatarInitial(for user: AuthUser) -> String {
        // Use first letter of email, or phone icon indicator, or fallback to "U"
        if let email = user.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        } else if user.phoneNumber != nil {
            return "📱"  // Phone emoji for phone-only users
        }
        return "U"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try to parse ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
