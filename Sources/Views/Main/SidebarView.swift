import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        VStack(spacing: 16) {
            SidebarButton(
                title: l10n.t("Record", ru: "Запись"),
                icon: "mic.fill",
                color: .red,
                isSelected: selection == .record
            ) { selection = .record }
            
            SidebarButton(
                title: l10n.t("History", ru: "История"),
                icon: "clock.fill",
                color: .blue,
                isSelected: selection == .history
            ) { selection = .history }
            
            SidebarButton(
                title: l10n.t("Settings", ru: "Настройки"),
                icon: "gear",
                color: .gray,
                isSelected: selection == .settings
            ) { selection = .settings }
            
            Spacer()
        }
        .padding()
        .navigationTitle("")
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.2) : color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : color)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum SidebarItem: Hashable {
    case record
    case history
    case settings
}
