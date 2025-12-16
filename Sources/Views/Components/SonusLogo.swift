import SwiftUI

struct SonusLogo: View {
    var size: CGFloat = 22

    @State private var phase: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            SonusWaveMark(phase: phase)
                .stroke(
                    LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)
                .shadow(color: .purple.opacity(0.5), radius: 5, x: 0, y: 0)

            Text("Sonus")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .hueRotation(.degrees(phase * 20))
                .opacity(textOpacity)
        }
        .accessibilityLabel("Sonus")
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                textOpacity = 1
            }
        }
    }
}

private struct SonusWaveMark: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        
        // Simple sine-based wave for continuous animation
        let midY = h / 2
        p.move(to: CGPoint(x: 0, y: midY))
        
        for x in stride(from: 0, through: w, by: 1) {
            let relativeX = x / w
            let sine = sin((relativeX + phase) * .pi * 4) // 2 cycles
            let y = midY + sine * (h * 0.4)
            p.addLine(to: CGPoint(x: x, y: y))
        }

        return p
    }
}

struct SonusTopBar: View {
    let left: AnyView
    let right: AnyView

    init(left: AnyView = AnyView(EmptyView()), right: AnyView = AnyView(EmptyView())) {
        self.left = left
        self.right = right
    }

    var body: some View {
        HStack {
            left
                .frame(minWidth: 220, alignment: .leading)

            Spacer(minLength: 12)

            SonusLogo(size: 22)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            right
                .frame(minWidth: 220, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}
