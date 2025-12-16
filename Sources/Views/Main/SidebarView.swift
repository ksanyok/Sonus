import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarItem.record) {
                Label("Record", systemImage: "mic.fill")
            }
            
            NavigationLink(value: SidebarItem.history) {
                Label("History", systemImage: "clock.fill")
            }
            
            NavigationLink(value: SidebarItem.settings) {
                Label("Settings", systemImage: "gear")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Sonus")
    }
}

enum SidebarItem: Hashable {
    case record
    case history
    case settings
}
