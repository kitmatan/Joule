import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var alerts: AlertCenter
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore

    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = AppTheme.defaultTheme

    var body: some View {
        Group {
            if Platform.isMac {
                MacRootView()
            } else {
                PhoneRootView()
            }
        }
        // Theming goes through the window's `overrideUserInterfaceStyle` and nothing else.
        // `preferredColorScheme` drives that same property from SwiftUI's side, and running both
        // leaves them fighting: one of the two hierarchies (root or presented sheet) keeps the
        // stale style until relaunch. One mechanism, applied to the window, restyles everything —
        // sheets included, since they inherit the window's traits.
        .onAppear { theme.applyToOpenWindows() }
        .onChange(of: theme) { _, newTheme in newTheme.applyToOpenWindows() }
        // Covers the case where auth resolved before this view appeared; `onChange` catches the
        // rest. `connect` is idempotent, so the overlap is harmless.
        .task { bindStore(to: auth.state) }
        .onChange(of: auth.state) { _, state in bindStore(to: state) }
        .alert(
            alerts.current?.title ?? "",
            isPresented: Binding(
                get: { alerts.current != nil },
                set: { if !$0 { alerts.current = nil } }
            ),
            presenting: alerts.current
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private func bindStore(to state: AuthService.State) {
        if let userID = state.userID {
            store.connect(userID: userID)
        } else if case .signedOut = state {
            store.disconnect()
        }
    }
}

/// iPhone/iPad experience: bottom tab bar with push navigation.
struct PhoneRootView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator

    var body: some View {
        Group {
            if let targetSession = store.sessions.first, ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "session_detail" {
                NavigationStack {
                    SessionDetailView(session: targetSession)
                }
            } else if ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "add_session" {
                NavigationStack {
                    AddSessionView()
                }
            } else if ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "settings" {
                NavigationStack {
                    SettingsView()
                }
            } else if ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "presets" {
                PresetPickerView(selectedPresetId: .constant("byd_atto3_ext")) { _ in }
            } else {
                TabView(selection: Binding(
                    get: { navCoordinator.selectedTab.rawValue },
                    set: { if let tab = AppTab(rawValue: $0) { navCoordinator.selectTab(tab) } }
                )) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.xaxis")
                        }
                        .tag(0)

                    NavigationStack {
                        BatteryHealthView()
                    }
                    .tabItem {
                        Label("Battery Health", systemImage: "bolt.batteryblock.fill")
                    }
                    .tag(1)

                    SessionListView()
                        .tabItem {
                            Label("History", systemImage: "list.bullet")
                        }
                        .tag(2)
                }
            }
        }
        .sheet(isPresented: $navCoordinator.showingAddSession) {
            AddSessionView()
        }
        .sheet(isPresented: $navCoordinator.showingSettings) {
            SettingsView()
        }
        .fileExporter(
            isPresented: $navCoordinator.showingExporter,
            document: CSVDocument(text: CSVExporter.generateCSV(from: store.sessions)),
            contentType: .commaSeparatedText,
            defaultFilename: "Joule_Export"
        ) { _ in }
        .fileImporter(
            isPresented: $navCoordinator.showingImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            store.handleImport(result)
        }
        .onAppear {
            if let envTab = ProcessInfo.processInfo.environment["SCREENSHOT_TAB"] {
                switch envTab {
                case "1", "battery_health": navCoordinator.selectTab(.batteryHealth)
                case "2", "history": navCoordinator.selectTab(.history)
                default: navCoordinator.selectTab(.dashboard)
                }
            }
        }
    }
}
