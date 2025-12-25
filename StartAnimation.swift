//
//  StartAnimation.swift
//  ListeByBache
//
//  Created by Christopher Bachmann on 10.12.25.
//

import SwiftUI
import UIKit

struct StartAnimation: View {
    @State private var isAnimating = false
    @State private var showMainContent = false
    
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "v\(version)" : "v\(version) (\(build))"
    }
    
    var body: some View {
        ZStack {
            // Hintergrund an Logo-Farben angelehnt
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 18/255, green: 33/255, blue: 103/255), location: 0.0),  // dunkles Blau oben
                    .init(color: Color(red: 53/255, green: 27/255, blue: 125/255), location: 0.55), // Indigo in der Mitte
                    .init(color: Color(red: 94/255, green: 23/255, blue: 111/255), location: 1.0)   // Violett/Pink unten
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if !showMainContent {
                VStack(spacing: 30) {
                    // Einkaufswagen Icon mit Animation
                    Group {
                        if let uiImage = UIImage(named: "AppLogo") {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                                .rotationEffect(.degrees(isAnimating ? 0 : -6))
                                .scaleEffect(isAnimating ? 1.0 : 0.85)
                                .opacity(isAnimating ? 1.0 : 0.0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isAnimating)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .opacity(isAnimating ? 0.8 : 1.0)
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            }
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .opacity(isAnimating ? 1.0 : 0.0)
                        }
                    }
                    
                    // App Name
                    Text("ListeByBache")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    // Untertitel
                    Text("Deine smarte Liste")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    // Ladebalken
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .opacity(isAnimating ? 0.8 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.top, 20)
                    
                    Text(versionString)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .transition(.opacity)
                    
                    Text("Made by Bache")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 12)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: isAnimating)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                isAnimating = true
            }
            
            // Nach 3.5 Sekunden zum Hauptinhalt wechseln (plus 1 Sekunde)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showMainContent = true
                }
            }
        }
    }
}

#Preview {
    StartAnimation()
}
