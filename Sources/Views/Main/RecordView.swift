import SwiftUI
import UniformTypeIdentifiers

struct RecordView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var recorder: AudioRecorder
    @Binding var sidebarSelection: SidebarItem?
    @EnvironmentObject private var l10n: LocalizationService
    @StateObject private var updateService = UpdateService.shared
    @State private var isHovering = false
    @State private var pulseAnimation = false
    @State private var startingPulse = false
    @State private var showingUpdateSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.1, blue: 0.16),
                    Color(red: 0.05, green: 0.07, blue: 0.11)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -200, y: -220)
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 200, y: 240)
            
            VStack(spacing: 28) {
                // Баннер обновления
                if let update = updateService.updateAvailable {
                    UpdateBannerCompact(update: update, showingUpdateSheet: $showingUpdateSheet)
                        .padding(.horizontal, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                HStack {
                    SonusTopBar(
                        left: AnyView(
                            HStack(spacing: 10) {
                                Button {
                                    sidebarSelection = .history
                                } label: {
                                    Label(l10n.t("History", ru: "История"), systemImage: "clock.fill")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    sidebarSelection = .settings
                                } label: {
                                    Label(l10n.t("Settings", ru: "Настройки"), systemImage: "gear")
                                }
                                .buttonStyle(.bordered)
                            }
                            .foregroundColor(.white.opacity(0.9))
                        ),
                        right: AnyView(
                            HStack(spacing: 10) {
                                // Версия приложения
                                Text("v1.4.2")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                                
                                Label(
                                    recorder.isRecording
                                        ? l10n.t("Recording", ru: "Запись")
                                        : (viewModel.isStartingRecording ? l10n.t("Starting…", ru: "Запуск…") : l10n.t("Ready", ru: "Готов")),
                                    systemImage: recorder.isRecording ? "record.circle" : (viewModel.isStartingRecording ? "hourglass" : "waveform")
                                )
                                .font(.headline)
                                .foregroundColor(recorder.isRecording ? .red : .white.opacity(0.9))

                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 32)
                                    .overlay(
                                        HStack(spacing: 10) {
                                            Image(systemName: "waveform.path.ecg")
                                            Text(recorder.isRecording ? l10n.t("Live", ru: "Live") : l10n.t("Standby", ru: "Ожидание"))
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                    )
                            }
                        )
                    )
                    .foregroundColor(.white.opacity(0.92))
                }
                .padding(.horizontal, 4)

                Text(l10n.t("Hotkey: Cmd+Shift+Space (configurable in Settings)", ru: "Хоткей: Cmd+Shift+Space (настраивается в Settings)"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                
                HStack(alignment: .top, spacing: 20) {
                    // Left: recording card
                    VStack(spacing: 20) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                VStack(spacing: 18) {
                                    if recorder.isRecording {
                                        Text(timeString(from: recorder.recordingDuration))
                                            .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                                            .foregroundColor(.white)
                                            .contentTransition(.numericText())
                                    } else {
                                        Text(l10n.t("Ready to record", ru: "Готов к записи"))
                                            .font(.system(size: 32, weight: .light))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    
                                    VisualizerView(levels: recorder.audioLevels)
                                        .frame(height: 140)
                                        .opacity(recorder.isRecording ? 1 : 0.45)
                                }
                                .padding(24)
                            )
                            .frame(minWidth: 420)
                            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)
                        
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(l10n.t("Title", ru: "Название"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField(l10n.t("e.g. Client meeting", ru: "Например, Встреча с клиентом"), text: $viewModel.draftTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(l10n.t("Category", ru: "Категория"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                Picker(l10n.t("Category", ru: "Категория"), selection: $viewModel.draftCategory) {
                                    ForEach(SessionCategory.allCases) { category in
                                        HStack {
                                            Image(systemName: category.icon)
                                            Text(l10n.t(category.displayNameEn, ru: category.displayNameRu))
                                        }
                                        .tag(category)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    
                    // Right: controls card
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                VStack(spacing: 16) {
                                    Text(recorder.isRecording ? l10n.t("Recording in progress", ru: "Идёт запись") : l10n.t("Tap to start", ru: "Нажми, чтобы начать"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                            if recorder.isRecording {
                                                viewModel.stopRecording()
                                            } else {
                                                viewModel.startRecording()
                                            }
                                        }
                                    }) {
                                        ZStack {
                                            // Starting pulse ring (visual feedback immediately on tap)
                                            if viewModel.isStartingRecording && !recorder.isRecording {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 3)
                                                    .frame(width: 134, height: 134)
                                                    .scaleEffect(startingPulse ? 1.08 : 0.95)
                                                    .opacity(startingPulse ? 0.2 : 0.55)
                                                    .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: startingPulse)
                                            }

                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: recorder.isRecording ? [.red, .orange] : [.cyan, .purple]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 4
                                                )
                                                .frame(width: 120, height: 120)
                                                .scaleEffect(isHovering ? 1.08 : 1.0)
                                                .opacity(0.65)
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: recorder.isRecording ? [.red, .orange] : [.blue, .purple]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 108, height: 108)
                                                .shadow(color: (recorder.isRecording ? Color.red : Color.blue).opacity(0.6), radius: 28, x: 0, y: 14)
                                                .scaleEffect(isHovering ? 1.05 : 1.0)
                                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                                .font(.system(size: 44, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hover in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isHovering = hover
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(l10n.t("Tips", ru: "Советы"))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text(l10n.t("Use the hotkey or the button to start. Title and category will be saved into the new session.", ru: "Используй хоткей или кнопку, чтобы начать. Категория и название сохранятся в новую запись."))
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.system(size: 15))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.2))

                                    if viewModel.isImportingAudio {
                                        HStack(spacing: 10) {
                                            ProgressView()
                                                .controlSize(.large)
                                            Text(l10n.t("Importing audio…", ru: "Импортируем аудио…"))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                    
                                    HStack(spacing: 10) {
                                        Button {
                                            importAudio()
                                        } label: {
                                            Label(l10n.t("Import", ru: "Импорт"), systemImage: "square.and.arrow.down")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(.secondary)
                                        .font(.system(size: 15, weight: .semibold))
                                        .disabled(viewModel.isImportingAudio)
                                        .help(l10n.t("Import audio file (or drag & drop)", ru: "Загрузить файл (или перетащить сюда)"))

                                        Button {
                                            importFromNotes()
                                        } label: {
                                            Label(l10n.t("From Notes", ru: "Из Заметок"), systemImage: "note.text")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(.secondary)
                                        .font(.system(size: 15, weight: .semibold))
                                        .disabled(viewModel.isImportingAudio)
                                        .help(l10n.t("Select an audio file exported from Apple Notes", ru: "Выберите аудио, экспортированное из Заметок"))
                                    }
                                }
                                .padding(22)
                            )
                            .frame(width: 320)
                            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)
                    }
                }
            }
            .padding(24)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        viewModel.importAudio(from: url)
                    }
                }
            }
            return true
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: viewModel.isStartingRecording) { _, newValue in
            if newValue {
                startingPulse = true
            } else {
                startingPulse = false
            }
        }
        .sheet(isPresented: $showingUpdateSheet) {
            UpdateView()
        }
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func importAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = l10n.t("Select an audio file or Voice Memo", ru: "Выберите аудиофайл или запись диктофона")
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.importAudio(from: url)
            }
        }
    }

    private func importFromNotes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = l10n.t(
            "Select an audio file exported from Apple Notes (Share → Save to Files / AirDrop), or drag the attachment from Notes into Sonus.",
            ru: "Выберите аудио, экспортированное из Заметок (Поделиться → Сохранить в Файлы / AirDrop), или перетащите вложение из Заметок в Sonus."
        )
        panel.prompt = l10n.t("Import", ru: "Импортировать")

        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.importAudio(from: url)
            }
        }
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseEffect())
    }
}

struct PulseEffect: ViewModifier {
    @State private var isOn = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isOn ? 0.5 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isOn = true
                }
            }
    }
}
