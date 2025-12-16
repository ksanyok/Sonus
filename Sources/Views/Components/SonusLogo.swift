import SwiftUI

struct SonusLogo: View {
    var size: CGFloat = 22

    @State private var draw: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            SonusWaveMark()
                .trim(from: 0, to: draw)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.65)) {
                        draw = 1
                    }
                }

            Text("Sonus")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .tracking(0.8)
        }
        .accessibilityLabel("Sonus")
    }
}

private struct SonusWaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        // A simple "SVG-like" waveform mark.
        // 4 peaks with smooth curves.
        let w = rect.width
        let h = rect.height

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        p.move(to: pt(0.05, 0.55))
        p.addCurve(to: pt(0.20, 0.30), control1: pt(0.10, 0.55), control2: pt(0.14, 0.32))
        p.addCurve(to: pt(0.32, 0.65), control1: pt(0.24, 0.28), control2: pt(0.28, 0.66))

        p.addCurve(to: pt(0.45, 0.18), control1: pt(0.36, 0.64), control2: pt(0.40, 0.22))
        p.addCurve(to: pt(0.58, 0.72), control1: pt(0.50, 0.14), control2: pt(0.54, 0.74))

        p.addCurve(to: pt(0.72, 0.35), control1: pt(0.62, 0.70), control2: pt(0.67, 0.36))
        p.addCurve(to: pt(0.84, 0.62), control1: pt(0.76, 0.34), control2: pt(0.80, 0.63))

        p.addCurve(to: pt(0.95, 0.50), control1: pt(0.88, 0.61), control2: pt(0.92, 0.52))
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
