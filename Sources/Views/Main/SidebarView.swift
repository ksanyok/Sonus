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
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.2) : color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : color)
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? color : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
                    .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
            )
            .contentShape(Rectangle())
            .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hover
            }
        }
    }
}

enum SidebarItem: Hashable {
    case record
    case history
    case settings
}
