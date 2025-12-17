import SwiftUI
import Charts

struct SpeakerInsightsView: View {
    let insights: [SpeakerInsight]

    @EnvironmentObject private var l10n: LocalizationService

    @State private var markedIDs: Set<UUID> = []

    private var markedInsights: [SpeakerInsight] {
        insights.filter { markedIDs.contains($0.id) }
    }

    private func overallScore(for s: SpeakerInsight) -> Int? {
        let values: [Int] = [
            s.activityScore,
            s.competenceScore,
            s.emotionControlScore,
            s.conflictHandlingScore
        ].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return Int(round(Double(values.reduce(0, +)) / Double(values.count)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if insights.isEmpty {
                Text(l10n.t("No speaker evaluation yet", ru: "Пока нет оценки по собеседникам"))
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            } else {
                header
                speakersTable
                comparison
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // Default: all speakers included in comparison.
            if markedIDs.isEmpty {
                markedIDs = Set(insights.map { $0.id })
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.t("Speakers", ru: "Собеседники"))
                    .font(.headline)
                Text("\(insights.count)")
                    .foregroundColor(.secondary)
                Spacer()
                Text(l10n.t("Marked", ru: "Отмечено") + ": \(markedIDs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(insights) { s in
                        SpeakerChip(
                            name: s.name,
                            isMarked: markedIDs.contains(s.id),
                            action: {
                                if markedIDs.contains(s.id) {
                                    markedIDs.remove(s.id)
                                } else {
                                    markedIDs.insert(s.id)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            Text(l10n.t("Mark speakers to compare them below.", ru: "Отмечайте собеседников — ниже появится сравнение колонками."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var speakersTable: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            SpeakersTable(
                insights: insights,
                overallScore: { overallScore(for: $0) },
                l10n: l10n
            )
            .fixedSize(horizontal: true, vertical: false)
            .padding(.bottom, 1)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l10n.t("Comparison", ru: "Сравнение"))
                    .font(.headline)
                Spacer()
                if !markedInsights.isEmpty {
                    Text(l10n.t("Showing", ru: "Показываем") + ": \(markedInsights.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if markedInsights.isEmpty {
                Text(l10n.t("Mark speakers above to compare them here.", ru: "Отметьте собеседников сверху — здесь появится сравнение."))
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            } else {
                ComparisonResponsiveGrid(
                    speakers: markedInsights,
                    overallScore: { overallScore(for: $0) }
                )
            }
        }
    }
}

private struct SpeakersTable: View {
    let insights: [SpeakerInsight]
    let overallScore: (SpeakerInsight) -> Int?
    let l10n: LocalizationService

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ForEach(Array(insights.enumerated()), id: \.element.id) { idx, s in
                row(for: s)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(idx.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlColor).opacity(0.35))
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text(l10n.t("Speaker", ru: "Собеседник"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)

            Text(l10n.t("Lang", ru: "Язык"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(l10n.t("Overall", ru: "Итог"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 84, alignment: .leading)

            Text(l10n.t("Activity", ru: "Активность"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160, alignment: .leading)

            Text(l10n.t("Competence", ru: "Компетентность"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 190, alignment: .leading)

            Text(l10n.t("Emotion", ru: "Эмоции"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160, alignment: .leading)

            Text(l10n.t("Conflict", ru: "Конфликт"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 160, alignment: .leading)
        }
    }

    private func row(for s: SpeakerInsight) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name)
                    .font(.system(size: 13, weight: .semibold))

                if let role = s.role, !role.isEmpty {
                    Text(role)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
            .help(s.name)

            Group {
                if let lang = s.language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
                    Text("\(LanguageUtils.flagEmoji(forLanguageRaw: lang)) \(lang)")
                        .foregroundColor(.secondary)
                        .help(lang)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)

            OverallBadge(score: overallScore(s))
                .frame(width: 84, alignment: .leading)

            MetricCell(
                title: l10n.t("Activity", ru: "Активность"),
                icon: "bolt.fill",
                tint: .orange,
                score: s.activityScore
            )
            .frame(width: 160, alignment: .leading)

            MetricCell(
                title: l10n.t("Competence", ru: "Компетентность"),
                icon: "brain.head.profile",
                tint: .accentColor,
                score: s.competenceScore
            )
            .frame(width: 190, alignment: .leading)

            MetricCell(
                title: l10n.t("Emotion", ru: "Эмоции"),
                icon: "face.smiling",
                tint: .green,
                score: s.emotionControlScore
            )
            .frame(width: 160, alignment: .leading)

            MetricCell(
                title: l10n.t("Conflict", ru: "Конфликт"),
                icon: "exclamationmark.triangle",
                tint: .red,
                score: s.conflictHandlingScore
            )
            .frame(width: 160, alignment: .leading)
        }
    }
}

private struct SpeakerChip: View {
    let name: String
    let isMarked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isMarked ? .accentColor : .secondary)
                Text(name)
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlColor))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isMarked ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

private struct OverallBadge: View {
    let score: Int?

    var body: some View {
        if let score {
            Text("\(score)%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(scoreColor(score))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(scoreColor(score).opacity(0.12))
                .cornerRadius(8)
        } else {
            Text("—")
                .foregroundColor(.secondary)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<50: return .red
        case 50..<75: return .orange
        default: return .green
        }
    }
}

private struct MetricCell: View {
    let title: String
    let icon: String
    let tint: Color
    let score: Int?

    var body: some View {
        if let score {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                ProgressView(value: Double(score), total: 100)
                Text("\(score)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .help("\(title): \(score)")
        } else {
            Text("—")
                .foregroundColor(.secondary)
        }
    }
}

private struct ComparisonResponsiveGrid: View {
    let speakers: [SpeakerInsight]
    let overallScore: (SpeakerInsight) -> Int?

    private let minCardWidth: CGFloat = 360
    private let spacing: CGFloat = 12

    var body: some View {
        Group {
            if speakers.count <= 3 {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(speakers) { s in
                        SpeakerCompareColumn(speaker: s, overallScore: overallScore(s))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(speakers) { s in
                            SpeakerCompareColumn(speaker: s, overallScore: overallScore(s))
                                .frame(width: minCardWidth)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct SpeakerCompareColumn: View {
    let speaker: SpeakerInsight
    let overallScore: Int?

    @EnvironmentObject private var l10n: LocalizationService

    private var languageLine: String? {
        guard let lang = speaker.language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty else {
            return nil
        }
        return "\(LanguageUtils.flagEmoji(forLanguageRaw: lang)) \(lang)"
    }

    private var chartData: [(String, Int, String)] {
        var items: [(String, Int, String)] = []
        if let v = speaker.activityScore { items.append((l10n.t("Activity", ru: "Активность"), v, "bolt.fill")) }
        if let v = speaker.competenceScore { items.append((l10n.t("Competence", ru: "Компетентность"), v, "brain.head.profile")) }
        if let v = speaker.emotionControlScore { items.append((l10n.t("Emotion", ru: "Эмоции"), v, "face.smiling")) }
        if let v = speaker.conflictHandlingScore { items.append((l10n.t("Conflict", ru: "Конфликт"), v, "exclamationmark.triangle")) }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(speaker.name)
                        .font(.headline)
                    if let role = speaker.role, !role.isEmpty {
                        Text(role)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let lang = languageLine {
                        Text(lang)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                OverallBadge(score: overallScore)
            }

            if !chartData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("Main indicators", ru: "Основные показатели"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Chart {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { _, item in
                            BarMark(
                                x: .value("Score", item.1),
                                y: .value("Metric", item.0)
                            )
                            .foregroundStyle(Color.accentColor)
                            .annotation(position: .trailing) {
                                Text("\(item.1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .chartXScale(domain: 0...100)
                    .frame(height: 140)

                    HStack(spacing: 12) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { _, item in
                            KPIChip(icon: item.2, title: item.0, value: item.1)
                        }
                    }
                }
            }

            if let ideas = speaker.ideasAndProposals, !ideas.isEmpty {
                BulletSection(title: l10n.t("Ideas & proposals", ru: "Идеи и предложения"), items: ideas)
            }

            if let strengths = speaker.strengths, !strengths.isEmpty {
                BulletSection(title: l10n.t("Strengths", ru: "Сильные стороны"), items: strengths)
            }

            if let risks = speaker.risks, !risks.isEmpty {
                BulletSection(title: l10n.t("Risks", ru: "Риски"), items: risks)
            }

            if let quotes = speaker.evidenceQuotes, !quotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("Evidence", ru: "Цитаты"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(Array(quotes.prefix(8).enumerated()), id: \.offset) { _, q in
                        Text("“\(q)”")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

private struct KPIChip: View {
    let icon: String
    let title: String
    let value: Int

    private var tint: Color {
        switch icon {
        case "bolt.fill": return .orange
        case "brain.head.profile": return .accentColor
        case "face.smiling": return .green
        case "exclamationmark.triangle": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlColor))
        .cornerRadius(10)
        .help("\(title): \(value)")
    }
}

private struct BulletSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
