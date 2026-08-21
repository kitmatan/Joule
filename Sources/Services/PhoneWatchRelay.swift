import Foundation

#if canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
import WatchConnectivity

/// Ships the published snapshot to the paired Apple Watch.
///
/// `updateApplicationContext` is the right primitive here: it keeps only the newest payload and
/// delivers it opportunistically, which matches a snapshot exactly — an older one has no value
/// once a newer one exists. Complications get a separate nudge, because application context alone
/// does not guarantee a timeline refresh while the watch app is not running.
final class PhoneWatchRelay: NSObject {
    static let shared = PhoneWatchRelay()

    /// Retained so a snapshot produced before the session finished activating is not dropped.
    private var pendingSnapshot: JouleSnapshot?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func send(_ snapshot: JouleSnapshot) {
        guard let session else { return }

        guard session.activationState == .activated else {
            pendingSnapshot = snapshot
            session.delegate = self
            session.activate()
            return
        }

        deliver(snapshot, over: session)
    }

    private func deliver(_ snapshot: JouleSnapshot, over session: WCSession) {
        guard session.isPaired, session.isWatchAppInstalled else { return }
        guard let payload = SharedStorage.encodeForTransfer(snapshot) else { return }

        // A duplicate context throws rather than no-opping, so a failure here is not worth
        // surfacing to the user: the watch already holds an identical snapshot.
        try? session.updateApplicationContext(payload)

        // Complication transfers are rationed by the system (see `remainingComplicationUserInfoTransfers`).
        // Spending one on every write would exhaust the budget on a busy day and leave the
        // complication stale exactly when the user is charging most, so only push once the
        // remaining budget is comfortable.
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 5 {
            session.transferCurrentComplicationUserInfo(payload)
        }
    }

    private func flushPendingSnapshot() {
        guard let pendingSnapshot, let session, session.activationState == .activated else { return }
        self.pendingSnapshot = nil
        deliver(pendingSnapshot, over: session)
    }
}

extension PhoneWatchRelay: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard error == nil, activationState == .activated else { return }
        flushPendingSnapshot()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Reactivating immediately re-binds to the newly paired watch; without it the relay goes
    /// quiet for the rest of the app's lifetime after a watch switch.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Installing the watch app is the moment it first needs data — resend what we have.
        if let snapshot = SharedStorage.loadSnapshot() {
            deliver(snapshot, over: session)
        }
    }

    /// Answers the watch's pull-to-refresh. Application context is opportunistic, so a user who
    /// opens the watch app expecting fresh numbers needs a way to ask for them directly.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message[SharedStorage.refreshRequestKey] != nil else {
            replyHandler([:])
            return
        }
        guard let snapshot = SharedStorage.loadSnapshot(),
              let payload = SharedStorage.encodeForTransfer(snapshot) else {
            replyHandler([:])
            return
        }
        replyHandler(payload)
    }
}

#else

/// Mac Catalyst has no WatchConnectivity. The widgets still work; there is simply no watch to
/// talk to, so the relay degrades to a no-op rather than forcing `#if` at every call site.
final class PhoneWatchRelay {
    static let shared = PhoneWatchRelay()
    private init() {}

    func activate() {}
    func send(_ snapshot: JouleSnapshot) {}
}

#endif
