import SwiftUI

/// Окно для режима помощника интервью с реал-тайм транскрибацией и подсказками
struct InterviewAssistantView: View {
    @ObservedObject var assistant = InterviewAssistantService.shared
    @State private var isStarting = false
    @State private var error: String?
    @State private var showError = false
    @State private var floatingWindow: FloatingTranscriptWindowController?
    @State private var showFloatingWindow = true
    @State private var saveSessionAfterStop = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Interview Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                if assistant.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            if !assistant.isActive {
                // Экран приветствия
                welcomeScreen
            } else {
                // Активный режим
                activeScreen
            }
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            if let error = error {
                Text(error)
            }
        }
    }
    
    // MARK: - Welcome Screen
    
    private var welcomeScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Помощник для интервью на английском")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Получайте реал-тайм транскрибацию, перевод и подсказки для ответов")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "waveform",
                        title: "Транскрибация в реальном времени",
                        description: "Автоматическое распознавание речи интервьюера на английском"
                    )
                    
                    FeatureRow(
                        icon: "character.bubble",
                        title: "Перевод на русский",
                        description: "Мгновенный перевод каждой реплики"
                    )
                    
                    FeatureRow(
                        icon: "lightbulb",
                        title: "Подсказки для ответов",
                        description: "ИИ предлагает варианты ответов после вопросов"
                    )
                    
                    FeatureRow(
                        icon: "person.2",
                        title: "Определение говорящих",
                        description: "Различает речь интервьюера и вашу"
                    )
                    
                    FeatureRow(
                        icon: "macwindow.on.rectangle",
                        title: "Плавающее окно",
                        description: "Всегда поверх других окон"
                    )
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Показать плавающее окно", isOn: $showFloatingWindow)
                    Toggle("Сохранить сессию после завершения", isOn: $saveSessionAfterStop)
                }
                
                Button(action: startAssistant) {
                    HStack {
                        if isStarting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "mic.fill")
                        }
                        Text(isStarting ? "Запуск..." : "Начать собеседование")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isStarting)
            }
            .padding(32)
            .frame(maxWidth: 600)
        }
    }
    
    // MARK: - Active Screen
    
    private var activeScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Транскрипт интервьюера (последний)
                    if let lastInterviewer = assistant.dialogueHistory.last(where: { $0.speaker == .interviewer }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Интервьюер", systemImage: "person.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(lastInterviewer.englishText)
                                .font(.title3)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            
                            Text(lastInterviewer.russianTranslation)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Ваша речь (последняя)
                    if let lastUser = assistant.dialogueHistory.last(where: { $0.speaker == .user }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Вы", systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(lastUser.englishText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Подсказка
                    if !assistant.suggestedResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Подсказка", systemImage: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(assistant.suggestedResponse)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                                )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            
            Divider()
            
            // Статистика
            HStack(spacing: 20) {
                StatItem(icon: "bubble.left.and.bubble.right", value: "\(assistant.dialogueHistory.count)", label: "реплик")
                StatItem(icon: "timer", value: formatDuration(Date().timeIntervalSince(assistant.dialogueHistory.first?.timestamp ?? Date())), label: "времени")
            }
            .padding(.vertical, 12)
            
            // Кнопка остановки
            Button(action: stopAssistant) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Остановить")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
            .padding(.bottom)
        }
    }
    
    // MARK: - Actions
    
    private func startAssistant() {
        Task {
            isStarting = true
            
            do {
                try await assistant.start()
                await MainActor.run {
                    isStarting = false
                    if showFloatingWindow {
                        openFloatingWindow()
                    }
                }
            } catch {
                await MainActor.run {
                    isStarting = false
                    self.error = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func stopAssistant() {
        Task {
            if let result = await assistant.stop() {
                await MainActor.run {
                    closeFloatingWindow()
                    
                    if saveSessionAfterStop {
                        saveInterviewSession(result)
                    }
                }
            }
        }
    }
    
    private func openFloatingWindow() {
        closeFloatingWindow()
        
        let controller = FloatingTranscriptWindowController()
        controller.showWindow(self as Any?)
        floatingWindow = controller
    }
    
    private func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
    }
    
    private func saveInterviewSession(_ result: (filename: String, duration: TimeInterval, transcript: String)) {
        var newSession = Session(
            id: UUID(),
            date: Date(),
            duration: result.duration,
            audioFilename: result.filename
        )
        newSession.transcript = result.transcript
        newSession.customTitle = "Интервью на английском"
        newSession.source = .recording
        
        PersistenceService.shared.saveSession(newSession)
        print("✅ Interview session saved: \(newSession.id)")
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
