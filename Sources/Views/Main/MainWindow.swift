import SwiftUI

struct MainWindow: View {
    @StateObject var viewModel = AppViewModel()
    @State private var selectedSidebarItem: SidebarItem? = .record
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            switch selectedSidebarItem {
            case .record:
                RecordView(viewModel: viewModel)
            case .history:
                HistoryView(viewModel: viewModel)
            case .settings:
                SettingsView()
            case .none:
                Text("Select an item")
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
