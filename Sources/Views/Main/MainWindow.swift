import SwiftUI

struct MainWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSidebarItem: SidebarItem? = .record
    @State private var navigationPath: [Session] = []
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            NavigationStack(path: $navigationPath) {
                switch selectedSidebarItem {
                case .record:
                    RecordView(viewModel: viewModel, recorder: viewModel.audioRecorder)
                case .history:
                    HistoryView(viewModel: viewModel) { session in
                        navigationPath.append(session)
                    }
                case .settings:
                    SettingsView()
                case .none:
                    Text("Select an item")
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session, viewModel: viewModel)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
