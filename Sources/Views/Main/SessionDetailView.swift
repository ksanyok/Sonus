import SwiftUI
import AppKit

struct SessionDetailView: View {
    let sessionID: UUID
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @StateObject private var audioPlayer = AudioPlayer()
    private var session: Session? {
        viewModel.sessions.first(where: { $0.id == sessionID })
    }

    private func needsAnalysisUpdate(_ session: Session) -> Bool {
        guard session.analysis != nil else { return false }
        let v = session.analysisSchemaVersion ?? 0
        return v < OpenAIClient.analysisSchemaVersion
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let customTitle = session.customTitle, !customTitle.isEmpty {
                                    Text(customTitle)
                                        .font(.largeTitle).bold()
                                } else {
                                    Text(session.date, format: .dateTime.year().month().day().hour().minute())
                                        .font(.largeTitle).bold()
                                }
                                HStack(spacing: 8) {
                                    Label(l10n.t(session.category.displayNameEn, ru: session.category.displayNameRu), systemImage: session.category.icon)
                                    Text("•")
                                    Text(session.date, format: .dateTime.year().month().day().hour().minute())
                                    Text("•")
                                    Text(formatDuration(session.duration))
                                }
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 10) {
                                HStack(spacing: 10) {
                                    AnalyzeActionButton(
                                        isProcessing: session.isProcessing,
                                        lastAnalyzedAt: session.analysisUpdatedAt,
                                        needsUpdate: needsAnalysisUpdate(session),
                                        onAnalyze: { viewModel.processSession(session) }
                                    )
                                    Button(l10n.t("Delete", ru: "Удалить"), role: .destructive) { viewModel.deleteSession(session) }
                                        .buttonStyle(.bordered)
                                }
                                if session.isProcessing {
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Text(viewModel.processingStatus[session.id] ?? l10n.t("Processing…", ru: "Обработка…"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        // Unified Player
                        UnifiedPlayerView(audioPlayer: audioPlayer, session: session, analysis: session.analysis)
                            .padding(.horizontal)

                        if let analysis = session.analysis {
                            // Overview
                            OverviewGrid(analysis: analysis)
                                .padding(.horizontal)

                            // Detailed Analysis
                            DisclosureGroup(
                                content: { DetailedAnalysisView(analysis: analysis).padding(.top) },
                                label: { Text(l10n.t("Detailed Analysis", ru: "Подробный анализ")).font(.title2).bold() }
                            )
                            .padding(.horizontal)

                            // Reminders
                            DisclosureGroup(
                                content: { RemindersView(analysis: analysis).padding(.top) },
                                label: { Text(l10n.t("Reminders", ru: "Напоминания")).font(.title2).bold() }
                            )
                            .padding(.horizontal)

                            // Speaker Insights
                            if !analysis.speakerInsights.isEmpty {
                                DisclosureGroup(
                                    content: { SpeakerInsightsView(insights: analysis.speakerInsights).padding(.top) },
                                    label: { Text(l10n.t("Speaker Insights", ru: "Инсайты по спикерам")).font(.title2).bold() }
                                )
                                .padding(.horizontal)
                            }

                            // Transcript
                            DisclosureGroup(
                                content: { TranscriptView(transcript: session.transcript).frame(height: 400).padding(.top) },
                                label: { Text(l10n.t("Transcript", ru: "Транскрипт")).font(.title2).bold() }
                            )
                            .padding(.horizontal)
                        } else {
                            Text(l10n.t("No analysis available", ru: "Нет анализа"))
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                VStack {
                    Spacer()
                    Text(l10n.t("Session not found", ru: "Сессия не найдена"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    private var displayDuration: TimeInterval {
        let effectiveDuration = audioPlayer.duration > 0 ? audioPlayer.duration : (session?.duration ?? 0)
        return effectiveDuration > 0 ? effectiveDuration : 0
    }

    private var playbackProgress: Binding<Double> {
        Binding(get: {
            guard displayDuration > 0 else { return 0 }
            return audioPlayer.currentTime / displayDuration
        }, set: { ratio in
            guard displayDuration > 0 else { return }
            audioPlayer.seek(to: ratio * displayDuration)
        })
    }
}

private struct AnalyzeActionButton: View {
    let isProcessing: Bool
    let lastAnalyzedAt: Date?
    let needsUpdate: Bool
    let onAnalyze: () -> Void

    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                onAnalyze()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: needsUpdate ? "sparkles" : "wand.and.stars")
                    Text(l10n.t("Analyze", ru: "Анализ"))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(needsUpdate ? .orange : .accentColor)
            .disabled(isProcessing)

            if let lastAnalyzedAt {
                Text(lastAnalyzedString(lastAnalyzedAt))
                    .font(.caption2)
                    .foregroundColor(needsUpdate ? .orange : .secondary)
            } else {
                Text(l10n.t("Not analyzed yet", ru: "Ещё не анализировали"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if needsUpdate {
                Text(l10n.t("New insights available", ru: "Доступны новые метрики"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func lastAnalyzedString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = l10n.locale
        df.dateStyle = .medium
        df.timeStyle = .short
        return l10n.t("Last: ", ru: "Последний: ") + df.string(from: date)
    }
}

private struct RemindersView: View {
    let analysis: Analysis
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !analysis.commitments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Commitments", ru: "Обещали/договорились"), systemImage: "paperplane")
                        .font(.headline)
                    ForEach(Array(analysis.commitments.enumerated()), id: \.offset) { _, c in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 10) {
                                if let owner = c.owner, !owner.isEmpty {
                                    Text(owner)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let due = c.dueDateISO, !due.isEmpty {
                                    Text(due)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let conf = c.confidence {
                                    Text("\(conf)%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            if let notes = c.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if !analysis.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Action items", ru: "Задачи"), systemImage: "checkmark.circle")
                        .font(.headline)
                    ForEach(Array(analysis.actionItems.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 10) {
                                if let owner = item.owner, !owner.isEmpty {
                                    Text(owner)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let due = item.dueDateISO, !due.isEmpty {
                                    Text(due)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let pr = item.priority, !pr.isEmpty {
                                    Text(pr)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            if let notes = item.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if analysis.commitments.isEmpty && analysis.actionItems.isEmpty {
                Text(l10n.t("No reminders yet. Run analysis again and they will appear here.", ru: "Пока нет напоминаний. После повторного анализа они появятся здесь."))
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            }
        }
    }
}

struct OverviewGrid: View {
    let analysis: Analysis
    @EnvironmentObject private var l10n: LocalizationService

    private let metricColumns = [
        GridItem(.adaptive(minimum: 190), spacing: 14)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Card
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("Summary", ru: "Итог"), systemImage: "text.alignleft")
                    .font(.headline)
                Text(analysis.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            LazyVGrid(columns: metricColumns, spacing: 14) {
                MetricCard(title: l10n.t("Score", ru: "Оценка"), value: "\(analysis.score)%", icon: "chart.bar.fill", color: .blue)
                MetricCard(title: l10n.t("Sentiment", ru: "Тон"), value: analysis.sentiment, icon: "face.smiling", color: .green)
                MetricCard(title: l10n.t("Engagement", ru: "Вовлечённость"), value: "\(analysis.engagementScore)%", icon: "person.2.wave.2.fill", color: .orange)
                MetricCard(title: l10n.t("Sales Prob.", ru: "Вероятность"), value: "\(analysis.salesProbability)%", icon: "cart.badge.plus", color: .pink)

                MetricCard(
                    title: l10n.t("Objections", ru: "Возражения"),
                    value: "\(analysis.objections.count)",
                    icon: "exclamationmark.bubble",
                    color: .red
                )
                MetricCard(
                    title: l10n.t("Key moments", ru: "Ключевые"),
                    value: "\(analysis.keyMoments.count)",
                    icon: "bookmark.fill",
                    color: .purple
                )
                MetricCard(
                    title: l10n.t("Reminders", ru: "Напоминания"),
                    value: "\(analysis.commitments.count + analysis.actionItems.count)",
                    icon: "checklist",
                    color: .orange
                )
                MetricCard(
                    title: l10n.t("Questions", ru: "Вопросы"),
                    value: "\(analysis.conversationMetrics?.questionCount ?? 0)",
                    icon: "questionmark.bubble",
                    color: .blue
                )
            }
            
            // Speakers / Languages
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(l10n.t("Speakers", ru: "Участники"), systemImage: "person.3.fill")
                    Spacer()
                    Text(l10n.t("\(analysis.speakerCount ?? analysis.participants.count) participant(s)", ru: "\(analysis.speakerCount ?? analysis.participants.count) участник(ов)"))
                        .foregroundColor(.secondary)
                }
                WrapChips(items: analysis.participants)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Label(l10n.t("Languages", ru: "Языки"), systemImage: "globe")
                WrapChips(items: analysis.languages)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            if let stop = analysis.stopWords, !stop.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("Stop words / fillers", ru: "Слова-паразиты"), systemImage: "ellipsis.message")
                    WrapChips(items: stop)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Intent
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("Customer Intent", ru: "Намерение клиента"), systemImage: "cart.fill")
                    .font(.headline)
                Text(analysis.customerIntent)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            if !analysis.nextSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Next Steps", ru: "Следующие шаги"), systemImage: "arrow.turn.up.right")
                        .font(.headline)
                    ForEach(analysis.nextSteps, id: \.self) { step in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .padding(.top, 6)
                            Text(step)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let style = analysis.communicationStyle {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Communication style", ru: "Стиль общения"), systemImage: "quote.bubble")
                        .font(.headline)

                    if let formality = style.formality, !formality.isEmpty {
                        HStack {
                            Text(l10n.t("Formality", ru: "Формат"))
                            Spacer()
                            Text(formality)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let pacing = style.pacing, !pacing.isEmpty {
                        HStack {
                            Text(l10n.t("Pacing", ru: "Темп"))
                            Spacer()
                            Text(pacing)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let structure = style.structure, !structure.isEmpty {
                        HStack {
                            Text(l10n.t("Structure", ru: "Структура"))
                            Spacer()
                            Text(structure)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let conflict = style.conflictLevel {
                        HStack {
                            Text(l10n.t("Conflict", ru: "Конфликтность"))
                            Spacer()
                            Text("\(conflict)%")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let tone = style.tone, !tone.isEmpty {
                        WrapChips(items: tone)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let client = analysis.client {
                ParticipantProfileCard(title: l10n.t("Client", ru: "Клиент"), profile: client)
            }

            if let others = analysis.otherParticipants, !others.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Other participants", ru: "Другие собеседники"), systemImage: "person.3")
                        .font(.headline)
                    ForEach(Array(others.enumerated()), id: \.offset) { _, p in
                        ParticipantProfileRow(profile: p)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let insights = analysis.clientInsights {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Client analysis", ru: "Анализ клиента"), systemImage: "person.text.rectangle")
                        .font(.headline)

                    if let s = insights.summary, !s.isEmpty {
                        Text(s)
                            .foregroundColor(.secondary)
                    }

                    if let goals = insights.goals, !goals.isEmpty {
                        BulletListCard(title: l10n.t("Goals", ru: "Цели"), items: goals)
                    }
                    if let pains = insights.painPoints, !pains.isEmpty {
                        BulletListCard(title: l10n.t("Pain points", ru: "Боли/проблемы"), items: pains)
                    }
                    if let pr = insights.priorities, !pr.isEmpty {
                        BulletListCard(title: l10n.t("Priorities", ru: "Приоритеты"), items: pr)
                    }
                    if let budget = insights.budget, !budget.isEmpty {
                        HStack {
                            Text(l10n.t("Budget", ru: "Бюджет"))
                            Spacer()
                            Text(budget).foregroundColor(.secondary)
                        }
                    }
                    if let timeline = insights.timeline, !timeline.isEmpty {
                        HStack {
                            Text(l10n.t("Timeline", ru: "Сроки"))
                            Spacer()
                            Text(timeline).foregroundColor(.secondary)
                        }
                    }
                    if let dm = insights.decisionMakers, !dm.isEmpty {
                        BulletListCard(title: l10n.t("Decision makers", ru: "ЛПР/участники решения"), items: dm)
                    }
                    if let dp = insights.decisionProcess, !dp.isEmpty {
                        HStack(alignment: .top) {
                            Text(l10n.t("Decision process", ru: "Процесс решения"))
                            Spacer()
                            Text(dp)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let sig = insights.buyingSignals, !sig.isEmpty {
                        BulletListCard(title: l10n.t("Buying signals", ru: "Сигналы интереса"), items: sig)
                    }
                    if let risks = insights.risks, !risks.isEmpty {
                        BulletListCard(title: l10n.t("Risks", ru: "Риски"), items: risks)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let entities = analysis.extractedEntities, entities.hasAnyData {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Extracted data", ru: "Извлечённые данные"), systemImage: "tray.full")
                        .font(.headline)

                    if let companies = entities.companies, !companies.isEmpty {
                        Text(l10n.t("Companies", ru: "Компании"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: companies)
                    }
                    if let people = entities.people, !people.isEmpty {
                        Text(l10n.t("People", ru: "Люди"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: people)
                    }
                    if let products = entities.products, !products.isEmpty {
                        Text(l10n.t("Products", ru: "Продукты"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: products)
                    }
                    if let urls = entities.urls, !urls.isEmpty {
                        Text(l10n.t("Links", ru: "Ссылки"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: urls)
                    }
                    if let emails = entities.emails, !emails.isEmpty {
                        Text(l10n.t("Email", ru: "Email"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: emails)
                    }
                    if let phones = entities.phones, !phones.isEmpty {
                        Text(l10n.t("Phones", ru: "Телефоны"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: phones)
                    }
                    if let dates = entities.dateMentions, !dates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n.t("Dates / deadlines", ru: "Даты/дедлайны"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(Array(dates.enumerated()), id: \.offset) { _, d in
                                HStack(alignment: .top) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.text)
                                        if let iso = d.isoDate, !iso.isEmpty {
                                            Text(iso)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let ctx = d.context, !ctx.isEmpty {
                                            Text(ctx)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let m = analysis.conversationMetrics {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Conversation metrics", ru: "Метрики разговора"), systemImage: "waveform.path.ecg")
                        .font(.headline)

                    if let share = m.talkTimeShare, !share.isEmpty {
                        let sales = share["sales"]
                        let client = share["client"]
                        if sales != nil || client != nil {
                            HStack {
                                Text(l10n.t("Talk time", ru: "Доля речи"))
                                Spacer()
                                Text("\(l10n.t("sales", ru: "продавец")) \(sales ?? 0)% • \(l10n.t("client", ru: "клиент")) \(client ?? 0)%")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if let q = m.questionCount {
                        HStack {
                            Text(l10n.t("Questions", ru: "Вопросов"))
                            Spacer()
                            Text("\(q)")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let i = m.interruptionsCount {
                        HStack {
                            Text(l10n.t("Interruptions", ru: "Перебиваний"))
                            Spacer()
                            Text("\(i)")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let mono = m.monologueLongestSeconds {
                        HStack {
                            Text(l10n.t("Longest monologue", ru: "Длинный монолог"))
                            Spacer()
                            Text("\(mono)\(l10n.t("s", ru: "с"))")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let trend = m.sentimentTrend, !trend.isEmpty {
                        HStack {
                            Text(l10n.t("Sentiment trend", ru: "Тренд настроения"))
                            Spacer()
                            Text(trend)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let flags = m.riskFlags, !flags.isEmpty {
                        BulletListCard(title: l10n.t("Risk flags", ru: "Флаги риска"), items: flags)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
}

struct DetailedAnalysisView: View {
    let analysis: Analysis
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Criteria
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("Evaluation criteria", ru: "Критерии оценки"), systemImage: "checklist")
                    .font(.headline)
                
                ForEach(analysis.criteria) { criterion in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(criterion.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(criterion.comment)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(criterion.score)/10")
                            .font(.headline)
                            .foregroundColor(criterion.score >= 7 ? .green : (criterion.score >= 4 ? .orange : .red))
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // Recommendations
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("Recommendations", ru: "Рекомендации"), systemImage: "lightbulb.fill")
                    .font(.headline)
                
                ForEach(analysis.recommendations, id: \.self) { rec in
                    HStack(alignment: .top) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .padding(.top, 6)
                        Text(rec)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            if !analysis.objections.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Objections", ru: "Возражения"), systemImage: "exclamationmark.bubble")
                        .font(.headline)
                    ForEach(analysis.objections, id: \.self) { obj in
                        HStack(alignment: .top) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 10))
                                .padding(.top, 4)
                            Text(obj)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if !analysis.keyMoments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Key moments", ru: "Ключевые моменты"), systemImage: "bookmark")
                        .font(.headline)
                    ForEach(Array(analysis.keyMoments.enumerated()), id: \.offset) { _, m in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                if let t = m.type, !t.isEmpty {
                                    Text(t)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                if let s = m.speaker, !s.isEmpty {
                                    Text(s)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let th = m.timeHint, !th.isEmpty {
                                    Text(th)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(m.text)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if !analysis.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("Action items & deadlines", ru: "Задачи и дедлайны"), systemImage: "checkmark.circle")
                        .font(.headline)
                    ForEach(Array(analysis.actionItems.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack(spacing: 10) {
                                if let owner = item.owner, !owner.isEmpty {
                                    Text(owner)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let due = item.dueDateISO, !due.isEmpty {
                                    Text(due)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let pr = item.priority, !pr.isEmpty {
                                    Text(pr)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            if let notes = item.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
}

private struct ParticipantProfileCard: View {
    let title: String
    let profile: ParticipantProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "person.crop.circle")
                .font(.headline)
            ParticipantProfileRow(profile: profile)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

private struct ParticipantProfileRow: View {
    let profile: ParticipantProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let nameOrLabel = [profile.name, profile.label].compactMap({ $0 }).first, !nameOrLabel.isEmpty {
                Text(nameOrLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            if let role = profile.role, !role.isEmpty {
                Text(role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let company = profile.company, !company.isEmpty {
                Text(company)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let title = profile.title, !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let notes = profile.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let contact = profile.contact {
                if let emails = contact.emails, !emails.isEmpty {
                    WrapChips(items: emails)
                }
                if let phones = contact.phones, !phones.isEmpty {
                    WrapChips(items: phones)
                }
                if let messengers = contact.messengers, !messengers.isEmpty {
                    WrapChips(items: messengers)
                }
            }
        }
    }
}

private struct BulletListCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(items, id: \.self) { it in
                HStack(alignment: .top) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .padding(.top, 6)
                    Text(it)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private extension ExtractedEntities {
    var hasAnyData: Bool {
        let hasStrings = (companies?.isEmpty == false)
            || (people?.isEmpty == false)
            || (products?.isEmpty == false)
            || (locations?.isEmpty == false)
            || (urls?.isEmpty == false)
            || (emails?.isEmpty == false)
            || (phones?.isEmpty == false)
        let hasDates = (dateMentions?.isEmpty == false)
        return hasStrings || hasDates
    }
}

struct TranscriptView: View {
    let transcript: String?
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        VStack(alignment: .leading) {
            if let text = transcript {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            } else {
                Text(l10n.t("No transcript available", ru: "Нет транскрипта"))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct WrapChips: View {
    let items: [String]
    
    var body: some View {
        FlexibleView(data: items, spacing: 8, alignment: .leading) { item in
            Text(item)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
        }
    }
}

// Simple flexible wrap layout
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let rows = buildRows(for: geo.size.width)
            VStack(alignment: alignment, spacing: spacing) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(rows[row], id: \.self) { element in
                            content(element)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func buildRows(for availableWidth: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for element in data {
            let w = estimateWidth(for: element)
            if currentWidth + w + spacing > availableWidth {
                rows.append([element])
                currentWidth = w + spacing
            } else {
                if rows[rows.count - 1].isEmpty {
                    rows[rows.count - 1].append(element)
                } else {
                    rows[rows.count - 1].append(element)
                }
                currentWidth += w + spacing
            }
        }
        return rows
    }
    
    private func estimateWidth(for element: Data.Element) -> CGFloat {
        let attr = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))]
        let size = (String(describing: element) as NSString).size(withAttributes: attr)
        return size.width + 20 // padding used in chip
    }
}
