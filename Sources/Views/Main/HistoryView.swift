import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    var onSelect: ((Session) -> Void)? = nil
    @State private var selectedCategory: SessionCategory? = nil // nil means "All"
    @State private var showEditSheet: Bool = false
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
            // Categories Header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(title: "Все", icon: "tray.full.fill", isSelected: selectedCategory == nil) {
                        withAnimation { selectedCategory = nil }
                    }
                    
                    ForEach(SessionCategory.allCases) { category in
                        CategoryPill(title: category.displayName, icon: category.icon, isSelected: selectedCategory == category) {
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
                        NavigationLink(value: session) {
                            SessionCard(session: session,
                                        processingStatus: viewModel.processingStatus[session.id],
                                        processingProgress: viewModel.processingProgress[session.id],
                                        onAnalyze: {
                                viewModel.processSession(session)
                            }, onDelete: {
                                viewModel.deleteSession(session)
                            }, onEdit: {
                                editingSession = session
                                showEditSheet = true
                            })
                            .contentShape(Rectangle())
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.selectedSession = session
                            onSelect?(session)
                        })
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("История")
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showEditSheet, onDismiss: { editingSession = nil }) {
            if let session = editingSession {
                SessionEditSheet(session: session, viewModel: viewModel, isPresented: $showEditSheet)
            }
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
    @State private var isHovering = false
    
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
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    Text("•")
                    Text(formatDuration(session.duration))
                }
                .font(.caption)
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
                            Text(processingStatus ?? "Обработка…")
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
                        Text("Not analyzed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                HStack(spacing: 8) {
                    Button("Analyze") { onAnalyze() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Edit") { onEdit() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button(role: .destructive) { onDelete() } label: { Text("Delete") }
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
}

struct SessionEditSheet: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var title: String = ""
    @State private var category: SessionCategory = .personal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Редактировать запись")
                .font(.title2)
                .bold()
            TextField("Название", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Категория", selection: $category) {
                ForEach(SessionCategory.allCases) { cat in
                    HStack {
                        Image(systemName: cat.icon)
                        Text(cat.displayName)
                    }.tag(cat)
                }
            }
            .pickerStyle(.menu)
            HStack {
                Spacer()
                Button("Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                Button("Отмена") { isPresented = false }
            }
        }
        .padding()
        .frame(width: 360)
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
        isPresented = false
    }
}
