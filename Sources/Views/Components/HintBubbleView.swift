import SwiftUI
import AppKit

struct HintBubbleView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 14)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(l10n.t("Hints", ru: "Подсказки"))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.95))
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 120, height: 26)
                        .overlay(
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.9)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 1).repeatForever(), value: viewModel.currentHint?.id)
                                Text(l10n.t("Live", ru: "Live"))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                    Spacer()
                    Button(action: { viewModel.clearHints() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if let hint = viewModel.currentHint {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.t("Question", ru: "Вопрос"))
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
                            Text(l10n.t("Answer", ru: "Ответ"))
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t("No hints yet", ru: "Пока нет подсказок"))
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.85))
                        if !viewModel.hasAPIKey {
                            Text(l10n.t("Add an API key in Settings to enable live analysis.", ru: "Добавьте API ключ в настройках — без него live анализ не работает."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else if viewModel.isRecording {
                            Text(l10n.t("Recording: first hint usually appears in 10–20 seconds.", ru: "Идёт запись: ждём первую подсказку (обычно 10–20 секунд)."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text(l10n.t("Start recording to get real-time hints.", ru: "Запустите запись — подсказки будут появляться в реальном времени."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                HStack(spacing: 12) {
                    Button(action: viewModel.previousHint) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.28))
                    .foregroundColor(.white)
                    .disabled(viewModel.hints.isEmpty)

                    Button(action: viewModel.nextHint) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.28))
                    .foregroundColor(.white)
                    .disabled(viewModel.hints.isEmpty)

                    Spacer()

                    Button(action: copyHint) {
                        Label(l10n.t("Copy", ru: "Копировать"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.22))
                    .foregroundColor(.white)
                    .disabled(viewModel.currentHint == nil)
                }
                .padding(.top, 4)
                EngagementBar(value: viewModel.engagement)
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

    private var gradientColors: [Color] {
        // Более контрастный градиент: зелёный -> жёлтый -> красный
        let level = viewModel.engagement
        let green = Color(red: 0.1, green: 0.8, blue: 0.4)
        let yellow = Color(red: 0.95, green: 0.75, blue: 0.25)
        let red = Color(red: 0.9, green: 0.25, blue: 0.35)
        let mix1 = green.mix(with: yellow, amount: 1 - level)
        let mix2 = yellow.mix(with: red, amount: 1 - level)
        return [mix1.opacity(0.98), mix2.opacity(0.98)]
    }
}

// Толстая полоса вовлечённости с подсказкой цвета
struct EngagementBar: View {
    let value: Double
    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n.t("Engagement", ru: "Вовлечённость"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [Color.white, Color.white.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(12, CGFloat(value) * 300), height: 8)
                    .animation(.easeInOut(duration: 0.25), value: value)
            }
        }
    }
}

private extension Color {
    func mix(with other: Color, amount: Double) -> Color {
        let a = max(0, min(1, amount))
        let from = NSColor(self)
        let to = NSColor(other)
        let r = from.redComponent + (to.redComponent - from.redComponent) * a
        let g = from.greenComponent + (to.greenComponent - from.greenComponent) * a
        let b = from.blueComponent + (to.blueComponent - from.blueComponent) * a
        return Color(red: r, green: g, blue: b)
    }
}
