import SwiftUI
import AppKit

struct MainWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var l10n: LocalizationService
    @State private var selectedSidebarItem: SidebarItem? = .record
    @State private var navigationPath: [UUID] = []
    @State private var navigationResetToken = UUID()
    
    var body: some View {
        ZStack(alignment: .top) {
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
                    case .interviewAssistant:
                        InterviewAssistantView()
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

            if viewModel.shouldShowAPIKeyBanner, let text = viewModel.apiKeyBannerText {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)

                    Text(l10n.language == .ru
                         ? (viewModel.apiKeyStatus == .missing
                            ? "Не задан API ключ OpenAI. Добавьте его в настройках, чтобы работали транскрибация и анализ."
                            : "API ключ OpenAI отклонён/невалиден. Обновите его в настройках.")
                         : text)
                        .font(.callout)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(l10n.t("Open Settings", ru: "Открыть настройки")) {
                        NSApp.activate(ignoringOtherApps: true)
                        navigationPath.removeAll()
                        viewModel.selectedSession = nil
                        selectedSidebarItem = .settings
                        navigationResetToken = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 10)
                .padding(.horizontal, 12)
                .shadow(radius: 8)
            }
        }
        .onChange(of: viewModel.pendingOpenSessionID) { _, id in
            guard let id else { return }
            // Jump to the newly created/imported session so the user sees it was added.
            navigationPath.removeAll()
            viewModel.selectedSession = nil
            selectedSidebarItem = .history
            navigationPath.append(id)
            viewModel.pendingOpenSessionID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .sonusOpenSettings)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            navigationPath.removeAll()
            viewModel.selectedSession = nil
            selectedSidebarItem = .settings
            navigationResetToken = UUID()
        }
        .alert(l10n.t("Error", ru: "Ошибка"), isPresented: $viewModel.showError) {
            Button(l10n.t("OK", ru: "ОК"), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? l10n.t("Unknown error", ru: "Неизвестная ошибка"))
        }
    }
}
