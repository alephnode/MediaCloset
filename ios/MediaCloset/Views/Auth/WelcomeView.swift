//
//  Views/Auth/WelcomeView.swift
//  MediaCloset
//
//  Welcome screen shown to unauthenticated users
//

import SwiftUI

struct WelcomeView: View {
    @State private var appear = false
    @State private var showLogin = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Icon (matches LaunchSplash)
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.black, lineWidth: 6)
                            .frame(width: 128, height: 128)
                        
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 5)
                                .frame(width: 96, height: 96)
                            Circle()
                                .fill(Color.black)
                                .frame(width: 10, height: 10)
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 88, height: 10)
                        }
                    }
                    .scaleEffect(appear ? 1.0 : 0.85)
                    .opacity(appear ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)
                    
                    Text("MediaCloset")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(.black)
                        .padding(.top, 24)
                        .opacity(appear ? 1.0 : 0.0)
                        .offset(y: appear ? 0 : 8)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appear)
                    
                    Text("A centralized location to keep track\nof your physical media collection")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 32)
                        .opacity(appear ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: appear)
                    
                    Spacer()
                    
                    // Login button
                    Button {
                        showLogin = true
                    } label: {
                        Text("Log in or create an account")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .opacity(appear ? 1.0 : 0.0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: appear)
                }
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
        }
        .onAppear { appear = true }
    }
}

#Preview {
    WelcomeView()
}
