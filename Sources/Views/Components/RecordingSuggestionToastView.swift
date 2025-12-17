import SwiftUI

struct RecordingSuggestionToastView: View {
    let title: String
    let message: String
    let onStart: () -> Void
    let onLater: () -> Void

    @EnvironmentObject private var l10n: LocalizationService

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white.opacity(0.85))
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onLater) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(message)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label(l10n.t("Start recording", ru: "Начать запись"), systemImage: "record.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.22))
                    .foregroundColor(.white)

                    Button(l10n.t("Later", ru: "Позже")) {
                        onLater()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.28))
                    .foregroundColor(.white)

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .frame(width: 360, height: 180)
    }
}
