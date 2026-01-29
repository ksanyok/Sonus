import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    var onSelect: ((Session) -> Void)? = nil
    @State private var selectedCategory: SessionCategory? = nil // nil means "All"
    @State private var editingSession: Session?
    
    var filteredSessions: [Session] {
        if let category = selectedCategory {
            return viewModel.sessions.filter { $0.category == category }
        } else {
            return viewModel.sessions
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SonusTopBar()
                .background(Color(nsColor: .controlBackgroundColor))

            // Categories Header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(title: l10n.t("All", ru: "Все"), icon: "tray.full.fill", isSelected: selectedCategory == nil) {
                        print("[History] Filter -> All")
                        withAnimation { selectedCategory = nil }
                    }
                    
                    ForEach(SessionCategory.allCases) { category in
                        CategoryPill(title: l10n.t(category.displayNameEn, ru: category.displayNameRu), icon: category.icon, isSelected: selectedCategory == category) {
                            print("[History] Filter -> \(category.rawValue)")
                            withAnimation { selectedCategory = category }
                        }
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Sessions List
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredSessions) { session in
                        SessionCard(
                            session: session,
                            processingStatus: viewModel.processingStatus[session.id],
                            processingProgress: viewModel.processingProgress[session.id],
                            onAnalyze: { viewModel.processSession(session) },
                            onDelete: { viewModel.deleteSession(session) },
                            onEdit: { editingSession = session }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedSession = session
                            onSelect?(session)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(l10n.t("History", ru: "История"))
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingSession, onDismiss: { editingSession = nil }) { session in
            SessionEditSheet(session: session, viewModel: viewModel)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SessionCard: View {
    let session: Session
    let processingStatus: String?
    let processingProgress: Double?
    let onAnalyze: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject private var l10n: LocalizationService
    @State private var isHovering = false

    private var audioSizeString: String? {
        PersistenceService.shared.audioFileSizeString(for: session.audioFilename)
    }

    private var needsUpdate: Bool {
        guard session.analysis != nil else { return false }
        return (session.analysisSchemaVersion ?? 0) < OpenAIClient.analysisSchemaVersion
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon/Category
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: session.category.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 10) {
                    Label(l10n.t(session.resolvedSource.labelEn, ru: session.resolvedSource.labelRu), systemImage: session.resolvedSource.icon)
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Label(formatDuration(session.duration), systemImage: "clock")
                    if let size = audioSizeString {
                        Label(size, systemImage: "internaldrive")
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                if let analysis = session.analysis {
                    VStack(alignment: .trailing) {
                        Text("\(analysis.score)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(analysis.score))
                        
                        Text(analysis.sentiment)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor(analysis.score).opacity(0.1))
                    .cornerRadius(8)
                } else {
                    if session.isProcessing {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(processingStatus ?? l10n.t("Processing…", ru: "Обработка…"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let p = processingProgress {
                                ProgressView(value: p)
                                    .frame(width: 120)
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(10)
                    } else {
                        Text(l10n.t("Not analyzed", ru: "Не проанализировано"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Button {
                            onAnalyze()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: needsUpdate ? "sparkles" : "wand.and.stars")
                                Text(l10n.t("Analyze", ru: "Анализ"))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(needsUpdate ? .orange : .accentColor)
                        .controlSize(.small)
                        .disabled(session.isProcessing)

                        if let d = session.analysisUpdatedAt {
                            Text(lastAnalyzedString(d))
                                .font(.caption2)
                                .foregroundColor(needsUpdate ? .orange : .secondary)
                        } else {
                            Text(l10n.t("Not analyzed", ru: "Не проанализировано"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(l10n.t("Edit", ru: "Правка")) { onEdit() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button(role: .destructive) { onDelete() } label: { Text(l10n.t("Delete", ru: "Удалить")) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0.05), radius: isHovering ? 8 : 4, x: 0, y: 2)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hover in
            isHovering = hover
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<50: return .red
        case 50..<75: return .orange
        default: return .green
        }
    }

    private func lastAnalyzedString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = l10n.locale
        df.dateStyle = .short
        df.timeStyle = .short
        return l10n.t("Last: ", ru: "Последний: ") + df.string(from: date)
    }
}

struct SessionEditSheet: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var category: SessionCategory = .personal
    @State private var showSaveSuccess = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(l10n.t("Edit session", ru: "Редактировать запись"))
                    .font(.title2)
                    .bold()
                TextField(l10n.t("Title", ru: "Название"), text: $title)
                    .textFieldStyle(.roundedBorder)
                Picker(l10n.t("Category", ru: "Категория"), selection: $category) {
                    ForEach(SessionCategory.allCases) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                            Text(l10n.t(cat.displayNameEn, ru: cat.displayNameRu))
                        }.tag(cat)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer().frame(height: 40)
                
                HStack {
                    Spacer()
                    Button(l10n.t("Cancel", ru: "Отмена")) { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 360)
            
            // Floating Save Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: save) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(l10n.t("Save", ru: "Сохранить"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(showSaveSuccess ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSaveSuccess)
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
            }
            
            // Toast Notification
            if showSaveSuccess {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text(l10n.t("Saved successfully!", ru: "Успешно сохранено!"))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                    )
                    .padding(.top, 20)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            title = session.customTitle ?? session.title
            category = session.category
        }
    }
    
    private func save() {
        var updated = session
        updated.customTitle = title.isEmpty ? nil : title
        updated.category = category
        viewModel.saveSession(updated)
        if viewModel.selectedSession?.id == updated.id {
            viewModel.selectedSession = updated
        }
        
        // Show success toast
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSaveSuccess = true
        }
        
        // Auto dismiss after showing toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showSaveSuccess = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
            }
        }
    }
}
