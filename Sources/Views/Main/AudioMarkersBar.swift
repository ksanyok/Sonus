import SwiftUI

struct AudioMarkersBar: View {
    struct Marker: Identifiable, Hashable {
        let id = UUID()
        let timeSeconds: Double
        let title: String
        let subtitle: String?
    }

    let duration: Double
    let currentTime: Double
    let markers: [Marker]
    let onSeek: (Double) -> Void

    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n.t("Markers", ru: "Метки"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(TimelinePointBuilder.formatHMS(currentTime)) / \(TimelinePointBuilder.formatHMS(duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let h = geo.size.height
                let safeDuration = max(1, duration)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .frame(height: 10)
                        .position(x: w / 2, y: h / 2)

                    // markers
                    ForEach(markers) { m in
                        let x = w * CGFloat(min(max(m.timeSeconds / safeDuration, 0), 1))
                        Rectangle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 2, height: 16)
                            .position(x: x, y: h / 2)
                            .help(tooltip(for: m))
                    }

                    // playhead
                    let playX = w * CGFloat(min(max(currentTime / safeDuration, 0), 1))
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 8, height: 8)
                        .position(x: playX, y: h / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / w, 0), 1)
                            onSeek(Double(ratio) * safeDuration)
                        }
                )
            }
            .frame(height: 20)
        }
    }

    private func tooltip(for marker: Marker) -> String {
        var parts: [String] = []
        parts.append(TimelinePointBuilder.formatHMS(marker.timeSeconds))
        parts.append(marker.title)
        if let s = marker.subtitle, !s.isEmpty {
            parts.append(s)
        }
        return parts.joined(separator: " — ")
    }
}
