import Foundation

/// A message surfaced in the app-level alert. Carries its own title so an import summary does not
/// have to masquerade as a failure.
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func failure(_ message: String) -> AppAlert {
        AppAlert(title: "Something went wrong", message: message)
    }
}

/// One alert channel for the whole app. Auth and the session store both raise messages, and SwiftUI
/// presents only one alert per view — routing them through a single published value means a
/// sign-in failure and an import summary can never silently drop each other.
final class AlertCenter: ObservableObject {
    @Published var current: AppAlert?

    func report(_ alert: AppAlert) {
        current = alert
    }

    func report(failure message: String) {
        current = .failure(message)
    }
}
