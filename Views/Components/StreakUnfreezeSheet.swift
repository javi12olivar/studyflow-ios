import SwiftUI

public struct StreakUnfreezeSheet: View {
    @ObservedObject var streakManager: StreakManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tapCount: Int = 0
    @State private var iceScale: CGFloat = 1.0
    @State private var isUnfrozen: Bool = false
    @State private var showConfetti: Bool = false
    
    public init(streakManager: StreakManager) {
        self.streakManager = streakManager
    }
    
    public var body: some View {
        ZStack {
            // Dark Frost Background
            Color(red: 0.05, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Text(isUnfrozen ? "¡Racha Rescatada!" : "Descongelar Racha")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(isUnfrozen ? "Tu fuego de estudio vuelve a arder con fuerza." : "Toca el hielo repetidamente para romperlo y reactivar tu racha.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Ice Cube Interactive Target
                ZStack {
                    if isUnfrozen {
                        NativeFlameView(streakCount: streakManager.currentStreak, isFrozen: false)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ZStack {
                            // Frosty Glow
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 190, height: 190)
                                .blur(radius: 16)
                            
                            // Ice Block Body
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.85), Color.cyan.opacity(0.6), Color.blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 170, height: 170)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                )
                                .shadow(color: .cyan.opacity(0.5), radius: 20)
                            
                            // Frozen Flame Silhouette Inside
                            Image(systemName: "flame.fill")
                                .font(.system(size: 72))
                                .foregroundColor(.white.opacity(0.4))
                            
                            // Crack Overlays based on Tap Count
                            if tapCount >= 1 {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.9))
                                    .rotationEffect(.degrees(25))
                            }
                            if tapCount >= 2 {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 45))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(-35))
                                    .offset(x: 10, y: -10)
                            }
                        }
                        .scaleEffect(iceScale)
                        .onTapGesture {
                            handleIceTap()
                        }
                    }
                }
                .frame(height: 240)
                
                Spacer()
                
                // Bottom Action
                if isUnfrozen {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Continuar Estudiando")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(18)
                            .shadow(color: .orange.opacity(0.5), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                } else {
                    Text("Toca el bloque de hielo (\(3 - tapCount) toques restantes)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.cyan)
                        .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func handleIceTap() {
        guard !isUnfrozen else { return }
        
        tapCount += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            iceScale = 0.92
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                iceScale = 1.0
            }
        }
        
        if tapCount == 1 {
            HapticManager.shared.heavy()
            AudioManager.shared.play(.crackFirst)
        } else if tapCount == 2 {
            HapticManager.shared.rigid()
            AudioManager.shared.play(.crackSecond)
        } else if tapCount >= 3 {
            HapticManager.shared.success()
            AudioManager.shared.play(.dayLands)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioManager.shared.play(.flame)
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isUnfrozen = true
                streakManager.unfreezeManually()
            }
        }
    }
}
