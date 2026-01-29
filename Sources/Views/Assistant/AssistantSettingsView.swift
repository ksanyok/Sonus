import SwiftUI

/// Настройки AI ассистента
struct AssistantSettingsView: View {
    @StateObject private var assistant = RealTimeAssistantService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("Настройки ассистента")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Язык
                    settingSection(
                        title: "Целевой язык",
                        description: "На какой язык переводить расшифровку",
                        icon: "globe"
                    ) {
                        Picker("", selection: $assistant.targetLanguage) {
                            ForEach(RealTimeAssistantService.AssistantLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    Divider()
                    
                    // Режим работы
                    settingSection(
                        title: "Режим работы",
                        description: "Как ассистент должен помогать",
                        icon: "sparkles"
                    ) {
                        VStack(spacing: 8) {
                            ForEach(RealTimeAssistantService.AssistantMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Автоматические подсказки
                    settingSection(
                        title: "Автоподсказки",
                        description: "Автоматически генерировать рекомендации",
                        icon: "lightbulb"
                    ) {
                        Toggle("", isOn: $assistant.autoSuggest)
                            .toggleStyle(.switch)
                    }
                    
                    Divider()
                    
                    // Информация
                    infoSection
                }
                .padding()
            }
            
            Divider()
            
            // Кнопки действий
            HStack {
                Button("Сбросить") {
                    resetToDefaults()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Готово") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Components
    
    private func settingSection<Content: View>(
        title: String,
        description: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            content()
        }
    }
    
    private func modeButton(_ mode: RealTimeAssistantService.AssistantMode) -> some View {
        let isSelected = assistant.assistantMode == mode
        let isRecommended = mode == .translation
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                assistant.assistantMode = mode
            }
        } label: {
            HStack {
                // Иконка с анимированным индикатором выбора
                ZStack {
                    Circle()
                        .fill(isSelected ? 
                              LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color.secondary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode.displayName)
                            .font(.body)
                            .fontWeight(isSelected ? .bold : .medium)
                            .foregroundColor(isSelected ? .primary : .secondary)
                        
                        if isRecommended {
                            Text("⭐️ Рекомендуем")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(modeDescription(mode))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Большой чекмарк для выбранного
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .font(.title2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.secondary.opacity(0.05)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? 
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isSelected ? 2.5 : 0
                    )
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("Как это работает")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                infoItem(
                    number: "1",
                    text: "Ассистент слушает разговор и расшифровывает речь"
                )
                
                infoItem(
                    number: "2",
                    text: "Переводит на выбранный язык в реальном времени"
                )
                
                infoItem(
                    number: "3",
                    text: "Анализирует вовлечённость собеседника"
                )
                
                infoItem(
                    number: "4",
                    text: "Даёт подсказки и рекомендации по режиму работы"
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    private func infoItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func modeDescription(_ mode: RealTimeAssistantService.AssistantMode) -> String {
        switch mode {
        case .translation:
            return "Перевод на целевой язык + подсказки для ответа"
        case .coaching:
            return "Анализ разговора + советы по улучшению коммуникации"
        case .notes:
            return "Автоматические заметки и ключевые моменты беседы"
        }
    }
    
    private func resetToDefaults() {
        assistant.targetLanguage = .russian
        assistant.assistantMode = .translation
        assistant.autoSuggest = true
    }
    
    private func saveAndClose() {
        assistant.saveSettings()
        dismiss()
    }
}

#Preview {
    AssistantSettingsView()
}
