import Foundation
import Combine
import WidgetKit

/// Keeps the App Group snapshot, the home screen widgets, and the watch in step with the store.
///
/// Publishing is debounced rather than immediate: a CSV import or the first Firestore sync
/// rewrites `sessions` in bursts, and recomputing battery health for every intermediate state
/// would burn CPU on results nobody sees. A short settle window collapses each burst into one
/// write, and the widget reload that follows is itself rate-limited by the system.
@MainActor
final class SnapshotPublisher: ObservableObject {
    /// Long enough to swallow a sync burst, short enough that a manually logged charge appears on
    /// the Home Screen before the user has finished putting their phone away.
    private static let settleWindow: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(600)

    private let store: SessionStore
    private let relay: PhoneWatchRelay
    private var cancellables: Set<AnyCancellable> = []

    /// The last payload written, so a settings change that alters nothing observable does not
    /// churn the widget timeline.
    private var lastPublished: JouleSnapshot?

    init(store: SessionStore, relay: PhoneWatchRelay = .shared) {
        self.store = store
        self.relay = relay
    }

    /// Begins observing. Safe to call more than once; later calls replace the subscriptions.
    func start() {
        cancellables.removeAll()
        relay.activate()

        let sessionsChanged = store.$sessions.map { _ in () }
        let vehiclesChanged = store.$vehicles.map { _ in () }
        let selectionChanged = store.$selectedVehicleId.map { _ in () }

        // Currency, units, and the gas baseline all live in UserDefaults via `@AppStorage`, and
        // every one of them changes what the widget should read. Observing the store alone would
        // leave the widget showing dollars after a switch to baht until the next charge is logged.
        let defaultsChanged = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }

        Publishers.Merge4(sessionsChanged, vehiclesChanged, selectionChanged, defaultsChanged)
            .debounce(for: Self.settleWindow, scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.publish() }
            .store(in: &cancellables)

        publish()
    }

    /// Rebuilds and distributes the snapshot. Call directly after an action that must land
    /// immediately; routine changes arrive through `start()`'s subscriptions.
    func publish() {
        let snapshot = makeSnapshot()

        // `generatedAt` moves every time, so compare everything else — otherwise the guard below
        // would never hold and the debounce would be the only thing preventing churn.
        if var previous = lastPublished {
            previous.generatedAt = snapshot.generatedAt
            guard previous != snapshot else { return }
        }

        lastPublished = snapshot

        if SharedStorage.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        relay.send(snapshot)
    }

    private func makeSnapshot() -> JouleSnapshot {
        SnapshotBuilder.build(
            sessions: store.sessions(for: store.selectedVehicleId),
            vehicle: store.activeVehicle,
            vehicleCount: store.vehicles.count,
            currency: VehicleProfile.currency,
            unitSystem: VehicleProfile.unitSystem
        )
    }
}
