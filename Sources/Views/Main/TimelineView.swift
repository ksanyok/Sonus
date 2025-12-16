import SwiftUI
import Charts

struct TimelineView: View {
    let transcript: String
    let duration: TimeInterval
    let keyMoments: [KeyMoment]

    @EnvironmentObject private var l10n: LocalizationService

    @State private var selectedIndex: Int? = nil

    var body: some View {
        let points = TimelinePointBuilder.build(transcript: transcript, duration: duration)

        VStack(alignment: .leading, spacing: 12) {
            if points.isEmpty {
                Text(l10n.t("No timeline available", ru: "Нет таймлайна"))
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(
                            x: .value("Time", p.midSeconds),
                            y: .value("Emotional", p.emotionalIntensity)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", p.midSeconds),
                            y: .value("Tension", p.tension)
                        )
                        .foregroundStyle(.secondary)
                        .interpolationMethod(.catmullRom)

                        BarMark(
                            x: .value("Time", p.midSeconds),
                            y: .value("Negations", Double(p.negationsCount))
                        )
                        .foregroundStyle(.tertiary)
                    }

                    if let selectedIndex, points.indices.contains(selectedIndex) {
                        let p = points[selectedIndex]
                        RuleMark(x: .value("Selected", p.midSeconds))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                TimelineTooltip(point: p)
                            }
                    }

                    // Overlay key moments (approximate) on the timeline if timeHint is parseable
                    ForEach(keyMomentMarkers(points: points)) { marker in
                        PointMark(
                            x: .value("Moment", marker.timeSeconds),
                            y: .value("MomentY", marker.y)
                        )
                        .foregroundStyle(.primary)
                        .symbolSize(30)
                        .annotation(position: .top, alignment: .leading) {
                            Text(marker.title)
                                .font(.caption)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(TimelinePointBuilder.formatHMS(seconds))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 260)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geo[plotFrame].origin
                                        let locationX = value.location.x - origin.x
                                        if let time: Double = proxy.value(atX: locationX) {
                                            selectedIndex = TimelinePointBuilder.closestIndex(points: points, timeSeconds: time)
                                        }
                                    }
                                    .onEnded { _ in }
                            )
                            .onHover { hovering in
                                if !hovering {
                                    selectedIndex = nil
                                }
                            }
                    }
                }

                Text(l10n.t("Note: timeline is approximate (derived from transcript segments).", ru: "Важно: таймлайн приблизительный (построен по фрагментам транскрипта)."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func keyMomentMarkers(points: [TimelinePoint]) -> [TimelineMomentMarker] {
        guard !points.isEmpty else { return [] }
        let maxY: Double = 96

        var markers: [TimelineMomentMarker] = []
        markers.reserveCapacity(min(12, keyMoments.count))

        for m in keyMoments.prefix(12) {
            guard let hint = m.timeHint else { continue }
            guard let seconds = TimelinePointBuilder.parseTimeHintSeconds(hint) else { continue }
            let title = m.type ?? "moment"
            markers.append(TimelineMomentMarker(timeSeconds: seconds, y: maxY, title: title))
        }

        return markers
    }
}

private struct TimelineTooltip: View {
    let point: TimelinePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("≈ \(TimelinePointBuilder.formatHMS(point.startSeconds))–\(TimelinePointBuilder.formatHMS(point.endSeconds))")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Label("Emo \(Int(point.emotionalIntensity))", systemImage: "waveform.path.ecg")
                Label("Tension \(Int(point.tension))", systemImage: "exclamationmark.triangle")
                Label("Neg \(point.negationsCount)", systemImage: "nosign")
            }
            .font(.caption)

            if !point.reasons.isEmpty {
                Text(point.reasons.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let snippet = point.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

private struct TimelineMomentMarker: Identifiable {
    let id = UUID()
    let timeSeconds: Double
    let y: Double
    let title: String
}

struct TimelinePoint: Identifiable {
    let id = UUID()
    let startSeconds: Double
    let endSeconds: Double

    let emotionalIntensity: Double // 0..100
    let tension: Double // 0..100
    let negationsCount: Int

    let reasons: [String]
    let snippet: String?

    var midSeconds: Double { (startSeconds + endSeconds) / 2 }
}

enum TimelinePointBuilder {
    static func build(transcript: String?, duration: TimeInterval) -> [TimelinePoint] {
        guard let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return build(transcript: transcript, duration: duration)
    }

    static func build(transcript: String, duration: TimeInterval) -> [TimelinePoint] {
        let cleaned = transcript.replacingOccurrences(of: "\r", with: "")
        let total = max(1.0, duration)

        let targetBuckets = bucketCount(for: total)
        let segments = splitEvenly(cleaned, count: targetBuckets)

        var points: [TimelinePoint] = []
        points.reserveCapacity(segments.count)

        for i in segments.indices {
            let start = total * Double(i) / Double(segments.count)
            let end = total * Double(i + 1) / Double(segments.count)
            let text = segments[i]

            let negations = countMatches(in: text, pattern: "\\b(не|нет|никак|никогда|нельзя|невозможно|откажусь)\\b")
            let exclam = text.filter { $0 == "!" }.count
            let questions = text.filter { $0 == "?" }.count
            let conflictWords = countMatches(in: text.lowercased(), pattern: "(дорого|проблем|не устраивает|возраж|конфликт|скандал|не согласен|не подходит)")

            // Emotional intensity is a blend of punctuation + conflict words.
            let emotional = clamp01(Double(exclam) / 6.0) * 50
                + clamp01(Double(conflictWords) / 6.0) * 40
                + clamp01(Double(questions) / 10.0) * 10

            // Tension emphasizes negations + conflict words.
            let tension = clamp01(Double(negations) / 20.0) * 55
                + clamp01(Double(conflictWords) / 6.0) * 35
                + clamp01(Double(exclam) / 6.0) * 10

            var reasons: [String] = []
            if negations >= 6 { reasons.append("many negations") }
            if conflictWords >= 3 { reasons.append("conflict / objections") }
            if exclam >= 2 { reasons.append("raised emotions") }
            if questions >= 5 { reasons.append("many questions") }

            let snippet = snippetFrom(text)

            points.append(
                TimelinePoint(
                    startSeconds: start,
                    endSeconds: end,
                    emotionalIntensity: min(100, emotional),
                    tension: min(100, tension),
                    negationsCount: negations,
                    reasons: reasons,
                    snippet: snippet
                )
            )
        }

        return points
    }

    static func closestIndex(points: [TimelinePoint], timeSeconds: Double) -> Int? {
        guard !points.isEmpty else { return nil }
        var bestIdx = 0
        var best = Double.greatestFiniteMagnitude
        for (i, p) in points.enumerated() {
            let d = abs(p.midSeconds - timeSeconds)
            if d < best {
                best = d
                bestIdx = i
            }
        }
        return bestIdx
    }

    static func formatHMS(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    static func parseTimeHintSeconds(_ hint: String) -> Double? {
        // Accept "HH:MM:SS" or "MM:SS"
        let parts = hint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
            .map { String($0) }

        if parts.count == 2 {
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        }
        if parts.count == 3 {
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        }
        return nil
    }

    private static func bucketCount(for durationSeconds: Double) -> Int {
        // Aim ~2 minutes per bucket, clamp 12...60
        let ideal = Int((durationSeconds / 120.0).rounded(.toNearestOrAwayFromZero))
        return min(60, max(12, ideal))
    }

    private static func splitEvenly(_ text: String, count: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, count > 0 else { return [] }

        let total = trimmed.count
        if total <= count { return Array(repeating: trimmed, count: 1) }

        let chunkSize = max(1, total / count)
        var out: [String] = []
        out.reserveCapacity(count)

        var start = trimmed.startIndex
        while start < trimmed.endIndex {
            let end = trimmed.index(start, offsetBy: chunkSize, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
            out.append(String(trimmed[start..<end]))
            start = end
        }

        // Adjust to requested count by merging/truncating
        if out.count > count {
            out = Array(out.prefix(count))
        } else if out.count < count, let last = out.last {
            out.append(contentsOf: Array(repeating: last, count: count - out.count))
        }

        return out
    }

    private static func countMatches(in text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.numberOfMatches(in: text, options: [], range: range)
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1, max(0, x))
    }

    private static func snippetFrom(_ text: String) -> String? {
        let t = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if t.count <= 200 { return t }
        return String(t.prefix(200)) + "…"
    }
}
