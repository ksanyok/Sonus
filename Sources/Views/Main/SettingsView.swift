import SwiftUI
import AVFoundation
import Carbon
import AppKit

struct SettingsView: View {
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var updateService = UpdateService.shared
    @State private var apiKey: String = ""
    @State private var micPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var showSaveSuccess = false
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool? = nil
    @State private var keyValidationMessage: String? = nil
    @State private var hotkeyChar: String = "Space"
    @State private var useCommand = true
    @State private var useShift = true
    @State private var useOption = false
    @State private var useControl = false
    @State private var audioFolderName: String = PersistenceService.shared.audioStorageDirectory.lastPathComponent
    @State private var audioFolderPath: String = PersistenceService.shared.audioStorageDirectoryPath

    @State private var suggestionsEnabled: Bool = UserDefaults.standard.object(forKey: "triggers.enabled") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "triggers.enabled")
    @State private var suggestOnMicActive: Bool = UserDefaults.standard.object(forKey: "triggers.mic") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "triggers.mic")
    @State private var suggestOnAppsActive: Bool = UserDefaults.standard.object(forKey: "triggers.apps") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "triggers.apps")
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(l10n.t("Settings", ru: "Настройки"))
                    .font(.largeTitle).bold()

                // Баннер обновления
                if let update = updateService.updateAvailable {
                    UpdateBanner(update: update)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Language", ru: "Язык"))
                        .font(.headline)
                    Picker(l10n.t("App language", ru: "Язык приложения"), selection: $l10n.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(l10n.t("Applies immediately inside the app.", ru: "Применяется сразу внутри приложения."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Storage", ru: "Хранилище"))
                        .font(.headline)

                    HStack(alignment: .firstTextBaseline) {
                        Text(l10n.t("Audio folder", ru: "Папка аудио"))
                        Spacer()
                        Text(audioFolderName)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text(audioFolderPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    HStack(spacing: 10) {
                        Button(l10n.t("Reveal in Finder", ru: "Показать в Finder")) {
                            PersistenceService.shared.revealAudioStorageDirectoryInFinder()
                        }
                        Button(l10n.t("Change…", ru: "Изменить…")) {
                            pickAudioStorageDirectory()
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Permissions", ru: "Разрешения")).font(.headline)
                    HStack {
                        Text(l10n.t("Microphone access", ru: "Доступ к микрофону"))
                        Spacer()
                        switch micPermissionStatus {
                        case .authorized:
                            Label(l10n.t("Authorized", ru: "Разрешено"), systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .denied, .restricted:
                            Button(l10n.t("Open System Settings", ru: "Открыть системные настройки")) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        case .notDetermined:
                            Button(l10n.t("Request access", ru: "Запросить доступ")) {
                                requestMicPermission()
                            }
                        @unknown default:
                            Text(l10n.t("Unknown", ru: "Неизвестно"))
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("OpenAI", ru: "OpenAI")).font(.headline)
                    SecureField(l10n.t("API Key", ru: "API ключ"), text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(l10n.t("Your API key is stored locally.", ru: "Ключ хранится локально на этом компьютере."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button(isValidatingKey ? l10n.t("Validating…", ru: "Проверяем…") : l10n.t("Validate key", ru: "Проверить ключ")) {
                            validateKey()
                        }
                        .disabled(isValidatingKey)

                        if let ok = keyValidationResult {
                            Label(ok ? l10n.t("Valid", ru: "Валиден") : l10n.t("Invalid", ru: "Неверный"), systemImage: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundColor(ok ? .green : .red)
                        }
                        Spacer()
                    }
                    if let msg = keyValidationMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Suggestions", ru: "Подсказки"))
                        .font(.headline)

                    Toggle(l10n.t("Suggest starting a recording", ru: "Подсказывать начать запись"), isOn: $suggestionsEnabled)

                    Toggle(l10n.t("When microphone becomes active", ru: "Когда активируется микрофон"), isOn: $suggestOnMicActive)
                        .disabled(!suggestionsEnabled)

                    Toggle(l10n.t("When Telegram/Viber becomes active", ru: "Когда активируется Telegram/Viber"), isOn: $suggestOnAppsActive)
                        .disabled(!suggestionsEnabled)

                    Text(l10n.t("Shows a small prompt near the menu bar.", ru: "Показывает небольшую подсказку возле меню-бара."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Analysis Settings", ru: "Настройки анализа"))
                        .font(.headline)
                    
                    Picker(l10n.t("Default Playbook", ru: "Сценарий по умолчанию"), selection: $viewModel.selectedPlaybook) {
                        ForEach(Playbook.allCases) { playbook in
                            Text(playbook.displayName).tag(playbook)
                        }
                    }
                    
                    Text(l10n.t("Custom Vocabulary", ru: "Словарь компании"))
                        .font(.subheadline)
                    TextEditor(text: $viewModel.customVocabulary)
                        .font(.body)
                        .frame(height: 60)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        
                    Text(l10n.t("Add product names, competitors, or slang (comma separated).", ru: "Добавьте названия продуктов, конкурентов или сленг (через запятую)."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("Hotkey", ru: "Хоткей"))
                        .font(.headline)
                    HStack {
                        Text(l10n.t("Key", ru: "Клавиша"))
                        Spacer()
                        TextField(l10n.t("Space or letter", ru: "Space или буква"), text: $hotkeyChar)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 140)
                    }
                    HStack {
                        Toggle(l10n.t("Command", ru: "Command"), isOn: $useCommand)
                        Toggle(l10n.t("Shift", ru: "Shift"), isOn: $useShift)
                    }
                    HStack {
                        Toggle(l10n.t("Option", ru: "Option"), isOn: $useOption)
                        Toggle(l10n.t("Control", ru: "Control"), isOn: $useControl)
                    }
                    Text(l10n.t("Use a single key name like 'Space' or 'A'.", ru: "Используйте одно имя клавиши: 'Space' или 'A'."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // About Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n.t("About", ru: "О приложении"))
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 16) {
                        if let icon = NSImage(named: "AppIcon") {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "waveform.circle.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sonus")
                                .font(.title3)
                                .bold()
                            Text(l10n.t("Version 1.4", ru: "Версия 1.4"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(updateService.isCheckingForUpdates ? l10n.t("Checking…", ru: "Проверка…") : l10n.t("Check for updates", ru: "Проверить обновления")) {
                                Task {
                                    await updateService.checkForUpdates(silent: false)
                                }
                            }
                            .disabled(updateService.isCheckingForUpdates)
                            .buttonStyle(.link)
                        }
                    }
                    
                    Text(l10n.t("Developed by BuyReadySite.com", ru: "Разработано BuyReadySite.com"))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .onTapGesture {
                            if let url = URL(string: "https://buyreadysite.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .onHover { isHovered in
                            NSCursor.pointingHand.set()
                        }
                    
                    Text(l10n.t("Sonus is your personal AI meeting assistant. It records, transcribes, and analyzes conversations to help you be more effective.", ru: "Sonus — ваш персональный AI-ассистент для встреч. Записывает, транскрибирует и анализирует разговоры, помогая вам быть эффективнее."))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    
                    Divider()
                    
                    Text(l10n.t("Technical Requirements:", ru: "Технические требования:"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("macOS 14.0+", systemImage: "desktopcomputer")
                        Label(l10n.t("Microphone Access", ru: "Доступ к микрофону"), systemImage: "mic")
                        Label(l10n.t("OpenAI API Key", ru: "API ключ OpenAI"), systemImage: "key")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                HStack {
                    Spacer()
                    Button(l10n.t("Save", ru: "Сохранить")) { saveSettings() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                
                if showSaveSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(l10n.t("Settings saved", ru: "Настройки сохранены"))
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: 720)
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 420)
        .onAppear {
            loadSettings()
            checkMicPermission()
            refreshAudioFolderUI()
            persistTriggerSettings()
        }
        .onChange(of: suggestionsEnabled) { _, _ in
            persistTriggerSettings()
        }
        .onChange(of: suggestOnMicActive) { _, _ in
            persistTriggerSettings()
        }
        .onChange(of: suggestOnAppsActive) { _, _ in
            persistTriggerSettings()
        }
    }
    
    private func saveSettings() {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeychainService.shared.delete()
        } else {
            KeychainService.shared.save(key: apiKey)
        }
        saveHotkey()

        Task { @MainActor in
            await viewModel.refreshAPIKeyStatus(force: true)
        }

        withAnimation {
            showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func loadSettings() {
        if let key = KeychainService.shared.load() {
            apiKey = key
        }
        loadHotkey()
    }

    private func validateKey() {
        keyValidationMessage = nil
        keyValidationResult = nil
        isValidatingKey = true

        Task {
            do {
                let ok = try await OpenAIClient.shared.validateAPIKey()
                await MainActor.run {
                    keyValidationResult = ok
                    keyValidationMessage = ok
                        ? l10n.t("Key works.", ru: "Ключ работает.")
                        : l10n.t("Key rejected by OpenAI (401/403).", ru: "OpenAI отклонил ключ (401/403).")
                    isValidatingKey = false

                    viewModel.apiKeyStatus = ok ? .valid : .invalid
                }
            } catch {
                await MainActor.run {
                    keyValidationResult = false
                    keyValidationMessage = error.localizedDescription
                    isValidatingKey = false

                    if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.apiKeyStatus = .missing
                    } else {
                        viewModel.updateAPIKeyStatusFromOpenAIError(error)
                    }
                }
            }
        }
    }

    private func persistTriggerSettings() {
        UserDefaults.standard.set(suggestionsEnabled, forKey: "triggers.enabled")
        UserDefaults.standard.set(suggestOnMicActive, forKey: "triggers.mic")
        UserDefaults.standard.set(suggestOnAppsActive, forKey: "triggers.apps")
        NotificationCenter.default.post(name: .sonusTriggersDidChange, object: nil)
    }
    
    private func checkMicPermission() {
        micPermissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }
    
    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            DispatchQueue.main.async {
                checkMicPermission()
            }
        }
    }

    private func pickAudioStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = l10n.t("Choose", ru: "Выбрать")
        panel.title = l10n.t("Choose Audio Storage Folder", ru: "Выберите папку для хранения аудио")

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PersistenceService.shared.setAudioStorageDirectory(url)
                refreshAudioFolderUI()
            } catch {
                viewModel.errorMessage = l10n.t("Failed to set audio folder: ", ru: "Не удалось выбрать папку аудио: ") + error.localizedDescription
                viewModel.showError = true
            }
        }
    }

    private func refreshAudioFolderUI() {
        audioFolderName = PersistenceService.shared.audioStorageDirectory.lastPathComponent
        audioFolderPath = PersistenceService.shared.audioStorageDirectoryPath
    }

    private func saveHotkey() {
        let code = keyCode(for: hotkeyChar)
        var modifiers = 0
        if useCommand { modifiers |= Int(cmdKey) }
        if useShift { modifiers |= Int(shiftKey) }
        if useOption { modifiers |= Int(optionKey) }
        if useControl { modifiers |= Int(controlKey) }
        UserDefaults.standard.set(code, forKey: "hotkey.code")
        UserDefaults.standard.set(modifiers, forKey: "hotkey.modifiers")
        GlobalHotKeyService.shared.register()
    }

    private func loadHotkey() {
        let code = UserDefaults.standard.integer(forKey: "hotkey.code")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkey.modifiers")
        hotkeyChar = readableKeyName(from: code)
        useCommand = modifiers & Int(cmdKey) != 0
        useShift = modifiers & Int(shiftKey) != 0
        useOption = modifiers & Int(optionKey) != 0
        useControl = modifiers & Int(controlKey) != 0
    }

    private func keyCode(for input: String) -> Int {
        let upper = input.trimmingCharacters(in: .whitespaces).uppercased()
        switch upper {
        case "SPACE", "" : return Int(kVK_Space)
        case "A": return Int(kVK_ANSI_A)
        case "B": return Int(kVK_ANSI_B)
        case "C": return Int(kVK_ANSI_C)
        case "D": return Int(kVK_ANSI_D)
        case "E": return Int(kVK_ANSI_E)
        case "F": return Int(kVK_ANSI_F)
        case "G": return Int(kVK_ANSI_G)
        case "H": return Int(kVK_ANSI_H)
        case "I": return Int(kVK_ANSI_I)
        case "J": return Int(kVK_ANSI_J)
        case "K": return Int(kVK_ANSI_K)
        case "L": return Int(kVK_ANSI_L)
        case "M": return Int(kVK_ANSI_M)
        case "N": return Int(kVK_ANSI_N)
        case "O": return Int(kVK_ANSI_O)
        case "P": return Int(kVK_ANSI_P)
        case "Q": return Int(kVK_ANSI_Q)
        case "R": return Int(kVK_ANSI_R)
        case "S": return Int(kVK_ANSI_S)
        case "T": return Int(kVK_ANSI_T)
        case "U": return Int(kVK_ANSI_U)
        case "V": return Int(kVK_ANSI_V)
        case "W": return Int(kVK_ANSI_W)
        case "X": return Int(kVK_ANSI_X)
        case "Y": return Int(kVK_ANSI_Y)
        case "Z": return Int(kVK_ANSI_Z)
        default: return Int(kVK_Space)
        }
    }

    private func readableKeyName(from code: Int) -> String {
        switch code {
        case Int(kVK_ANSI_A): return "A"
        case Int(kVK_ANSI_B): return "B"
        case Int(kVK_ANSI_C): return "C"
        case Int(kVK_ANSI_D): return "D"
        case Int(kVK_ANSI_E): return "E"
        case Int(kVK_ANSI_F): return "F"
        case Int(kVK_ANSI_G): return "G"
        case Int(kVK_ANSI_H): return "H"
        case Int(kVK_ANSI_I): return "I"
        case Int(kVK_ANSI_J): return "J"
        case Int(kVK_ANSI_K): return "K"
        case Int(kVK_ANSI_L): return "L"
        case Int(kVK_ANSI_M): return "M"
        case Int(kVK_ANSI_N): return "N"
        case Int(kVK_ANSI_O): return "O"
        case Int(kVK_ANSI_P): return "P"
        case Int(kVK_ANSI_Q): return "Q"
        case Int(kVK_ANSI_R): return "R"
        case Int(kVK_ANSI_S): return "S"
        case Int(kVK_ANSI_T): return "T"
        case Int(kVK_ANSI_U): return "U"
        case Int(kVK_ANSI_V): return "V"
        case Int(kVK_ANSI_W): return "W"
        case Int(kVK_ANSI_X): return "X"
        case Int(kVK_ANSI_Y): return "Y"
        case Int(kVK_ANSI_Z): return "Z"
        default: return "Space"
        }
    }
}
