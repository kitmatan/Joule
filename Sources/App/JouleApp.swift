import SwiftUI
import FirebaseCore

@main
struct JouleApp: App {
    @StateObject private var alerts: AlertCenter
    @StateObject private var auth: AuthService
    @StateObject private var store: SessionStore
    @StateObject private var navCoordinator = AppNavigationCoordinator()

    init() {
        FirebaseApp.configure()

        // One AlertCenter shared by both services. `StateObject(wrappedValue:)` takes an
        // autoclosure, so nothing here is constructed until the scene first renders — safely after
        // `configure()` has run.
        let alerts = AlertCenter()
        _alerts = StateObject(wrappedValue: alerts)
        _auth = StateObject(wrappedValue: AuthService(alerts: alerts))
        _store = StateObject(wrappedValue: SessionStore(alerts: alerts))
    }

    var body: some Scene {
        WindowGroup("Joule") {
            ContentView()
                .environmentObject(alerts)
                .environmentObject(auth)
                .environmentObject(store)
                .environmentObject(navCoordinator)
                .onOpenURL { auth.handle($0) }
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
}
