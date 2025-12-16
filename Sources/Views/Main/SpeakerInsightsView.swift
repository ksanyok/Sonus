import SwiftUI

struct SpeakerInsightsView: View {
    let insights: [SpeakerInsight]

    @EnvironmentObject private var l10n: LocalizationService

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
                ForEach(insights) { s in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name)
                                    .font(.headline)
                                if let role = s.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }

                        VStack(spacing: 10) {
                            ScoreRow(title: l10n.t("Activity", ru: "Активность"), score: s.activityScore)
                            ScoreRow(title: l10n.t("Competence", ru: "Компетентность"), score: s.competenceScore)
                            ScoreRow(title: l10n.t("Emotion control", ru: "Контроль эмоций"), score: s.emotionControlScore)
                            ScoreRow(title: l10n.t("Conflict handling", ru: "Работа с конфликтом"), score: s.conflictHandlingScore)
                        }

                        if let ideas = s.ideasAndProposals, !ideas.isEmpty {
                            BulletSection(title: l10n.t("Ideas & proposals", ru: "Идеи и предложения"), items: ideas)
                        }

                        if let strengths = s.strengths, !strengths.isEmpty {
                            BulletSection(title: l10n.t("Strengths", ru: "Сильные стороны"), items: strengths)
                        }

                        if let risks = s.risks, !risks.isEmpty {
                            BulletSection(title: l10n.t("Risks", ru: "Риски"), items: risks)
                        }

                        if let quotes = s.evidenceQuotes, !quotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(l10n.t("Evidence", ru: "Цитаты"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                ForEach(Array(quotes.prefix(6).enumerated()), id: \.offset) { _, q in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScoreRow: View {
    let title: String
    let score: Int?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            if let score {
                ProgressView(value: Double(score), total: 100)
                    .frame(maxWidth: .infinity)
                Text("\(score)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 34, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
