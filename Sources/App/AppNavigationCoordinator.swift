import SwiftUI
import Combine

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case batteryHealth = 1
    case history = 2

    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .batteryHealth: return "Battery Health"
        case .history: return "History"
        }
    }
}

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var macSidebarSelection: MacSidebarDestination? = .dashboard
    @Published var showingAddSession: Bool = false
    @Published var showingSettings: Bool = false
    @Published var showingExporter: Bool = false
    @Published var showingImporter: Bool = false
    
    func selectTab(_ tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .dashboard:
            macSidebarSelection = .dashboard
        case .batteryHealth:
            macSidebarSelection = .batteryHealth
        case .history:
            macSidebarSelection = .history(.all)
        }
    }
    
    func presentNewSession() {
        showingAddSession = true
    }
    
    func presentSettings() {
        showingSettings = true
    }
    
    func triggerExport() {
        showingExporter = true
    }
    
    func triggerImport() {
        showingImporter = true
    }
}

enum MacSidebarDestination: Hashable {
    case dashboard
    case batteryHealth
    case history(SessionFilter)
}
