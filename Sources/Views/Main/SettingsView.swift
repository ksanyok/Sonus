import SwiftUI
import AVFoundation
import Carbon

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var micPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var showSaveSuccess = false
    @State private var hotkeyChar: String = "Space"
    @State private var useCommand = true
    @State private var useShift = true
    @State private var useOption = false
    @State private var useControl = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle).bold()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions").font(.headline)
                    HStack {
                        Text("Microphone Access")
                        Spacer()
                        switch micPermissionStatus {
                        case .authorized:
                            Label("Authorized", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .denied, .restricted:
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        case .notDetermined:
                            Button("Request Access") {
                                requestMicPermission()
                            }
                        @unknown default:
                            Text("Unknown")
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAI Configuration").font(.headline)
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Your API key is stored locally.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hotkey").font(.headline)
                    HStack {
                        Text("Key")
                        Spacer()
                        TextField("Space or letter", text: $hotkeyChar)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 140)
                    }
                    HStack {
                        Toggle("Command", isOn: $useCommand)
                        Toggle("Shift", isOn: $useShift)
                    }
                    HStack {
                        Toggle("Option", isOn: $useOption)
                        Toggle("Control", isOn: $useControl)
                    }
                    Text("Use single key name like 'Space' or 'A'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                HStack {
                    Spacer()
                    Button("Save") { saveSettings() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                
                if showSaveSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings saved successfully")
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
        }
    }
    
    private func saveSettings() {
        guard !apiKey.isEmpty else { return }
        KeychainService.shared.save(key: apiKey)
        saveHotkey()
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
