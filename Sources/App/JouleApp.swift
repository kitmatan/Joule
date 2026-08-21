import SwiftUI
import FirebaseCore

@main
struct JouleApp: App {
    @StateObject private var alerts: AlertCenter
    @StateObject private var auth: AuthService
    @StateObject private var store: SessionStore
    @StateObject private var navCoordinator = AppNavigationCoordinator()
    @StateObject private var snapshotPublisher: SnapshotPublisher

    init() {
        FirebaseApp.configure()

        // One AlertCenter shared by both services, and one SessionStore shared with the snapshot
        // publisher. Both are built here rather than inside `StateObject`'s autoclosure because
        // the publisher needs the same store instance the views get — and `configure()` above has
        // already run, which was the reason for deferring construction in the first place.
        let alerts = AlertCenter()
        let store = SessionStore(alerts: alerts)
        _alerts = StateObject(wrappedValue: alerts)
        _auth = StateObject(wrappedValue: AuthService(alerts: alerts))
        _store = StateObject(wrappedValue: store)
        _snapshotPublisher = StateObject(wrappedValue: SnapshotPublisher(store: store))
    }

    var body: some Scene {
        WindowGroup("Joule") {
            ContentView()
                .environmentObject(alerts)
                .environmentObject(auth)
                .environmentObject(store)
                .environmentObject(navCoordinator)
                .onOpenURL { handle($0) }
                .task { snapshotPublisher.start() }
        }
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    navCoordinator.presentNewSession()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .importExport) {
                Button("Import CSV…") {
                    navCoordinator.triggerImport()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export All to CSV…") {
                    navCoordinator.triggerExport()
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Dashboard") {
                    navCoordinator.selectTab(.dashboard)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Battery Health") {
                    navCoordinator.selectTab(.batteryHealth)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("History") {
                    navCoordinator.selectTab(.history)
                }
                .keyboardShortcut("3", modifiers: .command)
            }
        }
    }

    /// Routes incoming URLs. Widget and complication taps arrive on the `joule` scheme; everything
    /// else is Google's OAuth callback, which must still reach `AuthService` untouched — swallowing
    /// it here would hang sign-in on the redirect with no visible error.
    private func handle(_ url: URL) {
        guard url.scheme == SharedStorage.urlScheme else {
            auth.handle(url)
            return
        }

        switch url.host {
        case "add":
            navCoordinator.presentNewSession()
        case "battery":
            navCoordinator.selectTab(.batteryHealth)
        case "history":
            navCoordinator.selectTab(.history)
        default:
            navCoordinator.selectTab(.dashboard)
        }
    }
}
