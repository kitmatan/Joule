import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var alerts: AlertCenter
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        Group {
            if Platform.isMac {
                MacRootView()
            } else {
                PhoneRootView()
            }
        }
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
    @State private var selectedTab: Int = {
        switch ProcessInfo.processInfo.environment["SCREENSHOT_TAB"] {
        case "1", "battery_health": return 1
        case "2", "history": return 2
        default: return 0
        }
    }()

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
                TabView(selection: $selectedTab) {
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
    }
}
