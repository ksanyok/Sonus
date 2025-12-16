import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarItem.record) {
                Label(l10n.t("Record", ru: "Запись"), systemImage: "mic.fill")
            }
            
            NavigationLink(value: SidebarItem.history) {
                Label(l10n.t("History", ru: "История"), systemImage: "clock.fill")
            }
            
            NavigationLink(value: SidebarItem.settings) {
                Label(l10n.t("Settings", ru: "Настройки"), systemImage: "gear")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("")
    }
}

enum SidebarItem: Hashable {
    case record
    case history
    case settings
}
