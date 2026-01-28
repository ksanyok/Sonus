import SwiftUI
import AppKit

/// Плавающее окно с транскрипцией, которое остается поверх всех окон
class FloatingTranscriptWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Interview Transcript"
        window.level = .floating // Поверх всех окон
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        window.titlebarAppearsTransparent = false
        window.isOpaque = false
        
        // Позиционируем в правом верхнем углу
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 420
            let y = screenFrame.maxY - 620
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let contentView = FloatingTranscriptView()
        window.contentView = NSHostingView(rootView: contentView)
        
        self.init(window: window)
    }
}

struct FloatingTranscriptView: View {
    @ObservedObject var assistant = InterviewAssistantService.shared
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.blue)
                Text("Live Transcript")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { autoScroll.toggle() }) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(autoScroll ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .help("Auto-scroll")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Транскрипция
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if assistant.dialogueHistory.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Waiting for conversation...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        } else {
                            ForEach(assistant.dialogueHistory) { entry in
                                DialogueEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(12)
                }
                .onChange(of: assistant.dialogueHistory.count) { _, _ in
                    if autoScroll, let lastEntry = assistant.dialogueHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Текущая подсказка (если есть)
            if !assistant.suggestedResponse.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Suggested Response:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text(assistant.suggestedResponse)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }
}

struct DialogueEntryRow: View {
    let entry: InterviewAssistantService.DialogueEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Метка говорящего
            HStack(spacing: 4) {
                Image(systemName: entry.speaker == .interviewer ? "person.fill" : "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(entry.speaker == .interviewer ? .blue : .green)
                
                Text(entry.speaker == .interviewer ? "Interviewer" : "You")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(entry.speaker == .interviewer ? .blue : .green)
                
                Spacer()
                
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Английский текст
            Text(entry.englishText)
                .font(.body)
                .foregroundColor(.primary)
                .padding(8)
                .background(entry.speaker == .interviewer ? Color.blue.opacity(0.05) : Color.green.opacity(0.05))
                .cornerRadius(8)
            
            // Русский перевод
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(entry.russianTranslation)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FloatingTranscriptView()
        .frame(width: 400, height: 600)
}
