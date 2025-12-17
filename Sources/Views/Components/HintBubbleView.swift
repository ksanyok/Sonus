import SwiftUI
import AppKit

struct HintBubbleView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 14)

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
                    Button(action: {
                        NotificationCenter.default.post(name: .sonusCloseHintsPanel, object: nil)
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.isRecording, let hint = viewModel.currentHint {
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
                        if viewModel.apiKeyStatus == .missing {
                            Text(l10n.t("Add an API key in Settings to enable live analysis.", ru: "Добавьте API ключ в настройках — без него live анализ не работает."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Button(l10n.t("Open Settings", ru: "Открыть настройки")) {
                                NotificationCenter.default.post(name: .sonusOpenSettings, object: nil)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.white.opacity(0.28))
                            .foregroundColor(.white)
                            .padding(.top, 4)
                        } else if viewModel.apiKeyStatus == .invalid {
                            Text(l10n.t("API key was rejected by OpenAI. Update it in Settings.", ru: "OpenAI отклонил API ключ. Обновите его в настройках."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Button(l10n.t("Open Settings", ru: "Открыть настройки")) {
                                NotificationCenter.default.post(name: .sonusOpenSettings, object: nil)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.white.opacity(0.28))
                            .foregroundColor(.white)
                            .padding(.top, 4)
                        }

                        if viewModel.isRecording {
                            Text(l10n.t("Recording: first hint usually appears in 10–20 seconds.", ru: "Идёт запись: ждём первую подсказку (обычно 10–20 секунд)."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text(l10n.t("Start recording to get real-time hints.", ru: "Запустите запись — подсказки будут появляться в реальном времени."))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Button(l10n.t("Start recording", ru: "Начать запись")) {
                                viewModel.startRecording()
                                NotificationCenter.default.post(name: .sonusShowMiniWindow, object: nil)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.white.opacity(0.22))
                            .foregroundColor(.white)
                            .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                if viewModel.isRecording, viewModel.currentHint != nil {
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
                    }
                    .padding(.top, 4)
                }

                EngagementBar(value: viewModel.engagement)
            }
            .padding(18)
        }
        .frame(width: 360, height: 280)
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
                    .foregroundColor(indicatorColor.opacity(0.95))
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(12, CGFloat(value) * 300), height: 8)
                    .animation(.easeInOut(duration: 0.25), value: value)
            }

            Text(recommendation)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(2)
        }
    }

    private var indicatorColor: Color {
        Color.engagementIndicator(for: value)
    }

    private var recommendation: String {
        let v = max(0, min(1, value))
        if v < 0.35 {
            return l10n.t(
                "Low interest: ask a clear question, confirm the goal, and propose a simple next step.",
                ru: "Низкая вовлечённость: задай уточняющий вопрос, проясни цель и предложи простой следующий шаг."
            )
        }
        if v < 0.65 {
            return l10n.t(
                "Moderate: mirror their concerns and add one concrete benefit or example.",
                ru: "Средняя: отзеркаль сомнение и добавь один конкретный бенефит или пример."
            )
        }
        return l10n.t(
            "High: keep momentum—confirm agreement and move to the next decision.",
            ru: "Высокая: закрепи согласие и переходи к следующему решению."
        )
    }
}

private extension Color {
    static func engagementIndicator(for value: Double) -> Color {
        let v = max(0, min(1, value))
        if v < 0.5 {
            // Red (1,0,0) -> Yellow (1,1,0)
            let t = v / 0.5
            return Color(red: 1.0, green: t, blue: 0.0)
        } else {
            // Yellow (1,1,0) -> Green (0,1,0)
            let t = (v - 0.5) / 0.5
            return Color(red: 1.0 - t, green: 1.0, blue: 0.0)
        }
    }
}
