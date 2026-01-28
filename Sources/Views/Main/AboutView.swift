import SwiftUI

struct AboutView: View {
    @EnvironmentObject var l10n: LocalizationService
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side: Icon
            VStack {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                } else {
                    Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 200)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Right side: Info
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sonus")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text(l10n.t("Version 1.4.5 (Build 10)", ru: "Версия 1.4.5 (Сборка 10)"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("Developed by", ru: "Разработчик"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("BuyReadySite.com", destination: URL(string: "https://buyreadysite.com")!)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("System Requirements", ru: "Системные требования"))
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("macOS 14.0 (Sonoma) or newer", systemImage: "desktopcomputer")
                        Label(l10n.t("Apple Silicon (M1+) or Intel Core i5+", ru: "Apple Silicon (M1+) или Intel Core i5+"), systemImage: "cpu")
                        Label(l10n.t("4GB RAM minimum (8GB recommended)", ru: "Минимум 4ГБ RAM (рекомендуется 8ГБ)"), systemImage: "memorychip")
                        Label(l10n.t("Active Internet connection", ru: "Активное интернет-соединение"), systemImage: "network")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Button(l10n.t("Check for Updates", ru: "Проверить обновления")) {
                        if let url = URL(string: "https://buyreadysite.com/sonus/updates") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    
                    Spacer()
                    
                    Text("© 2025 BuyReadySite")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .frame(width: 600, height: 380)
    }
}
