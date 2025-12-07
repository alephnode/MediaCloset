//
//  Views/Auth/LoginView.swift
//  MediaCloset
//
//  Email input screen for requesting login code
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCodeEntry = false
    
    @FocusState private var isEmailFocused: Bool
    
    private var isValidEmail: Bool {
        let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return email.wholeMatch(of: emailRegex) != nil
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.black)
                    
                    Text("Enter your email")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("We'll send you a code to sign in")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
                
                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isEmailFocused)
                        .font(.system(size: 17))
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(errorMessage != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button {
                    requestCode()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidEmail && !isLoading ? Color.black : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!isValidEmail || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCodeEntry) {
            CodeEntryView(email: email)
        }
        .onAppear {
            isEmailFocused = true
        }
    }
    
    private func requestCode() {
        guard isValidEmail else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await authManager.requestLoginCode(email: email)
                await MainActor.run {
                    isLoading = false
                    showCodeEntry = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthManager.shared)
    }
}
