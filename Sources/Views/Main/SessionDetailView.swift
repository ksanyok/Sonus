import SwiftUI
import AppKit
import Charts

struct SessionDetailView: View {
    let sessionID: UUID
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @StateObject private var audioPlayer = AudioPlayer()
    
    private var session: Session? {
        viewModel.sessions.first(where: { $0.id == sessionID })
    }

    @State private var selectedTab: DetailTab = .overview
    @State private var isExporting = false
    @State private var editingSession: Session?

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case analysis = "Analysis"
        case speakers = "Speakers"
        case transcript = "Transcript"
        case actions = "Actions"
    }

    var body: some View {
        ZStack {
            if let session {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        SessionHeaderView(
                            session: session,
                            viewModel: viewModel,
                            isExporting: $isExporting,
                            onEdit: { editingSession = session }
                        )
                            .padding(.horizontal)
                            .padding(.top, 16)

                        // Unified Player
                        UnifiedPlayerView(audioPlayer: audioPlayer, session: session, analysis: session.analysis)
                            .padding(.horizontal)

                        if let analysis = session.analysis {
                            // Segmented Control for Tabs
                            Picker("", selection: $selectedTab) {
                                ForEach(DetailTab.allCases, id: \.self) { tab in
                                    Text(l10n.t(tab.rawValue, ru: tabRu(tab))).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // Content Area
                            VStack(spacing: 20) {
                                switch selectedTab {
                                case .overview:
                                    OverviewGrid(analysis: analysis)
                                case .analysis:
                                    DetailedAnalysisView(
                                        analysis: analysis,
                                        transcript: session.transcript,
                                        onSeek: { t in
                                            audioPlayer.seek(to: t)
                                        }
                                    )
                                case .speakers:
                                    SpeakerInsightsView(insights: analysis.speakerInsights)
                                case .transcript:
                                    TranscriptView(transcript: session.transcript)
                                case .actions:
                                    RemindersView(analysis: analysis)
                                }
                            }
                            .padding(.horizontal)
                            .transition(.opacity)
                        } else {
                            Text(l10n.t("No analysis available", ru: "Нет анализа"))
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                
                // Overlays
                if isExporting {
                    LoadingOverlay(message: l10n.t("Generating PDF Report...", ru: "Создание PDF отчета..."))
                }
                
                if session.isProcessing {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.processingStatus[session.id] ?? l10n.t("Analyzing...", ru: "Анализ..."))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
        .sheet(item: $editingSession, onDismiss: { editingSession = nil }) { session in
            SessionEditSheet(session: session, viewModel: viewModel)
        }
    }
    
    private func tabRu(_ tab: DetailTab) -> String {
        switch tab {
        case .overview: return "Обзор"
        case .analysis: return "Анализ"
        case .speakers: return "Собеседники"
        case .transcript: return "Транскрипт"
        case .actions: return "Действия"
        }
    }
}

struct SessionHeaderView: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @Binding var isExporting: Bool
    let onEdit: () -> Void
    @EnvironmentObject private var l10n: LocalizationService

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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    SonusLogo(size: 28)
                        .opacity(0.8)
                    
                    Text(session.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }

                HStack(spacing: 16) {
                    Label(l10n.t(session.category.displayNameEn, ru: session.category.displayNameRu), systemImage: session.category.icon)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(formatDuration(session.duration))
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                    if let analysis = session.analysis {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                            Text("\(analysis.speakerCount ?? analysis.participants.count)")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                        if !analysis.languages.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                Text(
                                    analysis.languages
                                        .map { "\(LanguageUtils.flagEmoji(forLanguageRaw: $0)) \($0)" }
                                        .joined(separator: ", ")
                                )
                            }
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    if session.analysis != nil {
                        Button(action: {
                            exportPDF(session: session)
                        }) {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help(l10n.t("Export PDF", ru: "Экспорт PDF"))
                        .disabled(isExporting)
                    }
                    
                    AnalyzeActionButton(
                        isProcessing: session.isProcessing,
                        lastAnalyzedAt: session.analysisUpdatedAt,
                        needsUpdate: needsAnalysisUpdate(session),
                        onAnalyze: { viewModel.processSession(session) }
                    )

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .help(l10n.t("Edit", ru: "Правка"))

                    Button(role: .destructive) {
                        viewModel.deleteSession(session)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
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
    }
    
    
    private func exportPDF(session: Session) {
        isExporting = true
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = l10n.t("Export Report", ru: "Экспорт отчета")
        savePanel.message = l10n.t("Choose a location to save the PDF report.", ru: "Выберите место для сохранения PDF отчета.")
        savePanel.nameFieldStringValue = "Report_\(session.date.formatted(date: .numeric, time: .omitted)).pdf"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                PDFExportService.shared.exportPDF(for: session, to: url) { success in
                    DispatchQueue.main.async {
                        isExporting = false
                        if success {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } else {
                isExporting = false
            }
        }
    }
}

struct AnalyzeActionButton: View {
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

struct OverviewGrid: View {
    let analysis: Analysis
    @EnvironmentObject private var l10n: LocalizationService
    @State private var isNextStepsExpanded = false
    
    private let metricColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Top Stats Row
            HStack(spacing: 20) {
                ScoreCard(
                    title: l10n.t("Score", ru: "Оценка"),
                    value: "\(analysis.score)",
                    subtitle: "/ 100",
                    color: analysis.score >= 70 ? .green : (analysis.score >= 40 ? .orange : .red)
                )
                
                ScoreCard(
                    title: l10n.t("Engagement", ru: "Вовлечённость"),
                    value: "\(analysis.engagementScore)%",
                    subtitle: "",
                    color: .blue
                )
                
                ScoreCard(
                    title: l10n.t("Sales Prob.", ru: "Вероятность"),
                    value: "\(analysis.salesProbability)%",
                    subtitle: "",
                    color: .purple
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("Sentiment", ru: "Настроение"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(analysis.sentiment)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: sentimentIcon(analysis.sentiment))
                            .font(.title)
                            .foregroundColor(sentimentColor(analysis.sentiment))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 100)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Label(l10n.t("Executive Summary", ru: "Краткий итог"), systemImage: "doc.text.fill")
                    .font(.headline)
                Text(analysis.summary)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)

            // In 100 words (quick skim)
            if !analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("In 100 words", ru: "В 100 словах"), systemImage: "text.justify")
                        .font(.headline)
                    Text(limitWords(digest100Words(analysis), to: 100))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            
            // Quick Metrics Grid
            LazyVGrid(columns: metricColumns, spacing: 16) {
                MetricWidget(
                    title: l10n.t("Objections", ru: "Возражения"),
                    value: "\(analysis.objections.count)",
                    icon: "exclamationmark.bubble.fill",
                    color: analysis.objections.isEmpty ? .green : .orange
                )
                MetricWidget(
                    title: l10n.t("Key moments", ru: "Ключевые"),
                    value: "\(analysis.keyMoments.count)",
                    icon: "bookmark.fill",
                    color: .blue
                )
                MetricWidget(
                    title: l10n.t("Questions", ru: "Вопросы"),
                    value: "\(analysis.conversationMetrics?.questionCount ?? 0)",
                    icon: "questionmark.circle.fill",
                    color: .purple
                )
                MetricWidget(
                    title: l10n.t("Interruptions", ru: "Перебивания"),
                    value: "\(analysis.conversationMetrics?.interruptionsCount ?? 0)",
                    icon: "waveform.path.ecg",
                    color: (analysis.conversationMetrics?.interruptionsCount ?? 0) > 5 ? .red : .secondary
                )
            }
            
            // Intent & Next Steps
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Customer Intent", ru: "Намерение"), systemImage: "cart.fill")
                        .font(.headline)
                    Text(analysis.customerIntent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Next Steps", ru: "Следующие шаги"), systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                    
                    if analysis.nextSteps.isEmpty {
                        Text("—")
                            .foregroundColor(.secondary)
                    } else {
                        if isNextStepsExpanded {
                            ForEach(analysis.nextSteps, id: \.self) { step in
                                Text("• " + step)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Button(action: { withAnimation { isNextStepsExpanded = false } }) {
                                Text(l10n.t("Show less", ru: "Свернуть"))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            if let firstStep = analysis.nextSteps.first {
                                Text(firstStep)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            if analysis.nextSteps.count > 1 {
                                Button(action: { withAnimation { isNextStepsExpanded = true } }) {
                                    Text(l10n.t("+ \(analysis.nextSteps.count - 1) more", ru: "+ ещё \(analysis.nextSteps.count - 1)"))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
            }
            
            // Communication Style & Guidance Summary (Moved to Overview)
            if let style = analysis.communicationStyle {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Communication Style", ru: "Стиль общения"), systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                        if let formality = style.formality {
                            StyleBadgeMini(title: l10n.t("Formality", ru: "Формальность"), value: formality)
                        }
                        if let pacing = style.pacing {
                            StyleBadgeMini(title: l10n.t("Pacing", ru: "Темп"), value: pacing)
                        }
                        if let tone = style.tone, !tone.isEmpty {
                            StyleBadgeMini(title: l10n.t("Tone", ru: "Тон"), value: tone.first ?? "")
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
            }
            
            if let guidance = analysis.managerGuidance, let advice = guidance.generalAdvice, !advice.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Key Advice", ru: "Главный совет"), systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(advice.first ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
            }
        }
    }

    private func limitWords(_ text: String, to maxWords: Int) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        guard words.count > maxWords else { return cleaned }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }
    
    private func sentimentIcon(_ s: String) -> String {
        let lower = s.lowercased()
        if lower.contains("positive") || lower.contains("позитив") { return "face.smiling.fill" }
        if lower.contains("negative") || lower.contains("негатив") { return "face.frowning.fill" }
        return "face.dashed"
    }
    
    private func sentimentColor(_ s: String) -> Color {
        let lower = s.lowercased()
        if lower.contains("positive") || lower.contains("позитив") { return .green }
        if lower.contains("negative") || lower.contains("негатив") { return .red }
        return .gray
    }

    private func digest100Words(_ analysis: Analysis) -> String {
        // Make this intentionally different from the full summary by mixing multiple fields.
        var parts: [String] = []
        let summary = analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { parts.append(summary) }

        let intent = analysis.customerIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intent.isEmpty {
            parts.append(l10n.t("Intent: ", ru: "Намерение: ") + intent)
        }

        if let first = analysis.nextSteps.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(l10n.t("Next: ", ru: "Дальше: ") + first)
        }
        if let first = analysis.recommendations.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(l10n.t("Advice: ", ru: "Совет: ") + first)
        }
        return parts.joined(separator: " ")
    }
}

struct StyleBadgeMini: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DetailedAnalysisView: View {
    let analysis: Analysis
    let transcript: String?
    let onSeek: ((TimeInterval) -> Void)?
    @EnvironmentObject private var l10n: LocalizationService
    @State private var isCriteriaExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {

            // 100 words summary
            if !analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("In 100 words", ru: "В 100 словах"), systemImage: "text.justify")
                        .font(.title3.bold())
                    Text(limitWords(digest100Words(analysis), to: 100))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }

            // Stop words / Top words
            let stop = (analysis.stopWords ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let top = computeTopWords(transcript: transcript, limit: 14)
            if !stop.isEmpty || !top.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Top words", ru: "Топ слова"), systemImage: "text.word.spacing")
                        .font(.title3.bold())

                    if !stop.isEmpty {
                        Text(l10n.t("Stop words", ru: "Стоп-слова"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: stop)
                    } else {
                        WrapChips(items: top)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            
            // Manager Guidance
            if let guidance = analysis.managerGuidance {
                ManagerGuidanceSection(guidance: guidance)
                Divider()
            }
            
            // Triggers
            if let triggers = analysis.triggers, !triggers.isEmpty {
                TriggersSection(triggers: triggers, onSeek: onSeek)
                Divider()
            }

            // Communication Style
            if let style = analysis.communicationStyle {
                CommunicationStyleSection(style: style)
                Divider()
            }
            
            // Speaker Insights
            if !analysis.speakerInsights.isEmpty {
                SpeakerInsightsSection(insights: analysis.speakerInsights)
                Divider()
            }
            
            // Client Insights
            if let clientInsights = analysis.clientInsights {
                ClientInsightsSection(insights: clientInsights)
                Divider()
            }

            // Criteria Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(l10n.t("Evaluation criteria", ru: "Критерии оценки"), systemImage: "checklist")
                        .font(.title3.bold())
                    Spacer()
                }
                
                // Show top 3 criteria always
                let topCriteria = Array(analysis.criteria.prefix(3))
                let remainingCriteria = Array(analysis.criteria.dropFirst(3))
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(Array(topCriteria.enumerated()), id: \.element.id) { _, criterion in
                        CriterionCard(criterion: criterion, isFeatured: true)
                    }
                }
                
                if !remainingCriteria.isEmpty {
                    DisclosureGroup(
                        isExpanded: $isCriteriaExpanded,
                        content: {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                                ForEach(remainingCriteria) { criterion in
                                    CriterionCard(criterion: criterion, isFeatured: false)
                                }
                            }
                            .padding(.top, 16)
                        },
                        label: {
                            Text(isCriteriaExpanded ? l10n.t("Hide details", ru: "Скрыть детали") : l10n.t("Show all criteria", ru: "Показать все критерии"))
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                    )
                }
            }
            
            // Recommendations & Objections Grid
            HStack(alignment: .top, spacing: 20) {
                // Recommendations
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Recommendations", ru: "Рекомендации"), systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ForEach(analysis.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                                .padding(.top, 6)
                            Text(rec)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
                
                // Objections
                if !analysis.objections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(l10n.t("Objections", ru: "Возражения"), systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ForEach(analysis.objections, id: \.self) { obj in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red)
                                    .padding(.top, 6)
                                Text(obj)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(16)
                }
            }

            // Key Moments
            if !analysis.keyMoments.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Label(l10n.t("Key moments", ru: "Ключевые моменты"), systemImage: "bookmark.fill")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                    
                    ForEach(Array(analysis.keyMoments.enumerated()), id: \.offset) { _, m in
                        HStack(alignment: .top, spacing: 16) {
                            if let th = m.timeHint, !th.isEmpty {
                                Button {
                                    if let seconds = TimelinePointBuilder.parseTimeHintSeconds(th) {
                                        onSeek?(seconds)
                                    }
                                } label: {
                                    Text(th)
                                        .font(.caption.monospacedDigit())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .help(l10n.t("Go to this moment", ru: "Перейти к этому моменту"))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    if let t = m.type, !t.isEmpty {
                                        Text(t.uppercased())
                                            .font(.caption.bold())
                                            .foregroundColor(.blue)
                                    }
                                    if let s = m.speaker, !s.isEmpty {
                                        Text("• \(s)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(m.text)
                                    .font(.body)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func limitWords(_ text: String, to maxWords: Int) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        guard words.count > maxWords else { return cleaned }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .orange }
        return .red
    }

    private func digest100Words(_ analysis: Analysis) -> String {
        var parts: [String] = []
        let summary = analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { parts.append(summary) }

        let intent = analysis.customerIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intent.isEmpty {
            parts.append(l10n.t("Intent: ", ru: "Намерение: ") + intent)
        }
        if let first = analysis.nextSteps.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(l10n.t("Next: ", ru: "Дальше: ") + first)
        }
        if let first = analysis.recommendations.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(l10n.t("Advice: ", ru: "Совет: ") + first)
        }
        return parts.joined(separator: " ")
    }

    private func computeTopWords(transcript: String?, limit: Int) -> [String] {
        guard let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let stopEn: Set<String> = [
            "the","and","a","an","to","of","in","on","for","with","is","are","was","were","be","been","it","this","that","we","you","i","they","he","she","as","at","by","from","or","not","but","so","if","then","there","here","can","could","should","would","will","just","about"
        ]
        let stopRu: Set<String> = [
            "и","а","но","или","да","нет","что","это","как","так","то","же","ли","в","на","по","к","ко","из","за","у","о","об","от","до","для","при","про","мы","вы","я","они","он","она","оно","это","эти","тот","та","те","тут","там","уже","ещё","еще","бы","не","ну","вот","если","тогда","когда","где","что","чтобы","потому","почему"
        ]

        let lowered = transcript.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }
        let tokens = String(cleaned)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        var freq: [String: Int] = [:]
        for w in tokens {
            if w.count <= 2 { continue }
            if stopEn.contains(w) || stopRu.contains(w) { continue }
            freq[w, default: 0] += 1
        }

        return freq
            .sorted { a, b in a.value == b.value ? a.key < b.key : a.value > b.value }
            .prefix(limit)
            .map { "\($0.key) (\($0.value))" }
    }
}

private struct CriterionCard: View {
    let criterion: EvaluationCriterion
    let isFeatured: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(scoreColor(criterion.score).opacity(0.1))
                    .frame(width: 44, height: 44)
                Text("\(criterion.score)")
                    .font(.title3.bold())
                    .foregroundColor(scoreColor(criterion.score))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.name)
                    .font(.headline)
                Text(criterion.comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFeatured ? scoreColor(criterion.score).opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .orange }
        return .red
    }
}

struct RemindersView: View {
    let analysis: Analysis
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Commitments
            if !analysis.commitments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Commitments", ru: "Обещали/договорились"), systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(Array(analysis.commitments.enumerated()), id: \.offset) { _, c in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(c.title)
                                    .font(.headline)
                                
                                HStack {
                                    if let owner = c.owner, !owner.isEmpty {
                                        Label(owner, systemImage: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let due = c.dueDateISO, !due.isEmpty {
                                        Label(due, systemImage: "calendar")
                                            .font(.caption)
                                            .foregroundColor(.orange)
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
            }
            
            // Action Items
            if !analysis.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Action items", ru: "Задачи"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(Array(analysis.actionItems.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.headline)
                                
                                HStack {
                                    if let owner = item.owner, !owner.isEmpty {
                                        Label(owner, systemImage: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let pr = item.priority, !pr.isEmpty {
                                        Text(pr.uppercased())
                                            .font(.caption.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                if let notes = item.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Extracted Entities
            if let entities = analysis.extractedEntities, entities.hasAnyData {
                VStack(alignment: .leading, spacing: 12) {
                    Label(l10n.t("Extracted Data", ru: "Извлеченные данные"), systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                        if let companies = entities.companies, !companies.isEmpty {
                            BulletListCard(title: l10n.t("Companies", ru: "Компании"), items: companies)
                        }
                        if let people = entities.people, !people.isEmpty {
                            BulletListCard(title: l10n.t("People", ru: "Люди"), items: people)
                        }
                        if let products = entities.products, !products.isEmpty {
                            BulletListCard(title: l10n.t("Products", ru: "Продукты"), items: products)
                        }
                        if let dates = entities.dateMentions, !dates.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n.t("Dates", ru: "Даты"))
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
            }
        }
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

// MARK: - Helper Components

struct ScoreCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
}

struct MetricWidget: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct BulletListCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(items, id: \.self) { it in
                HStack(alignment: .top) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .padding(.top, 6)
                    Text(it)
                        .font(.subheadline)
                }
            }
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

// MARK: - New Analysis Sections

struct ManagerGuidanceSection: View {
    let guidance: ManagerGuidance
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(l10n.t("Manager Guidance", ru: "Советы менеджеру"), systemImage: "person.crop.circle.badge.checkmark")
                .font(.title3.bold())
            
            if let advice = guidance.generalAdvice, !advice.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("General Advice", ru: "Общие советы"), systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    ForEach(advice, id: \.self) { item in
                        HStack(alignment: .top) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(item).font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            if let scenarios = guidance.alternativeScenarios, !scenarios.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("Alternative Scenarios", ru: "Как могло быть иначе"), systemImage: "arrow.triangle.branch")
                        .font(.headline)
                        .foregroundColor(.purple)
                    ForEach(scenarios, id: \.self) { item in
                        HStack(alignment: .top) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text(item).font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            if let examples = guidance.specificExamples, !examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("Specific Examples", ru: "Примеры фраз"), systemImage: "quote.bubble.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    ForEach(examples, id: \.self) { item in
                        HStack(alignment: .top) {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(item).font(.subheadline).italic()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                if let persuasion = guidance.persuasionTechniques, !persuasion.isEmpty {
                    GuidanceCard(title: l10n.t("Persuasion", ru: "Убеждение"), icon: "bubble.left.and.exclamationmark.bubble.right.fill", color: .blue, items: persuasion)
                }
                if let engagement = guidance.engagementTips, !engagement.isEmpty {
                    GuidanceCard(title: l10n.t("Engagement", ru: "Вовлечение"), icon: "person.2.wave.2.fill", color: .green, items: engagement)
                }
                if let conflict = guidance.conflictAvoidance, !conflict.isEmpty {
                    GuidanceCard(title: l10n.t("Conflict Avoidance", ru: "Избегание конфликтов"), icon: "shield.fill", color: .red, items: conflict)
                }
                if let emotion = guidance.emotionHandling, !emotion.isEmpty {
                    GuidanceCard(title: l10n.t("Emotion Handling", ru: "Работа с эмоциями"), icon: "heart.fill", color: .purple, items: emotion)
                }
            }
        }
    }
}

struct TriggersSection: View {
    let triggers: [ConversationTrigger]
    let onSeek: ((TimeInterval) -> Void)?
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(l10n.t("Triggers & Signals", ru: "Триггеры и сигналы"), systemImage: "exclamationmark.bubble.fill")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                ForEach(triggers, id: \.self) { trigger in
                    TriggerCard(trigger: trigger, onSeek: onSeek)
                }
            }
        }
    }
}

struct TriggerCard: View {
    let trigger: ConversationTrigger
    let onSeek: ((TimeInterval) -> Void)?
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForType(trigger.type))
                .font(.title2)
                .foregroundColor(colorForType(trigger.type))
                .frame(width: 32, height: 32)
                .background(colorForType(trigger.type).opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trigger.type.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(trigger.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let context = trigger.context {
                    Text(context)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let time = trigger.timeHint {
                    Button {
                        if let seconds = TimelinePointBuilder.parseTimeHintSeconds(time) {
                            onSeek?(seconds)
                        }
                    } label: {
                        Text(time)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("Go to this moment", ru: "Перейти к этому моменту"))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    func iconForType(_ type: String) -> String {
        switch type {
        case "profanity": return "exclamationmark.octagon.fill"
        case "sarcasm": return "face.dashed.fill"
        case "stop_word": return "hand.raised.fill"
        case "buying_signal": return "dollarsign.circle.fill"
        default: return "exclamationmark.circle"
        }
    }
    
    func colorForType(_ type: String) -> Color {
        switch type {
        case "profanity": return .red
        case "sarcasm": return .orange
        case "stop_word": return .gray
        case "buying_signal": return .green
        default: return .blue
        }
    }
}

struct GuidanceCard: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .padding(.top, 6)
                        .foregroundColor(color.opacity(0.7))
                    Text(item).font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct CommunicationStyleSection: View {
    let style: CommunicationStyle
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(l10n.t("Communication Style", ru: "Стиль общения"), systemImage: "bubble.left.and.bubble.right.fill")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                if let formality = style.formality {
                    StyleBadge(title: l10n.t("Formality", ru: "Формальность"), value: formality)
                }
                if let pacing = style.pacing {
                    StyleBadge(title: l10n.t("Pacing", ru: "Темп"), value: pacing)
                }
                if let structure = style.structure {
                    StyleBadge(title: l10n.t("Structure", ru: "Структура"), value: structure)
                }
                if let tone = style.tone, !tone.isEmpty {
                    StyleBadge(title: l10n.t("Tone", ru: "Тон"), value: tone.joined(separator: ", "))
                }
                if let conflict = style.conflictLevel {
                    StyleBadge(title: l10n.t("Conflict", ru: "Конфликтность"), value: "\(conflict)/100")
                }
            }
        }
    }
}

struct StyleBadge: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.capitalized)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SpeakerInsightsSection: View {
    let insights: [SpeakerInsight]
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(l10n.t("Speaker Insights", ru: "Анализ спикеров"), systemImage: "person.3.fill")
                .font(.title3.bold())
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(insights) { insight in
                        SpeakerCard(insight: insight)
                    }
                }
            }
        }
    }
}

struct SpeakerCard: View {
    let insight: SpeakerInsight
    @EnvironmentObject private var l10n: LocalizationService
    @State private var showIdeas = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(insight.name)
                    .font(.headline)
                Spacer()
                if let role = insight.role {
                    Text(role)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Divider()
            
            // Radar Chart Placeholder (using Bars for now for stability)
            VStack(spacing: 8) {
                StatBar(label: l10n.t("Activity", ru: "Активность"), value: insight.activityScore ?? 0)
                StatBar(label: l10n.t("Competence", ru: "Компетентность"), value: insight.competenceScore ?? 0)
                StatBar(label: l10n.t("Emotion Control", ru: "Эмоции"), value: insight.emotionControlScore ?? 0)
                StatBar(label: l10n.t("Conflict Handling", ru: "Конфликты"), value: insight.conflictHandlingScore ?? 0)
            }
            
            if let strengths = insight.strengths, !strengths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("Strengths", ru: "Сильные стороны"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(strengths.prefix(3), id: \.self) { s in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(s).font(.caption)
                        }
                    }
                }
            }
            
            if let risks = insight.risks, !risks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("Risks", ru: "Риски"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(risks.prefix(2), id: \.self) { r in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text(r).font(.caption)
                        }
                    }
                }
            }
            
            if let ideas = insight.ideasAndProposals, !ideas.isEmpty {
                Button(action: { showIdeas.toggle() }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("Ideas", ru: "Идеи"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("\(ideas.count) " + l10n.t("proposals", ru: "предложений"))
                                .font(.caption)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showIdeas) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.t("Ideas & Proposals", ru: "Идеи и предложения"))
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        ForEach(ideas, id: \.self) { idea in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(idea)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .frame(width: 300)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
}

struct StatBar: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(value)")
                    .font(.caption2)
                    .bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}

struct ClientInsightsSection: View {
    let insights: ClientInsights
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(l10n.t("Client Profile", ru: "Профиль клиента"), systemImage: "briefcase.fill")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                if let goals = insights.goals, !goals.isEmpty {
                    BulletListCard(title: l10n.t("Goals", ru: "Цели"), items: goals)
                }
                if let pains = insights.painPoints, !pains.isEmpty {
                    BulletListCard(title: l10n.t("Pain Points", ru: "Боли"), items: pains)
                }
                if let budget = insights.budget {
                    SimpleCard(title: l10n.t("Budget", ru: "Бюджет"), value: budget)
                }
                if let timeline = insights.timeline {
                    SimpleCard(title: l10n.t("Timeline", ru: "Сроки"), value: timeline)
                }
                if let dm = insights.decisionMakers, !dm.isEmpty {
                    BulletListCard(title: l10n.t("Decision Makers", ru: "ЛПР"), items: dm)
                }
            }
        }
    }
}

struct SimpleCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

