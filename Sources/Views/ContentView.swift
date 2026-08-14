import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var alerts: AlertCenter
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        Group {
            switch auth.state {
            case .resolving:
                // Firebase restores a persisted session asynchronously; showing the sign-in screen
                // in the meantime would flash it at every returning user.
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                SignInView()
            case .signedIn:
                if Platform.isMac {
                    MacRootView()
                } else {
                    PhoneRootView()
                }
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
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            NavigationStack {
                BatteryHealthView()
            }
            .tabItem {
                Label("Battery Health", systemImage: "bolt.batteryblock.fill")
            }

            SessionListView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
        }
    }
}
