import SwiftUI

struct SpeakerInsightsView: View {
    let insights: [SpeakerInsight]

    @EnvironmentObject private var l10n: LocalizationService

    @State private var hiddenIDs: Set<UUID> = []
    @State private var showOnlyVisible = false
    @State private var selection: SpeakerInsight.ID? = nil

    private var visibleInsights: [SpeakerInsight] {
        if !showOnlyVisible { return insights }
        return insights.filter { !hiddenIDs.contains($0.id) }
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
                HStack {
                    Toggle(l10n.t("Show only visible", ru: "Показывать только видимых"), isOn: $showOnlyVisible)
                        .toggleStyle(.switch)
                    Spacer()
                    Button(l10n.t("Show all", ru: "Показать всех")) {
                        hiddenIDs.removeAll()
                        showOnlyVisible = false
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 14) {
                    Table(visibleInsights, selection: $selection) {
                        TableColumn(l10n.t("Visible", ru: "Видим")) { s in
                            Toggle("", isOn: Binding(
                                get: { !hiddenIDs.contains(s.id) },
                                set: { isVisible in
                                    if isVisible {
                                        hiddenIDs.remove(s.id)
                                    } else {
                                        hiddenIDs.insert(s.id)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        .width(min: 70, ideal: 70, max: 80)

                        TableColumn(l10n.t("Speaker", ru: "Собеседник"), value: \.name)
                            .width(min: 140, ideal: 180)

                        TableColumn(l10n.t("Role", ru: "Роль")) { s in
                            Text(s.role ?? "")
                                .foregroundColor(.secondary)
                        }
                        .width(min: 120, ideal: 160)

                        TableColumn(l10n.t("Activity", ru: "Активность")) { s in
                            ScoreCell(score: s.activityScore)
                        }
                        .width(min: 110, ideal: 130)

                        TableColumn(l10n.t("Competence", ru: "Компетентность")) { s in
                            ScoreCell(score: s.competenceScore)
                        }
                        .width(min: 130, ideal: 150)

                        TableColumn(l10n.t("Emotion", ru: "Эмоции")) { s in
                            ScoreCell(score: s.emotionControlScore)
                        }
                        .width(min: 110, ideal: 130)

                        TableColumn(l10n.t("Conflict", ru: "Конфликт")) { s in
                            ScoreCell(score: s.conflictHandlingScore)
                        }
                        .width(min: 110, ideal: 130)
                    }
                    .frame(minHeight: 260)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        if let selected = insights.first(where: { $0.id == selection }) {
                            Text(selected.name)
                                .font(.headline)

                            if let role = selected.role, !role.isEmpty {
                                Text(role)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(spacing: 10) {
                                ScoreRow(title: l10n.t("Activity", ru: "Активность"), score: selected.activityScore)
                                ScoreRow(title: l10n.t("Competence", ru: "Компетентность"), score: selected.competenceScore)
                                ScoreRow(title: l10n.t("Emotion control", ru: "Контроль эмоций"), score: selected.emotionControlScore)
                                ScoreRow(title: l10n.t("Conflict handling", ru: "Работа с конфликтом"), score: selected.conflictHandlingScore)
                            }

                            if let ideas = selected.ideasAndProposals, !ideas.isEmpty {
                                BulletSection(title: l10n.t("Ideas & proposals", ru: "Идеи и предложения"), items: ideas)
                            }

                            if let strengths = selected.strengths, !strengths.isEmpty {
                                BulletSection(title: l10n.t("Strengths", ru: "Сильные стороны"), items: strengths)
                            }

                            if let risks = selected.risks, !risks.isEmpty {
                                BulletSection(title: l10n.t("Risks", ru: "Риски"), items: risks)
                            }

                            if let quotes = selected.evidenceQuotes, !quotes.isEmpty {
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
                        } else {
                            Text(l10n.t("Select a speaker to see details", ru: "Выберите собеседника, чтобы увидеть детали"))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 360, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScoreCell: View {
    let score: Int?

    var body: some View {
        if let score {
            HStack(spacing: 8) {
                ProgressView(value: Double(score), total: 100)
                Text("\(score)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        } else {
            Text("—")
                .foregroundColor(.secondary)
        }
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
