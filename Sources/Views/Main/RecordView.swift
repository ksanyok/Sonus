import SwiftUI

struct RecordView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var recorder: AudioRecorder
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
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
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(recorder.isRecording ? "Recording" : "Ready", systemImage: recorder.isRecording ? "record.circle" : "waveform")
                            .font(.headline)
                            .foregroundColor(recorder.isRecording ? .red : .white.opacity(0.9))
                        Text("Hotkey: Cmd+Shift+Space (настраивается в Settings)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 36)
                        .overlay(
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.path.ecg")
                                Text(recorder.isRecording ? "Live" : "Standby")
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 14)
                        )
                }
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
                                        Text("Готов к записи")
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
                                Text("Название")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("Например, Встреча с клиентом", text: $viewModel.draftTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Категория")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                Picker("Категория", selection: $viewModel.draftCategory) {
                                    ForEach(SessionCategory.allCases) { category in
                                        HStack {
                                            Image(systemName: category.icon)
                                            Text(category.displayName)
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
                                    Text(recorder.isRecording ? "Идёт запись" : "Нажми, чтобы начать")
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
                                        Text("Советы")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Используй хоткей или кнопку, чтобы начать. Категория и название сохранятся в новую запись.")
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.footnote)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.2))
                                    
                                    HStack(spacing: 12) {
                                        Button {
                                            viewModel.startRecording()
                                        } label: {
                                            Label("Старт", systemImage: "play.fill")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        
                                        Button {
                                            viewModel.stopRecording()
                                        } label: {
                                            Label("Стоп", systemImage: "stop.fill")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
