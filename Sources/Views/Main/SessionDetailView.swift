import SwiftUI
import AppKit

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.largeTitle).bold()
                    HStack(spacing: 8) {
                        Label(session.category.displayName, systemImage: session.category.icon)
                        Text("•")
                        Text(session.date.formatted(date: .long, time: .shortened))
                        Text("•")
                        Text(formatDuration(session.duration))
                    }
                    .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Analyze") { viewModel.processSession(session) }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.isProcessing)
                        Button("Delete", role: .destructive) { viewModel.deleteSession(session) }
                            .buttonStyle(.bordered)
                    }
                    if session.isProcessing {
                        ProgressView("Processing...")
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Audio Player card
            HStack(spacing: 16) {
                Button(action: {
                    let url = PersistenceService.shared.getAudioURL(for: session.audioFilename)
                    audioPlayer.togglePlayback(audioURL: url)
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 6) {
                    Slider(value: playbackProgress)
                    HStack {
                        Text(formatDuration(audioPlayer.currentTime)).foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(displayDuration)).foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(14)
            .padding(.horizontal)
            
            // Content
            if let analysis = session.analysis {
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Analysis").tag(1)
                    Text("Transcript").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            OverviewView(analysis: analysis)
                        } else if selectedTab == 1 {
                            DetailedAnalysisView(analysis: analysis)
                        } else {
                            TranscriptView(transcript: session.transcript)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("No analysis available")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var displayDuration: TimeInterval {
        let effectiveDuration = audioPlayer.duration > 0 ? audioPlayer.duration : session.duration
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

struct OverviewView: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Card
            VStack(alignment: .leading, spacing: 10) {
                Label("Summary", systemImage: "text.alignleft")
                    .font(.headline)
                Text(analysis.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            // Key Metrics
            HStack(spacing: 20) {
                MetricCard(title: "Score", value: "\(analysis.score)%", icon: "chart.bar.fill", color: .blue)
                MetricCard(title: "Sentiment", value: analysis.sentiment, icon: "face.smiling", color: .green)
                MetricCard(title: "Engagement", value: "\(analysis.engagementScore)%", icon: "person.2.wave.2.fill", color: .orange)
                MetricCard(title: "Sales Prob.", value: "\(analysis.salesProbability)%", icon: "cart.badge.plus", color: .pink)
            }
            
            // Speakers / Languages
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Speakers", systemImage: "person.3.fill")
                    Spacer()
                    Text("\(analysis.speakerCount ?? analysis.participants.count) participant(s)")
                        .foregroundColor(.secondary)
                }
                WrapChips(items: analysis.participants)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("Languages", systemImage: "globe")
                WrapChips(items: analysis.languages)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            if let stop = analysis.stopWords, !stop.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Stop words / fillers", systemImage: "ellipsis.message")
                    WrapChips(items: stop)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Intent
            VStack(alignment: .leading, spacing: 10) {
                Label("Customer Intent", systemImage: "cart.fill")
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
                    Label("Next Steps", systemImage: "arrow.turn.up.right")
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
                    Label("Стиль общения", systemImage: "quote.bubble")
                        .font(.headline)

                    if let formality = style.formality, !formality.isEmpty {
                        HStack {
                            Text("Формат")
                            Spacer()
                            Text(formality)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let pacing = style.pacing, !pacing.isEmpty {
                        HStack {
                            Text("Темп")
                            Spacer()
                            Text(pacing)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let structure = style.structure, !structure.isEmpty {
                        HStack {
                            Text("Структура")
                            Spacer()
                            Text(structure)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let conflict = style.conflictLevel {
                        HStack {
                            Text("Конфликтность")
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
                ParticipantProfileCard(title: "Клиент", profile: client)
            }

            if let others = analysis.otherParticipants, !others.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Другие собеседники", systemImage: "person.3")
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
                    Label("Анализ клиента", systemImage: "person.text.rectangle")
                        .font(.headline)

                    if let s = insights.summary, !s.isEmpty {
                        Text(s)
                            .foregroundColor(.secondary)
                    }

                    if let goals = insights.goals, !goals.isEmpty {
                        BulletListCard(title: "Цели", items: goals)
                    }
                    if let pains = insights.painPoints, !pains.isEmpty {
                        BulletListCard(title: "Боли/проблемы", items: pains)
                    }
                    if let pr = insights.priorities, !pr.isEmpty {
                        BulletListCard(title: "Приоритеты", items: pr)
                    }
                    if let budget = insights.budget, !budget.isEmpty {
                        HStack {
                            Text("Бюджет")
                            Spacer()
                            Text(budget).foregroundColor(.secondary)
                        }
                    }
                    if let timeline = insights.timeline, !timeline.isEmpty {
                        HStack {
                            Text("Сроки")
                            Spacer()
                            Text(timeline).foregroundColor(.secondary)
                        }
                    }
                    if let dm = insights.decisionMakers, !dm.isEmpty {
                        BulletListCard(title: "ЛПР/участники решения", items: dm)
                    }
                    if let dp = insights.decisionProcess, !dp.isEmpty {
                        HStack(alignment: .top) {
                            Text("Процесс решения")
                            Spacer()
                            Text(dp)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if let sig = insights.buyingSignals, !sig.isEmpty {
                        BulletListCard(title: "Сигналы интереса", items: sig)
                    }
                    if let risks = insights.risks, !risks.isEmpty {
                        BulletListCard(title: "Риски", items: risks)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            if let entities = analysis.extractedEntities, entities.hasAnyData {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Извлечённые данные", systemImage: "tray.full")
                        .font(.headline)

                    if let companies = entities.companies, !companies.isEmpty {
                        Text("Компании")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: companies)
                    }
                    if let people = entities.people, !people.isEmpty {
                        Text("Люди")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: people)
                    }
                    if let products = entities.products, !products.isEmpty {
                        Text("Продукты")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: products)
                    }
                    if let urls = entities.urls, !urls.isEmpty {
                        Text("Ссылки")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: urls)
                    }
                    if let emails = entities.emails, !emails.isEmpty {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: emails)
                    }
                    if let phones = entities.phones, !phones.isEmpty {
                        Text("Телефоны")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        WrapChips(items: phones)
                    }
                    if let dates = entities.dateMentions, !dates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Даты/дедлайны")
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
        }
    }
}

struct DetailedAnalysisView: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Criteria
            VStack(alignment: .leading, spacing: 10) {
                Label("Evaluation Criteria", systemImage: "checklist")
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
                Label("Recommendations", systemImage: "lightbulb.fill")
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
                    Label("Objections", systemImage: "exclamationmark.bubble")
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
                    Label("Ключевые моменты", systemImage: "bookmark")
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
                    Label("Задачи и дедлайны", systemImage: "checkmark.circle")
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
    
    var body: some View {
        VStack(alignment: .leading) {
            if let text = transcript {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            } else {
                Text("No transcript available")
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
