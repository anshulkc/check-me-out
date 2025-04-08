//
//  UnhingedStyle.swift
//  CheckMeOut
//
//  Created for unhinged visual style
//

import SwiftUI

// Custom font modifiers for unhinged typography
struct UnhingedText: ViewModifier {
    let intensity: CGFloat // 0.0 to 1.0 for varying levels of distortion
    
    func body(content: Content) -> some View {
        content
            .font(.system(.title, design: .monospaced))
            .fontWeight(.black)
            .italic()
            .kerning(2)
            .rotationEffect(.degrees(intensity * 2))
            .shadow(color: .black, radius: 1, x: intensity * 3, y: intensity * 3)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: intensity)
    }
}

// Distorted container for UI elements
struct UnhingedContainer: ViewModifier {
    @State private var animateOffset = false
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 2)
                        .offset(x: animateOffset ? 3 : -3, y: animateOffset ? -2 : 2)
                }
            )
            .rotationEffect(.degrees(animateOffset ? 1 : -1))
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateOffset.toggle()
                }
            }
    }
}

// Glitch effect for images
struct GlitchEffect: ViewModifier {
    @State private var glitchOffset1 = CGFloat.zero
    @State private var glitchOffset2 = CGFloat.zero
    @State private var glitchOffset3 = CGFloat.zero
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .foregroundColor(.red)
                .offset(x: glitchOffset1, y: 0)
            
            content
                .foregroundColor(.green)
                .offset(x: glitchOffset2, y: 0)
                .blendMode(.screen)
            
            content
                .foregroundColor(.blue)
                .offset(x: glitchOffset3, y: 0)
                .blendMode(.screen)
        }
        .onAppear {
            let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            _ = timer.sink { _ in
                if Int.random(in: 0...10) > 8 { // Occasionally glitch
                    withAnimation(.easeInOut(duration: 0.1)) {
                        glitchOffset1 = CGFloat.random(in: -5...5)
                        glitchOffset2 = CGFloat.random(in: -5...5)
                        glitchOffset3 = CGFloat.random(in: -5...5)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            glitchOffset1 = 0
                            glitchOffset2 = 0
                            glitchOffset3 = 0
                        }
                    }
                }
            }
        }
    }
}

// Shaky text animation
struct ShakyText: ViewModifier {
    @State private var animateShake = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: animateShake ? 2 : -2, y: animateShake ? -2 : 2)
            .animation(
                Animation.easeInOut(duration: 0.1)
                    .repeatForever(autoreverses: true),
                value: animateShake
            )
            .onAppear {
                animateShake = true
            }
    }
}

// Extension to make these modifiers easier to use
extension View {
    func unhingedText(intensity: CGFloat = 0.5) -> some View {
        self.modifier(UnhingedText(intensity: intensity))
    }
    
    func unhingedContainer() -> some View {
        self.modifier(UnhingedContainer())
    }
    
    func glitchEffect() -> some View {
        self.modifier(GlitchEffect())
    }
    
    func shakyText() -> some View {
        self.modifier(ShakyText())
    }
} 