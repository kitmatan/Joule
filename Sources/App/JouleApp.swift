import SwiftUI
import FirebaseCore

@main
struct JouleApp: App {
    @StateObject private var alerts: AlertCenter
    @StateObject private var auth: AuthService
    @StateObject private var store: SessionStore

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
                .onOpenURL { auth.handle($0) }
        }
    }
}
