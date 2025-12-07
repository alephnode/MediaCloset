//
//  Views/Auth/LoginSuccessView.swift
//  MediaCloset
//
//  Success animation shown after login, transitions to main app
//

import SwiftUI

struct LoginSuccessView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var showCheckmark = false
    @State private var showText = false
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var circleProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated checkmark circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    // Animated progress circle
                    Circle()
                        .trim(from: 0, to: circleProgress)
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.black)
                        .scaleEffect(showCheckmark ? 1.0 : checkmarkScale)
                        .opacity(showCheckmark ? 1.0 : 0.0)
                }
                
                // Welcome text
                VStack(spacing: 8) {
                    Text("Welcome!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                    
                    if let user = authManager.currentUser {
                        Text(user.email)
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(showText ? 1.0 : 0.0)
                .offset(y: showText ? 0 : 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            animateSuccess()
        }
    }
    
    private func animateSuccess() {
        // Animate circle progress
        withAnimation(.easeInOut(duration: 0.5)) {
            circleProgress = 1.0
        }
        
        // Show checkmark after circle completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
        }
        
        // Show text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                showText = true
            }
        }
        
        // Transition to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            authManager.completeAuthentication()
        }
    }
}

#Preview {
    LoginSuccessView()
        .environmentObject(AuthManager.shared)
}
