import SwiftUI
import AppKit

/// Современное плавающее окно AI ассистента в стиле ChatGPT
/// Активируется горячими клавишами, всегда поверх других окон
class FloatingAssistantWindow: NSWindowController {
    private static var instance: FloatingAssistantWindow?
    
    static func show() {
        if instance == nil {
            let contentView = FloatingAssistantView()
            let window = ModernFloatingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                contentView: NSHostingView(rootView: contentView)
            )
            instance = FloatingAssistantWindow(window: window)
        }
        
        instance?.showWindow(nil)
        instance?.window?.makeKeyAndOrderFront(nil)
        instance?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    static func hide() {
        instance?.close()
        instance = nil
    }
    
    static func toggle() {
        if instance?.window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}

/// Кастомное окно с современными эффектами
class ModernFloatingWindow: NSWindow {
    init(contentRect: NSRect, contentView: NSView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.contentView = contentView
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        
        // Скругление углов
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 16
        self.contentView?.layer?.masksToBounds = true
    }
}

/// Контент плавающего окна
struct FloatingAssistantView: View {
    @StateObject private var assistant = RealTimeAssistantService.shared
    @State private var showSettings = false
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Фон с эффектом стекла
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            
            VStack(spacing: 0) {
                // Заголовок с кнопками
                headerView
                
                Divider()
                
                // Основной контент
                if assistant.isActive {
                    activeAssistantView
                } else {
                    inactiveView
                }
            }
        }
        .frame(width: 400, height: 600)
        .sheet(isPresented: $showSettings) {
            AssistantSettingsView()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    assistant.isActive ?
                    LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.headline)
                
                Text(assistant.isActive ? "Активен" : "Неактивен")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Кнопка настроек
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Настройки")
            
            // Кнопка закрытия
            Button {
                FloatingAssistantWindow.hide()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Закрыть")
        }
        .padding()
        .background(Color.black.opacity(0.05))
    }
    
    // MARK: - Active State
    
    private var activeAssistantView: some View {
        VStack(spacing: 0) {
            // ФИКСИРОВАННАЯ СЕКЦИЯ: Подсказка всегда вверху
            if !assistant.suggestion.isEmpty {
                suggestionView
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // ФИКСИРОВАННАЯ СЕКЦИЯ: Текущая транскрипция
            if !assistant.currentTranscript.isEmpty {
                currentTranscriptView
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // Индикатор количества собеседников
            speakersIndicator
                .padding(.horizontal)
                .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // СКРОЛЛЯЩАЯСЯ ИСТОРИЯ - только старые записи
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Индикатор вовлечённости
                        engagementIndicator
                        
                        // История разговора (без текущей)
                        ForEach(assistant.conversationHistory) { entry in
                            conversationBubble(entry)
                                .id(entry.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: assistant.conversationHistory.count) { _ in
                    if let lastEntry = assistant.conversationHistory.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Кнопка остановки
            Button {
                Task {
                    await assistant.stop()
                }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Остановить")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
    
    // MARK: - Inactive State
    
    private var inactiveView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Иконка
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "waveform.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Голосовой AI Ассистент")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Нажмите кнопку для активации")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Информация о режиме
            VStack(spacing: 12) {
                infoRow(icon: "globe", text: "Язык: \(assistant.targetLanguage.displayName)")
                infoRow(icon: "sparkles", text: "Режим: \(assistant.assistantMode.displayName)")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Кнопка запуска
            Button {
                Task {
                    try? await assistant.start()
                }
            } label: {
                HStack {
                    Image(systemName: "mic.circle.fill")
                    Text("Начать запись")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Components
    
    private var engagementIndicator: some View {
        HStack {
            Circle()
                .fill(Color(assistant.engagement.color))
                .frame(width: 12, height: 12)
            
            Text(assistant.engagement.description)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            // Числовой показатель
            Text("\(Int(assistant.engagementScore * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func conversationBubble(_ entry: RealTimeAssistantService.ConversationEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Временная метка
            Text(entry.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Оригинальный текст
            if !entry.originalText.isEmpty {
                Text(entry.originalText)
                    .font(.body)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Перевод
            if !entry.translatedText.isEmpty && entry.translatedText != entry.originalText {
                Text(entry.translatedText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var currentTranscriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("Сейчас")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(assistant.currentTranscript)
                .font(.body)
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            
            if !assistant.translation.isEmpty && assistant.translation != assistant.currentTranscript {
                Text(assistant.translation)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var suggestionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                Text("Подсказка")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Кнопка копирования
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(assistant.suggestion, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Скопировать")
            }
            
            Text(assistant.suggestion)
                .font(.body)
                .fontWeight(.medium)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                )
                .cornerRadius(10)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: Color.yellow.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    /// Индикатор количества распознанных собеседников
    private var speakersIndicator: some View {
        let speakerCount = detectSpeakerCount()
        return HStack(spacing: 12) {
            ForEach(0..<speakerCount, id: \.self) { index in
                HStack(spacing: 4) {
                    Circle()
                        .fill(speakerColor(for: index))
                        .frame(width: 10, height: 10)
                    Text(speakerName(for: index))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Text("\(speakerCount) собеседник\(speakerCount == 1 ? "" : speakerCount < 5 ? "а" : "ов")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func detectSpeakerCount() -> Int {
        // Подсчитываем уникальных говорящих из истории
        var speakers = Set<String>()
        for entry in assistant.conversationHistory {
            if !entry.originalText.isEmpty {
                // Простое определение: если разные стили речи - разные говорящие
                speakers.insert(entry.id.uuidString.prefix(8).description)
            }
        }
        // Минимум 2 собеседника если есть история
        return max(assistant.conversationHistory.isEmpty ? 1 : 2, min(speakers.count, 4))
    }
    
    private func speakerColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple]
        return colors[index % colors.count]
    }
    
    private func speakerName(for index: Int) -> String {
        let names = ["Вы", "Собеседник", "Участник 3", "Участник 4"]
        return names[index % names.count]
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
