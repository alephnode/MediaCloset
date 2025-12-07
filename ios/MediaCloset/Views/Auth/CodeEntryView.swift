//
//  Views/Auth/CodeEntryView.swift
//  MediaCloset
//
//  6-digit code entry screen with expiration timer
//

import SwiftUI

struct CodeEntryView: View {
    @EnvironmentObject private var authManager: AuthManager
    let email: String
    
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var timeRemaining = 300 // 5 minutes
    @State private var canResend = false
    @State private var showSuccess = false
    
    @FocusState private var isCodeFocused: Bool
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var isValidCode: Bool {
        code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.primary)
                    
                    Text("Enter your code")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("We sent a 6-digit code to")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                    
                    Text(email)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 40)
                
                // Code input
                VStack(spacing: 16) {
                    // Custom code input display
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            CodeDigitBox(
                                digit: index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : "",
                                isFocused: isCodeFocused && index == code.count
                            )
                        }
                    }
                    .onTapGesture {
                        isCodeFocused = true
                    }
                    
                    // Hidden text field for input
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .focused($isCodeFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .onChange(of: code) { _, newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                code = String(newValue.prefix(6))
                            }
                            // Remove non-digits
                            code = code.filter { $0.isNumber }
                            
                            // Auto-submit when 6 digits entered
                            if code.count == 6 {
                                verifyCode()
                            }
                        }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Timer
                    if timeRemaining > 0 {
                        Text("Code expires in \(formattedTime)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Code expired")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Resend button
                VStack(spacing: 16) {
                    if canResend || timeRemaining == 0 {
                        Button {
                            resendCode()
                        } label: {
                            Text("Resend code")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .disabled(isLoading)
                    }
                    
                    // Verify button
                    Button {
                        verifyCode()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(.systemBackground)))
                            } else {
                                Text("Verify")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValidCode && !isLoading && timeRemaining > 0 ? Color.primary : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!isValidCode || isLoading || timeRemaining == 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSuccess) {
            LoginSuccessView()
        }
        .onAppear {
            isCodeFocused = true
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
            // Enable resend after 30 seconds
            if timeRemaining <= 270 && !canResend {
                canResend = true
            }
        }
    }
    
    private func verifyCode() {
        guard isValidCode, timeRemaining > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.verifyLoginCode(email: email, code: code)
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    code = "" // Clear code on error
                }
            }
        }
    }
    
    private func resendCode() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await authManager.requestLoginCode(email: email)
                await MainActor.run {
                    isLoading = false
                    timeRemaining = 300 // Reset timer
                    canResend = false
                    code = ""
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

// MARK: - Code Digit Box

struct CodeDigitBox: View {
    let digit: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 48, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? Color.primary : Color.clear, lineWidth: 2)
                )
            
            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        CodeEntryView(email: "test@example.com")
            .environmentObject(AuthManager.shared)
    }
}
