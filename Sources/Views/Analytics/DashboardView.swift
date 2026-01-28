import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    
    var sessions: [Session] {
        viewModel.sessions.sorted(by: { $0.date < $1.date })
    }
    
    var analyzedSessions: [Session] {
        sessions.filter { $0.analysis != nil }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(l10n.t("Analytics Dashboard", ru: "Аналитическая панель"))
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(l10n.t("No sessions recorded yet", ru: "Пока нет записанных сессий"))
                            .font(.title3)
                        Text(l10n.t("Start recording to see analytics", ru: "Начните запись, чтобы увидеть аналитику"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if analyzedSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(l10n.t("Not enough data for analysis", ru: "Недостаточно данных для анализа"))
                            .font(.title3)
                        Text(l10n.t("Process your sessions with AI to see insights", ru: "Обработайте сессии с помощью AI для получения аналитики"))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // KPI Cards
                    HStack(spacing: 16) {
                        KPICard(title: l10n.t("Total Sessions", ru: "Всего сессий"), value: "\(sessions.count)", icon: "mic.fill", color: .blue)
                        KPICard(title: l10n.t("Avg Score", ru: "Средний балл"), value: String(format: "%.0f", avgScore), icon: "star.fill", color: .orange)
                        KPICard(title: l10n.t("Avg Engagement", ru: "Вовлеченность"), value: String(format: "%.0f%%", avgEngagement), icon: "person.2.wave.2.fill", color: .green)
                        KPICard(title: l10n.t("Sales Prob.", ru: "Вер. сделки"), value: String(format: "%.0f%%", avgSalesProb), icon: "chart.line.uptrend.xyaxis", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Charts Row 1
                    HStack(spacing: 16) {
                        // Score Trend
                        VStack(alignment: .leading) {
                            Text(l10n.t("Score Trend", ru: "Динамика качества"))
                                .font(.headline)
                            Chart {
                                ForEach(analyzedSessions) { session in
                                    LineMark(
                                        x: .value("Date", session.date),
                                        y: .value("Score", session.analysis?.score ?? 0)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.orange)
                                    
                                    PointMark(
                                        x: .value("Date", session.date),
                                        y: .value("Score", session.analysis?.score ?? 0)
                                    )
                                    .foregroundStyle(Color.orange)
                                }
                            }
                            .frame(height: 200)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        
                        // Sentiment Distribution
                        VStack(alignment: .leading) {
                            Text(l10n.t("Sentiment", ru: "Настроение"))
                                .font(.headline)
                            Chart(sentimentData, id: \.key) { item in
                                SectorMark(
                                    angle: .value("Count", item.value),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Type", item.key))
                            }
                            .frame(height: 200)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Charts Row 2
                    HStack(spacing: 16) {
                        // Top Objections
                        VStack(alignment: .leading) {
                            Text(l10n.t("Top Objections", ru: "Топ возражений"))
                                .font(.headline)
                            
                            if topObjections.isEmpty {
                                Text("No objections detected")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Chart(topObjections, id: \.key) { item in
                                    BarMark(
                                        x: .value("Count", item.value),
                                        y: .value("Objection", item.key)
                                    )
                                    .foregroundStyle(Color.red.opacity(0.8))
                                }
                                .frame(height: 250)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // Computed Stats
    
    var avgScore: Double {
        let scores = analyzedSessions.compactMap { $0.analysis?.score }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    var avgEngagement: Double {
        let scores = analyzedSessions.compactMap { $0.analysis?.engagementScore }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    var avgSalesProb: Double {
        let scores = analyzedSessions.compactMap { $0.analysis?.salesProbability }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    var sentimentData: [(key: String, value: Int)] {
        var counts: [String: Int] = ["Positive": 0, "Neutral": 0, "Negative": 0]
        for session in analyzedSessions {
            if let s = session.analysis?.sentiment {
                counts[s, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.value > $1.value }
    }
    
    var topObjections: [(key: String, value: Int)] {
        var counts: [String: Int] = [:]
        for session in analyzedSessions {
            if let objections = session.analysis?.objections {
                for obj in objections {
                    // Simple normalization: lowercase and take first 20 chars to group similar ones roughly
                    // In a real app, we'd use AI to cluster these.
                    let key = obj.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                    counts[key, default: 0] += 1
                }
            }
        }
        return counts.map { (key: $0.key, value: $0.value) }
            .sorted(by: { $0.value > $1.value })
            .prefix(8)
            .map { $0 }
    }
}

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
