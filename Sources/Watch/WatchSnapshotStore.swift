import Foundation
import Combine
import WatchConnectivity
import WidgetKit

/// The watch app's copy of the phone's data.
///
/// The watch never computes anything: Firestore has no watchOS slice, and re-deriving battery
/// health on a watch CPU to display one percentage would be wasteful even if it did. The phone
/// publishes a snapshot; this receives it, persists it to the watch's own App Group so the
/// complications can read it without launching the app, and republishes it to SwiftUI.
@MainActor
final class WatchSnapshotStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: JouleSnapshot?
    @Published private(set) var isRefreshing = false

    /// Set when a manual refresh could not reach the phone, so the UI can say why rather than
    /// silently showing stale numbers.
    @Published private(set) var lastRefreshFailed = false

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    override init() {
        super.init()
        // Seeded from disk so the first frame shows the last known values instead of a spinner,
        // even when the phone is out of range.
        snapshot = SharedStorage.loadSnapshot()
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Pulls the newest snapshot from the phone. Only possible while the phone is reachable;
    /// otherwise the app keeps whatever arrived last.
    func refresh() async {
        guard let session, session.activationState == .activated, session.isReachable else {
            lastRefreshFailed = true
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let payload: [String: Any]? = await withCheckedContinuation { continuation in
            session.sendMessage(
                [SharedStorage.refreshRequestKey: true],
                replyHandler: { continuation.resume(returning: $0) },
                errorHandler: { _ in continuation.resume(returning: nil) }
            )
        }

        guard let payload, let received = SharedStorage.decodeFromTransfer(payload) else {
            lastRefreshFailed = true
            return
        }

        lastRefreshFailed = false
        apply(received)
    }

    private func apply(_ received: JouleSnapshot) {
        // Application context and complication transfers can arrive out of order; keeping the
        // newer of the two prevents a delayed delivery from rolling the display backwards.
        if let current = snapshot, current.generatedAt >= received.generatedAt { return }

        snapshot = received
        if SharedStorage.save(received) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    nonisolated private func receive(_ payload: [String: Any]) {
        guard let received = SharedStorage.decodeFromTransfer(payload) else { return }
        Task { @MainActor in
            self.lastRefreshFailed = false
            self.apply(received)
        }
    }
}

extension WatchSnapshotStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard error == nil, activationState == .activated else { return }
        // The phone may have pushed a context while the watch app was not running.
        receive(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receive(userInfo)
    }
}
