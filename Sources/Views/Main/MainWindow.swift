import SwiftUI

struct MainWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @State private var selectedSidebarItem: SidebarItem? = .record
    @State private var navigationPath: [UUID] = []
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            NavigationStack(path: $navigationPath) {
                switch selectedSidebarItem {
                case .record:
                    RecordView(viewModel: viewModel, recorder: viewModel.audioRecorder, sidebarSelection: $selectedSidebarItem)
                case .history:
                    HistoryView(viewModel: viewModel) { session in
                        navigationPath.append(session.id)
                    }
                case .settings:
                    SettingsView()
                case .none:
                    Text(l10n.t("Select an item", ru: "Выберите раздел"))
                }
            }
            .navigationDestination(for: UUID.self) { id in
                SessionDetailView(sessionID: id, viewModel: viewModel)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert(l10n.t("Error", ru: "Ошибка"), isPresented: $viewModel.showError) {
            Button(l10n.t("OK", ru: "ОК"), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? l10n.t("Unknown error", ru: "Неизвестная ошибка"))
        }
    }
}
