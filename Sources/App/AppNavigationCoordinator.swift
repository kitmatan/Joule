import SwiftUI
import Combine

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case batteryHealth = 1
    case history = 2
    case garage = 3

    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .batteryHealth: return "Battery Health"
        case .history: return "History"
        case .garage: return "Garage"
        }
    }

    /// Label under the tab bar icon, short enough for five slots on a compact phone.
    var shortTitle: String {
        switch self {
        case .dashboard: return "Overview"
        case .batteryHealth: return "Battery"
        case .history: return "History"
        case .garage: return "Garage"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "chart.bar.xaxis"
        case .batteryHealth: return "bolt.batteryblock"
        case .history: return "list.bullet"
        case .garage: return "car.side"
        }
    }

    /// Filled variant for the selected tab.
    var selectedSymbol: String {
        switch self {
        case .dashboard: return "chart.bar.xaxis"
        case .batteryHealth: return "bolt.batteryblock.fill"
        case .history: return "list.bullet"
        case .garage: return "car.side.fill"
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
        case .garage:
            // The Mac keeps vehicles and preferences in the Settings sheet.
            showingSettings = Platform.isMac
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
