import SwiftUI

struct MainWindowView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection: SidebarItem? = .dashboard
    @StateObject private var dashboardVM = DashboardViewModel()

    var body: some View {
        if hasCompletedOnboarding {
            mainContent
        } else {
            OnboardingView()
                .frame(minWidth: 700, minHeight: 500)
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 250)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    dashboardVM.fixAll()
                } label: {
                    Label("Fix All", systemImage: "wrench.and.screwdriver")
                }
                .disabled(dashboardVM.totalIssueCount == 0 || dashboardVM.isFixingAll)

                Button {
                    dashboardVM.scan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(dashboardVM.isScanning)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            DashboardDetailView(viewModel: dashboardVM)
        case .vpnClients:
            VPNClientsDetailView(viewModel: dashboardVM)
        case .network:
            NetworkDetailView(viewModel: dashboardVM)
        case .logs:
            LogViewerView()
        case .general:
            GeneralSettingsView()
        case .notifications:
            NotificationsSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .about:
            AboutView()
        case nil:
            DashboardDetailView(viewModel: dashboardVM)
        }
    }
}
