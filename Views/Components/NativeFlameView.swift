import SwiftUI

// MARK: - Native SwiftUI Flame with Particles & Organic Pulse
public struct NativeFlameView: View {
    public let streakCount: Int
    public let isFrozen: Bool
    
    @State private var waveOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkOffsets: [CGSize] = Array(repeating: .zero, count: 6)
    @State private var sparkOpacities: [Double] = Array(repeating: 0.0, count: 6)
    
    public init(streakCount: Int, isFrozen: Bool) {
        self.streakCount = streakCount
        self.isFrozen = isFrozen
    }
    
    public var body: some View {
        ZStack {
            // Ambient Radial Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: isFrozen
                            ? [Color.cyan.opacity(0.4), Color.blue.opacity(0.1), Color.clear]
                            : [Color.orange.opacity(0.45), Color.red.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(pulseScale)
            
            // Outer Flame Shape
            FlameShape(curveFactor: waveOffset)
                .fill(
                    LinearGradient(
                        colors: isFrozen
                            ? [Color.cyan, Color.blue, Color(red: 0.1, green: 0.3, blue: 0.8)]
                            : [Color.yellow, Color.orange, Color.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 110, height: 145)
                .shadow(color: isFrozen ? Color.cyan.opacity(0.6) : Color.orange.opacity(0.8), radius: 16, y: 4)
            
            // Inner Core Flame
            FlameShape(curveFactor: -waveOffset * 0.7)
                .fill(
                    LinearGradient(
                        colors: isFrozen
                            ? [Color.white, Color.cyan.opacity(0.9), Color.blue.opacity(0.5)]
                            : [Color.white, Color.yellow.opacity(0.95), Color.orange.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 65, height: 95)
                .offset(y: 15)
            
            // Animated Sparks / Embers
            ForEach(0..<6, id: \.self) { idx in
                Circle()
                    .fill(isFrozen ? Color.cyan : Color.yellow)
                    .frame(width: CGFloat(3 + (idx % 3)), height: CGFloat(3 + (idx % 3)))
                    .offset(sparkOffsets[idx])
                    .opacity(sparkOpacities[idx])
            }
            
            // Frozen Ice Overlay Badge
            if isFrozen {
                Image(systemName: "snowflake")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .blue, radius: 8)
                    .offset(y: 10)
            }
        }
        .onAppear {
            startFlameAnimation()
            startSparkLoop()
        }
    }
    
    private func startFlameAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
        ) {
            waveOffset = 1.0
            pulseScale = 1.08
        }
    }
    
    private func startSparkLoop() {
        for idx in 0..<6 {
            let delay = Double(idx) * 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    Animation.easeOut(duration: 1.4)
                        .repeatForever(autoreverses: false)
                ) {
                    let randomX = CGFloat.random(in: -35...35)
                    let randomY = CGFloat.random(in: -85 ... -30)
                    sparkOffsets[idx] = CGSize(width: randomX, height: randomY)
                    sparkOpacities[idx] = 0.9
                }
            }
        }
    }
}

// MARK: - Geometric Flame Shape Path
struct FlameShape: Shape {
    var curveFactor: CGFloat
    
    var animatableData: CGFloat {
        get { curveFactor }
        set { curveFactor = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Apex tip of flame
        path.move(to: CGPoint(x: w * 0.5 + (curveFactor * 6), y: 0))
        
        // Right flank curve
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.75),
            control1: CGPoint(x: w * 0.85 + (curveFactor * 4), y: h * 0.3),
            control2: CGPoint(x: w * 1.05, y: h * 0.55)
        )
        
        // Base rounded bottom
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.75),
            control1: CGPoint(x: w * 0.95, y: h),
            control2: CGPoint(x: w * 0.05, y: h)
        )
        
        // Left flank curve returning to apex
        path.addCurve(
            to: CGPoint(x: w * 0.5 + (curveFactor * 6), y: 0),
            control1: CGPoint(x: -w * 0.05, y: h * 0.55),
            control2: CGPoint(x: w * 0.15 - (curveFactor * 4), y: h * 0.3)
        )
        
        path.closeSubpath()
        return path
    }
}
