import SwiftUI
import AppKit

struct HintBubbleView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Подсказки")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Button(action: { viewModel.clearHints() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if let hint = viewModel.currentHint {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Вопрос")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(hint.question)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Ответ")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(hint.answer)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.currentHint?.id)
                    }
                } else {
                    Text("Пока нет подсказок")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }

                HStack(spacing: 12) {
                    Button(action: viewModel.previousHint) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .disabled(viewModel.hints.isEmpty)

                    Button(action: viewModel.nextHint) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .disabled(viewModel.hints.isEmpty)

                    Spacer()

                    Button(action: copyHint) {
                        Label("Копировать", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.16))
                    .foregroundColor(.white)
                    .disabled(viewModel.currentHint == nil)
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(width: 360, height: 280)
    }

    private func copyHint() {
        guard let hint = viewModel.currentHint else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hint.answer, forType: .string)
    }
}
