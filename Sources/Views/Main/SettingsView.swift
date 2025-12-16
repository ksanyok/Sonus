import SwiftUI
import AVFoundation

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var micPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Permissions")) {
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
            
            Section(header: Text("OpenAI Configuration")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Your API key is stored securely in the Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                Button("Save") {
                    KeychainService.shared.save(key: apiKey)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
        .onAppear {
            if let key = KeychainService.shared.load() {
                apiKey = key
            }
            checkMicPermission()
        }
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
}
