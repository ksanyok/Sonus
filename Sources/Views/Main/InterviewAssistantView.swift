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
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(error ?? "Unknown error")
        }
    }
    
    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Помощник для англоязычного интервью")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "ear.fill",
                    title: "Слушает собеседника",
                    description: "Реал-тайм транскрибация речи на английском"
                )
                
                FeatureRow(
                    icon: "text.bubble.fill",
                    title: "Переводит на русский",
                    description: "Мгновенный перевод для понимания вопросов"
                )
                
                FeatureRow(
                    icon: "lightbulb.fill",
                    title: "Подсказывает ответы",
                    description: "Автоматические подсказки после пауз"
                )
                
                FeatureRow(
                    icon: "rectangle.on.rectangle",
                    title: "Плавающее окно",
                    description: "Транскрипция поверх других приложений"
                )
                
                FeatureRow(
                    icon: "doc.text.fill",
                    title: "Полная запись",
                    description: "Сохранение диалога для анализа"
                )
            }
            .padding(.horizontal, 40)
            
            Toggle("Показывать плавающее окно", isOn: $showFloatingWindow)
                .padding(.horizontal, 40)
            
            Toggle("Сохранить запись после завершения", isOn: $saveSessionAfterStop)
                .padding(.horizontal, 40)
            
            Button(action: startAssistant) {
                HStack {
                    if isStarting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "play.fill")
               Кнопка для показа/скрытия плавающего окна
            HStack {
                Spacer()
                Button(action: toggleFloatingWindow) {
                    HStack {
                        Image(systemName: floatingWindow == nil ? "rectangle.on.rectangle" : "rectangle.on.rectangle.slash")
                        Text(floatingWindow == nil ? "Show Floating Window" : "Hide Floating Window")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Последний вопрос собеседника
                    Text(isStarting ? "Запуск..." : "Начать интервью")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 12)
            // Последний вопрос собеседника
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text("Последняя реплика собеседника:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ScrollView {
                    Text(assistant.currentEnglishText.isEmpty ? "Ожидание речи..." : assistant.currentEnglishText)
                        .font(.body)
                        .foregroundColor(assistant.currentEnglishText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 80)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Перевод на русский
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.green)
                    Text("Перевод:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ScrollView {
                    Text(assistant.currentRussianTranslation.isEmpty ? "Перевод появится здесь..." : assistant.currentRussianTranslation)
                        .font(.body)
                        .foregroundColor(assistant.currentRussianTranslation.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 80)
                .background(Color.green.opacity(0.05
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ScrollView {
                    Text(assistant.currentRussianTranslation.isEmpty ? "Перевод появится здесь..." : assistant.currentRussianTranslation)
                        .font(.body)
                        .foregroundColor(assistant.currentRussianTranslation.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 100)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Подсказка ответа
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("Рекомендуемый ответ:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    if assistant.confidenceLevel > 0 {
                        HStack(spacing: 4) {
                            Text("Сложность:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(complexityLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(complexityColor)
                        }
                    }
                }
                
                ScrollView {
                    Text(assistant.suggestedResponse.isEmpty ? "Подсказка появится после паузы..." : assistant.suggestedResponse)
                        .font(.body)
                        .fontWeight(assistant.suggestedResponse.isEmpty ? .regular : .medium)
                        .foregroundColor(assistant.suggestedResponse.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }00)
                .background(assistant.suggestedResponse.isEmpty ? Color(nsColor: .textBackgroundColor) : Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(assistant.suggestedResponse.isEmpty ? Color.clear : Color.orange.opacity(0.5), lineWidth: 2)
                )
            }
            .padding(.horizontal)
            
            // Статистика
            HStack(spacing: 20) {
                StatItem(icon: "bubble.left.and.bubble.right", value: "\(assistant.dialogueHistory.count)", label: "реплик")
                StatItem(icon: "timer", value: formatDuration(Date().timeIntervalSince(assistant.dialogueHistory.first?.timestamp ?? Date())), label: "времени"        .stroke(assistant.suggestedResponse.isEmpty ? Color.clear : Color.orange.opacity(0.5), lineWidth: 2)
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
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
        .padding(.top)
    }
    
    private var complexityLabel: String {
        if assistant.confidenceLevel < 0.3 {
            return "Простой"
        } else if assistant.confidenceLevel < 0.7 {
            return "Средний"
        } else {
            return "Сложный"
        }
    }
    
    private var complexityColor: Color {
        if assistant.confidenceLevel < 0.3 {
            return .green
        } else if assistant.confidenceLevel < 0.7 {
            return .orange
        } else {
            return .red
        }
    }
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
                        // Сохраняем сессию для анализа
                        saveInterviewSession(result)
                    }
                }
            }
        }
    }
    
    private func openFloatingWindow() {
        if floatingWindow == nil {
            floatingWindow = FloatingTranscriptWindowController()
        }
        floatingWindow?.showWindow(nil)
        floatingWindow?.window?.makeKeyAndOrderFront(nil)
    }
    
    private func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
    }
    
    private func toggleFloatingWindow() {
        if floatingWindow?.window?.isVisible == true {
            closeFloatingWindow()
        } else {
            openFloatingWindow()
        }
    }
    
    private func saveInterviewSession(_ result: (filename: String, duration: TimeInterval, transcript: String)) {
        let newSession = Session(
            id: UUID(),
            date: Date(),
            duration: result.duration,
            audioFilename: result.filename,
            transcript: result.transcript,
            analysis: nil,
            analysisUpdatedAt: nil,
            analysisSchemaVersion: nil,
            isProcessing: false,
            category: .meetings,
            customTitle: "Interview - \(Date().formatted(date: .abbreviated, time: .shortened))",
            source: .recording
        )
        
        PersistenceService.shared.saveSession(newSession)
        print("✅ Interview session saved: \(newSession.id)")
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
        }.error = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func stopAssistant() {
        assistant.stop()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    InterviewAssistantView()
        .frame(width: 600, height: 500)
}
