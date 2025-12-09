//
//  Views/Auth/LoginView.swift
//  MediaCloset
//
//  Email or phone input screen for requesting login code
//

import SwiftUI

// MARK: - Input Type Detection

enum LoginInputType {
    case unknown
    case email
    case phone
}

// MARK: - Country Code Data

struct CountryCode: Identifiable, Hashable {
    let id: String  // ISO country code
    let name: String
    let dialCode: String
    let flag: String
    
    static let popular: [CountryCode] = [
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦"),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺"),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪"),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "🇫🇷"),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵"),
        CountryCode(id: "MX", name: "Mexico", dialCode: "+52", flag: "🇲🇽"),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷"),
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "🇮🇳"),
        CountryCode(id: "CN", name: "China", dialCode: "+86", flag: "🇨🇳"),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸"),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹"),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱"),
        CountryCode(id: "SE", name: "Sweden", dialCode: "+46", flag: "🇸🇪"),
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭"),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "🇰🇷"),
        CountryCode(id: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬"),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿"),
        CountryCode(id: "IE", name: "Ireland", dialCode: "+353", flag: "🇮🇪"),
    ]
    
    static var `default`: CountryCode {
        // Default to US
        popular.first { $0.id == "US" } ?? popular[0]
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var inputText = ""
    @State private var selectedCountry: CountryCode = .default
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCodeEntry = false
    @State private var showCountryPicker = false
    
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Input Detection
    
    private var detectedInputType: LoginInputType {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        
        // Empty input
        if trimmed.isEmpty {
            return .unknown
        }
        
        // If contains @, it's likely an email
        if trimmed.contains("@") {
            return .email
        }
        
        // If starts with + or is mostly digits, it's likely a phone
        let digitsOnly = trimmed.filter { $0.isNumber }
        if trimmed.hasPrefix("+") || (digitsOnly.count >= 7 && digitsOnly.count == trimmed.count) {
            return .phone
        }
        
        // If it has letters and no @, still unknown but leaning towards phone if mostly digits
        let digitRatio = Double(digitsOnly.count) / Double(trimmed.count)
        if digitRatio > 0.7 {
            return .phone
        }
        
        return .unknown
    }
    
    private var isValidEmail: Bool {
        let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return inputText.wholeMatch(of: emailRegex) != nil
    }
    
    private var isValidPhone: Bool {
        // Remove non-digits for validation
        let digitsOnly = inputText.filter { $0.isNumber }
        // Valid phone: 7-15 digits (without country code)
        return digitsOnly.count >= 7 && digitsOnly.count <= 15
    }
    
    private var isValidInput: Bool {
        switch detectedInputType {
        case .email:
            return isValidEmail
        case .phone:
            return isValidPhone
        case .unknown:
            return false
        }
    }
    
    private var fullPhoneNumber: String {
        let digitsOnly = inputText.filter { $0.isNumber }
        return "\(selectedCountry.dialCode)\(digitsOnly)"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Header
                headerView
                    .padding(.bottom, 40)
                
                // Input field
                inputFieldView
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCodeEntry) {
            CodeEntryView(
                identifier: detectedInputType == .email ? inputText : fullPhoneNumber,
                identifierType: detectedInputType == .email ? .email : .phone
            )
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: headerIcon)
                .font(.system(size: 64))
                .foregroundStyle(.primary)
            
            Text("Sign in")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Enter your email or phone number")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }
    
    private var headerIcon: String {
        switch detectedInputType {
        case .email:
            return "envelope.circle.fill"
        case .phone:
            return "phone.circle.fill"
        case .unknown:
            return "person.circle.fill"
        }
    }
    
    // MARK: - Input Field
    
    private var inputFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                // Country code picker (only show when phone detected)
                if detectedInputType == .phone {
                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCountry.flag)
                                .font(.system(size: 20))
                            Text(selectedCountry.dialCode)
                                .font(.system(size: 17))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Spacer().frame(width: 8)
                }
                
                // Main input field
                TextField(placeholderText, text: $inputText)
                    .textContentType(detectedInputType == .email ? .emailAddress : .telephoneNumber)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isInputFocused)
                    .font(.system(size: 17))
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(errorMessage != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
            }
            .animation(.easeInOut(duration: 0.2), value: detectedInputType)
            
            // Helper text
            if detectedInputType != .unknown {
                Text(helperText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private var placeholderText: String {
        switch detectedInputType {
        case .email:
            return "Email address"
        case .phone:
            return "Phone number"
        case .unknown:
            return "Email or phone number"
        }
    }
    
    private var keyboardType: UIKeyboardType {
        switch detectedInputType {
        case .email:
            return .emailAddress
        case .phone:
            return .phonePad
        case .unknown:
            return .default
        }
    }
    
    private var helperText: String {
        switch detectedInputType {
        case .email:
            return "We'll send a verification code to this email"
        case .phone:
            return "We'll text you a verification code"
        case .unknown:
            return ""
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            requestCode()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(.systemBackground)))
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isValidInput && !isLoading ? Color.primary : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!isValidInput || isLoading)
    }
    
    // MARK: - Actions
    
    private func requestCode() {
        guard isValidInput else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                switch detectedInputType {
                case .email:
                    _ = try await authManager.requestLoginCode(email: inputText)
                case .phone:
                    _ = try await authManager.requestLoginCodeByPhone(phoneNumber: fullPhoneNumber)
                case .unknown:
                    throw AuthManager.AuthError.requestFailed("Please enter a valid email or phone number")
                }
                
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

// MARK: - Country Picker View

struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: CountryCode
    @State private var searchText = ""
    
    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.popular
        }
        return CountryCode.popular.filter { country in
            country.name.localizedCaseInsensitiveContains(searchText) ||
            country.dialCode.contains(searchText) ||
            country.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    selectedCountry = country
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                            .font(.system(size: 24))
                        Text(country.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundStyle(.secondary)
                        if country.id == selectedCountry.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
