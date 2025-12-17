import SwiftUI

struct MainWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @State private var selectedSidebarItem: SidebarItem? = .record
    @State private var navigationPath: [UUID] = []
    @State private var navigationResetToken = UUID()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem, onInvoke: { item in
                // Always exit detail views when invoking any sidebar item.
                navigationPath.removeAll()
                viewModel.selectedSession = nil
                selectedSidebarItem = item
                navigationResetToken = UUID()
            })
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 400)
        } detail: {
            NavigationStack(path: $navigationPath) {
                switch selectedSidebarItem {
                case .record:
                    RecordView(viewModel: viewModel, recorder: viewModel.audioRecorder, sidebarSelection: $selectedSidebarItem)
                case .history:
                    HistoryView(viewModel: viewModel) { session in
                        navigationPath.append(session.id)
                    }
                case .analytics:
                    DashboardView()
                case .search:
                    GlobalSearchView()
                case .settings:
                    SettingsView()
                case .none:
                    Text(l10n.t("Select an item", ru: "Выберите раздел"))
                }
            }
            // Also reset any internal navigation state from destination-based NavigationLinks.
            .id(navigationResetToken)
            .navigationDestination(for: UUID.self) { id in
                SessionDetailView(sessionID: id, viewModel: viewModel)
            }
        }
        .frame(minWidth: 1100, minHeight: 800)
        .alert(l10n.t("Error", ru: "Ошибка"), isPresented: $viewModel.showError) {
            Button(l10n.t("OK", ru: "ОК"), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? l10n.t("Unknown error", ru: "Неизвестная ошибка"))
        }
    }
}
