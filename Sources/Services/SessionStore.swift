import Foundation
import FirebaseFirestore

class SessionStore: ObservableObject {
    /// Firestore rejects a batched write of more than 500 operations outright — nothing in an
    /// oversized batch is written — so a large import has to be split.
    private static let maxBatchSize = 500

    @Published var sessions: [ChargingSession] = []

    private let alerts: AlertCenter
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private(set) var userID: String?

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Paths

    /// Every session lives under its owner, so the security rules can scope access by UID.
    private func sessionsCollection(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("sessions")
    }

    /// The flat, pre-auth collection. Read once per user by the migration below, never written.
    private var legacySessionsCollection: CollectionReference {
        db.collection("sessions")
    }

    // MARK: - Connection

    /// Binds the store to a signed-in user. Idempotent, so re-delivering the same UID (a token
    /// refresh, a view reappearing) does not tear down and rebuild a working listener.
    func connect(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        sessions = []
        startListening(userID: userID)
        migrateLegacySessionsIfNeeded(userID: userID)
    }

    func disconnect() {
        userID = nil
        listenerRegistration?.remove()
        listenerRegistration = nil
        // Signing out must not leave the previous user's history on screen.
        sessions = []
    }

    private func startListening(userID: String) {
        // Replacing a live listener without removing it would leave it attached and double-billed.
        listenerRegistration?.remove()
        listenerRegistration = sessionsCollection(for: userID)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self else { return }
                // Signing out revokes the token before this listener is torn down, so a callback
                // already in flight can arrive with a permission error — expected teardown noise,
                // and its payload must not repopulate the list for a user who just left.
                guard self.userID == userID else { return }

                guard let documents = querySnapshot?.documents else {
                    self.alerts.report(failure: "Failed to load sessions: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                self.sessions = documents.compactMap { document in
                    try? document.data(as: ChargingSession.self)
                }
            }
    }

    // MARK: - Writes

    func saveSession(_ session: ChargingSession) {
        guard let userID else {
            alerts.report(failure: "You are signed out, so that session was not saved.")
            return
        }
        do {
            let collection = sessionsCollection(for: userID)
            if let id = session.id {
                try collection.document(id).setData(from: session)
            } else {
                let docRef = collection.document()
                var newSession = session
                newSession.id = docRef.documentID
                try docRef.setData(from: newSession)
            }
        } catch {
            alerts.report(failure: "Failed to save session: \(error.localizedDescription)")
        }
    }

