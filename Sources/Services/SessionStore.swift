import Foundation
import FirebaseFirestore

enum SyncStatus: Equatable {
    case localOnly
    case syncing
    case synced(lastSync: Date)
    case error(String)
    
    var isCloudActive: Bool {
        switch self {
        case .syncing, .synced:
            return true
        case .localOnly, .error:
            return false
        }
    }
    
    var statusDescription: String {
        switch self {
        case .localOnly:
            return "Local Storage (Offline-First)"
        case .syncing:
            return "Syncing with Cloud…"
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: date, relativeTo: Date())
            return "Synced \(relative)"
        case .error(let msg):
            return "Sync issue: \(msg)"
        }
    }
}

class SessionStore: ObservableObject {
    /// Firestore rejects a batched write of more than 500 operations outright.
    private static let maxBatchSize = 500

    @Published var sessions: [ChargingSession] = []
    @Published private(set) var syncStatus: SyncStatus = .localOnly

    private let alerts: AlertCenter
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private(set) var userID: String?

    init(alerts: AlertCenter) {
        self.alerts = alerts
        // Synchronously load from local storage so UI renders instantly on startup.
        let local = loadLocalSessions()
        self.sessions = local
        self.syncStatus = .localOnly
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Local Persistence

    private var localStorageURL: URL {
        let fileManager = FileManager.default
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL.documentsDirectory
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("joule_sessions.json")
    }

    private func loadLocalSessions() -> [ChargingSession] {
        guard FileManager.default.fileExists(atPath: localStorageURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: localStorageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ChargingSession].self, from: data)
        } catch {
            print("Failed to load local sessions: \(error)")
            return []
        }
    }

    private func persistLocalSessions() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: localStorageURL, options: .atomic)
        } catch {
            print("Failed to save local sessions: \(error)")
        }
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

    // MARK: - Connection & Cloud Sync

    /// Binds the store to a signed-in user and synchronizes local and cloud sessions.
    func connect(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        self.syncStatus = .syncing
        
        startListening(userID: userID)
        syncLocalSessionsToCloud(userID: userID)
        migrateLegacySessionsIfNeeded(userID: userID)
    }

    func disconnect(clearLocalData: Bool = false) {
        userID = nil
        listenerRegistration?.remove()
        listenerRegistration = nil
        syncStatus = .localOnly
        
        if clearLocalData {
            sessions = []
            try? FileManager.default.removeItem(at: localStorageURL)
        }
    }

    func forceSync() {
        guard let userID else {
            syncStatus = .localOnly
            return
        }
        syncStatus = .syncing
        
        sessionsCollection(for: userID)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.syncStatus = .error(error.localizedDescription)
                    self.alerts.report(failure: "Sync failed: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.syncStatus = .synced(lastSync: Date())
                    return
                }
                
                let remoteSessions = documents.compactMap { try? $0.data(as: ChargingSession.self) }
                self.sessions = remoteSessions
                self.persistLocalSessions()
                self.syncStatus = .synced(lastSync: Date())
            }
    }

    private func startListening(userID: String) {
        listenerRegistration?.remove()
        listenerRegistration = sessionsCollection(for: userID)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self else { return }
                guard self.userID == userID else { return }

                if let error {
                    self.syncStatus = .error(error.localizedDescription)
                    self.alerts.report(failure: "Failed to load cloud sessions: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents else { return }

                let cloudSessions = documents.compactMap { document in
                    try? document.data(as: ChargingSession.self)
                }
                
                self.sessions = cloudSessions
                self.persistLocalSessions()
                self.syncStatus = .synced(lastSync: Date())
            }
    }

    /// Automatically uploads any local-only sessions to the user's Firestore collection upon sign-in.
    private func syncLocalSessionsToCloud(userID: String) {
        let localSessions = self.sessions
        guard !localSessions.isEmpty else { return }
        
        let collection = sessionsCollection(for: userID)
        collection.getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                print("Could not query existing cloud sessions for merge: \(error)")
                return
            }
            
            let remoteIDs = Set((snapshot?.documents ?? []).map(\.documentID))
            let pendingUploads: [(DocumentReference, ChargingSession)] = localSessions.compactMap { session in
                if let id = session.id, remoteIDs.contains(id) {
                    return nil // Already in cloud
                }
                let docRef = (session.id != nil && !session.id!.isEmpty) ? collection.document(session.id!) : collection.document()
                var updated = session
                updated.id = docRef.documentID
                return (docRef, updated)
            }
            
            guard !pendingUploads.isEmpty else { return }
            
            self.write(pendingUploads) { [weak self] written, _, error in
                guard self != nil else { return }
                if error == nil && written > 0 {
                    print("Synced \(written) local session(s) to cloud account.")
                }
            }
        }
    }

    // MARK: - Writes

    func saveSession(_ session: ChargingSession) {
        var sessionToSave = session
        
        if let userID {
            // Signed-in Cloud Mode
            do {
                let collection = sessionsCollection(for: userID)
                if let id = sessionToSave.id, !id.isEmpty {
                    try collection.document(id).setData(from: sessionToSave)
                } else {
                    let docRef = collection.document()
                    sessionToSave.id = docRef.documentID
                    try docRef.setData(from: sessionToSave)
                }
                // Optimistically update local state & disk cache
                upsertLocalSession(sessionToSave)
            } catch {
                alerts.report(failure: "Failed to save session: \(error.localizedDescription)")
            }
        } else {
            // Offline / Local Mode
            if sessionToSave.id == nil || sessionToSave.id?.isEmpty == true {
                sessionToSave.id = UUID().uuidString
            }
            upsertLocalSession(sessionToSave)
        }
    }

    func deleteSession(_ session: ChargingSession) {
        guard let id = session.id else { return }
        
        // Remove locally immediately
        sessions.removeAll { $0.id == id }
        persistLocalSessions()
        
        // Remove from cloud if signed in
        if let userID {
            sessionsCollection(for: userID).document(id).delete { [weak self] error in
                if let error {
                    self?.alerts.report(failure: "Failed to delete session from cloud: \(error.localizedDescription)")
                }
            }
        }
    }

    private func upsertLocalSession(_ session: ChargingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        sessions.sort { $0.date > $1.date }
        persistLocalSessions()
    }

    // MARK: - CSV Import

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

    func importSessions(_ importedSessions: [ChargingSession], skippedRows: Int = 0) {
        guard !importedSessions.isEmpty else { return }

        if let userID {
            // Cloud batch import
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
        } else {
            // Local-only import
            var addedCount = 0
            for session in importedSessions {
                var newSession = session
                if newSession.id == nil || newSession.id?.isEmpty == true {
                    newSession.id = UUID().uuidString
                }
                upsertLocalSession(newSession)
                addedCount += 1
            }
            
            alerts.report(AppAlert(
                title: "Import Complete",
                message: Self.importSummary(written: addedCount, skipped: skippedRows, encodingFailures: 0)
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

    // MARK: - Batched Writes

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

    // MARK: - Legacy Migration

    private func migrateLegacySessionsIfNeeded(userID: String) {
        let marker = db.collection("users").document(userID)
        marker.getDocument { [weak self] snapshot, _ in
            guard let self else { return }
            guard snapshot?.get("legacySessionsMigrated") as? Bool != true else { return }
            self.copyLegacySessions(to: userID, marker: marker)
        }
    }

    private func copyLegacySessions(to userID: String, marker: DocumentReference) {
        legacySessionsCollection.getDocuments { [weak self] legacySnapshot, error in
            guard let self else { return }
            if error != nil { return }

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
                        message: "Moved \(written) \(written == 1 ? "session" : "sessions") into your account. The originals were left untouched."
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