    func deleteSession(_ session: ChargingSession) {
        guard let userID, let id = session.id else { return }
        sessionsCollection(for: userID).document(id).delete { [weak self] error in
            if let error {
                self?.alerts.report(failure: "Failed to delete session: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CSV import

    /// Handles the result of a `fileImporter`. Lives here so iOS and macOS share one implementation
    /// — they previously kept separate copies, and the iOS one reported its failures only to the
    /// console, leaving a failed import silent on iPhone.
    func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                alerts.report(failure: "Could not get permission to read that file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let string = try String(contentsOf: url, encoding: .utf8)
                let parsed = CSVParser.parseSessions(from: string)
                guard !parsed.sessions.isEmpty else {
                    alerts.report(failure: parsed.skippedRows > 0
                        ? "No sessions could be read from that file. \(parsed.skippedRows) \(parsed.skippedRows == 1 ? "row was" : "rows were") missing a readable date."
                        : "That file contained no sessions.")
                    return
                }
                importSessions(parsed.sessions, skippedRows: parsed.skippedRows)
            } catch {
                alerts.report(failure: "Failed to read CSV: \(error.localizedDescription)")
            }
        case .failure(let error):
            alerts.report(failure: "Error importing: \(error.localizedDescription)")
        }
    }

    /// - Parameter skippedRows: rows the parser could not read, folded into the summary so the user
    ///   sees one report covering the whole import rather than the write half of it.
    func importSessions(_ importedSessions: [ChargingSession], skippedRows: Int = 0) {
        guard !importedSessions.isEmpty else { return }
        guard let userID else {
            alerts.report(failure: "You are signed out, so nothing was imported.")
            return
        }

        let collection = sessionsCollection(for: userID)
        var documents: [(DocumentReference, ChargingSession)] = []
        for session in importedSessions {
            let docRef: DocumentReference
            if let id = session.id, !id.isEmpty {
                docRef = collection.document(id)
            } else {
                docRef = collection.document()
            }
            var newSession = session
            newSession.id = docRef.documentID
            documents.append((docRef, newSession))
        }

        write(documents) { [weak self] written, encodingFailures, error in
            guard let self else { return }
            if let error {
                self.alerts.report(failure: "Import failed: \(error.localizedDescription)")
                return
            }
            self.alerts.report(AppAlert(
                title: "Import Complete",
                message: Self.importSummary(written: written, skipped: skippedRows, encodingFailures: encodingFailures)
            ))
        }
    }

    private static func importSummary(written: Int, skipped: Int, encodingFailures: Int) -> String {
        var parts = ["Imported \(written) \(written == 1 ? "session" : "sessions")."]
        if skipped > 0 {
            parts.append("\(skipped) \(skipped == 1 ? "row was" : "rows were") missing a readable date and \(skipped == 1 ? "was" : "were") skipped.")
        }
        if encodingFailures > 0 {
            parts.append("\(encodingFailures) could not be saved.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Batched writes

    /// Splits `documents` across as many batches as the 500-operation cap requires and reports once
    /// they have all settled.
    private func write(
        _ documents: [(DocumentReference, ChargingSession)],
        completion: @escaping (_ written: Int, _ encodingFailures: Int, _ error: (any Error)?) -> Void
    ) {
        var batches: [WriteBatch] = []
        var batch = db.batch()
        var pending = 0
        var encodingFailures = 0

        for (docRef, session) in documents {
            do {
                try batch.setData(from: session, forDocument: docRef)
                pending += 1
                if pending == Self.maxBatchSize {
                    batches.append(batch)
                    batch = db.batch()
                    pending = 0
                }
            } catch {
                encodingFailures += 1
            }
        }
        if pending > 0 {
            batches.append(batch)
        }

        let written = documents.count - encodingFailures
        let group = DispatchGroup()
        // Firestore delivers completion handlers on the main queue, so this is only ever touched
        // from one thread despite the batches committing concurrently.
        var firstFailure: (any Error)?

        for batch in batches {
            group.enter()
            batch.commit { error in
                if let error, firstFailure == nil { firstFailure = error }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(written, encodingFailures, firstFailure)
        }
    }

    // MARK: - Legacy migration

    /// Copies the pre-auth top-level `sessions` collection into the signed-in user's subtree, once.
    ///
    /// Non-destructive in both directions: the originals are left in place, and a legacy document
    /// whose ID already exists under the user is skipped rather than overwritten. That second rule
    /// is what makes the pass safe to repeat — without it, a re-run after the user had edited a
    /// migrated session would silently revert their edit back to the legacy copy.
    private func migrateLegacySessionsIfNeeded(userID: String) {
        let marker = db.collection("users").document(userID)
        marker.getDocument { [weak self] snapshot, _ in
            guard let self else { return }
            // A failed marker read just means trying again next launch, which the skip-existing
            // rule above makes harmless. Not worth interrupting the user for.
            guard snapshot?.get("legacySessionsMigrated") as? Bool != true else { return }
            self.copyLegacySessions(to: userID, marker: marker)
        }
    }

    private func copyLegacySessions(to userID: String, marker: DocumentReference) {
        legacySessionsCollection.getDocuments { [weak self] legacySnapshot, error in
            guard let self else { return }

            if error != nil {
                // Almost always "the rules do not expose the legacy collection", which is the
                // expected end state once step 5 of FIREBASE_SETUP.md is done. Deliberately does
                // not set the marker: a user who has genuinely not migrated yet should retry on the
                // next launch rather than be recorded as migrated on the strength of a denied read.
                // A successful migration sets the marker, so this cannot loop forever in practice.
                return
            }

            let legacyDocuments = legacySnapshot?.documents ?? []
            guard !legacyDocuments.isEmpty else {
                self.markMigrated(marker, note: "nothing to migrate")
                return
            }

            let collection = self.sessionsCollection(for: userID)
            collection.getDocuments { [weak self] existingSnapshot, error in
                guard let self else { return }
                if let error {
                    self.alerts.report(failure: "Could not check your existing sessions before migrating: \(error.localizedDescription)")
                    return
                }

                let existingIDs = Set((existingSnapshot?.documents ?? []).map(\.documentID))
                let pending: [(DocumentReference, ChargingSession)] = legacyDocuments.compactMap { document in
                    guard !existingIDs.contains(document.documentID),
                          var session = try? document.data(as: ChargingSession.self) else { return nil }
                    session.id = document.documentID
                    return (collection.document(document.documentID), session)
                }

                guard !pending.isEmpty else {
                    self.markMigrated(marker, note: "already present")
                    return
                }

                self.write(pending) { [weak self] written, _, error in
                    guard let self else { return }
                    if let error {
                        self.alerts.report(failure: "Could not move your existing sessions into your account: \(error.localizedDescription)")
                        return
                    }
                    self.markMigrated(marker, note: "migrated \(written)")
                    self.alerts.report(AppAlert(
                        title: "History Restored",
                        message: "Moved \(written) \(written == 1 ? "session" : "sessions") into your account. The originals were left untouched — see FIREBASE_SETUP.md for how to remove them once you are happy."
                    ))
                }
            }
        }
    }

    private func markMigrated(_ marker: DocumentReference, note: String) {
        marker.setData([
            "legacySessionsMigrated": true,
            "legacySessionsMigratedAt": FieldValue.serverTimestamp(),
            "legacySessionsMigrationNote": note
        ], merge: true)
    }
}
