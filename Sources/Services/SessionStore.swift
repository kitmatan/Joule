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
    @Published var vehicles: [Vehicle] = []
    @Published var selectedVehicleId: String? = nil
    @Published private(set) var syncStatus: SyncStatus = .localOnly

    private let alerts: AlertCenter
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var vehicleListenerRegistration: ListenerRegistration?
    private(set) var userID: String?

    init(alerts: AlertCenter) {
        self.alerts = alerts
        // Synchronously load from local storage so UI renders instantly on startup.
        let localSessions = loadLocalSessions()
        self.sessions = localSessions
        
        let localVehicles = loadLocalVehicles()
        self.vehicles = localVehicles
        
        let savedActiveId = UserDefaults.standard.string(forKey: "active_vehicle_id")
        if let savedActiveId, localVehicles.contains(where: { $0.id == savedActiveId }) {
            self.selectedVehicleId = savedActiveId
        } else {
            self.selectedVehicleId = localVehicles.first(where: { $0.isDefault })?.id ?? localVehicles.first?.id
        }
        
        self.syncStatus = .localOnly
    }

    deinit {
        listenerRegistration?.remove()
        vehicleListenerRegistration?.remove()
    }

    // MARK: - Active & Default Vehicle Resolution

    var activeVehicle: Vehicle {
        if let selectedVehicleId, let vehicle = vehicles.first(where: { $0.id == selectedVehicleId }) {
            return vehicle
        }
        return vehicles.first(where: { $0.isDefault }) ?? vehicles.first ?? Vehicle.createDefaultFromLegacy()
    }
    
    var defaultVehicle: Vehicle {
        vehicles.first(where: { $0.isDefault }) ?? vehicles.first ?? Vehicle.createDefaultFromLegacy()
    }
    
    func vehicle(for id: String?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first(where: { $0.id == id })
    }
    
    func vehicleName(for id: String?) -> String {
        guard let id, let vehicle = vehicle(for: id) else {
            return activeVehicle.name
        }
        return vehicle.name
    }
    
    /// Returns sessions filtered for a specific vehicle or all sessions if vehicleId is nil.
    func sessions(for vehicleId: String?) -> [ChargingSession] {
        guard let vehicleId else { return sessions }
        let defaultId = defaultVehicle.id
        return sessions.filter { session in
            if let sid = session.vehicleId, !sid.isEmpty {
                return sid == vehicleId
            }
            // Legacy / unassigned sessions belong to the primary default vehicle
            return vehicleId == defaultId || vehicles.count <= 1
        }
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

    private var localStorageVehiclesURL: URL {
        let fileManager = FileManager.default
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL.documentsDirectory
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("joule_vehicles.json")
    }

    private func loadLocalSessions() -> [ChargingSession] {
        guard FileManager.default.fileExists(atPath: localStorageURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: localStorageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([ChargingSession].self, from: data)
            let (unique, _) = Self.findDuplicates(in: decoded)
            return unique
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

    private func loadLocalVehicles() -> [Vehicle] {
        guard FileManager.default.fileExists(atPath: localStorageVehiclesURL.path) else {
            let initial = Vehicle.createDefaultFromLegacy()
            persistVehicles([initial])
            return [initial]
        }
        do {
            let data = try Data(contentsOf: localStorageVehiclesURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([Vehicle].self, from: data)
            if decoded.isEmpty {
                let initial = Vehicle.createDefaultFromLegacy()
                persistVehicles([initial])
                return [initial]
            }
            return decoded
        } catch {
            print("Failed to load local vehicles: \(error)")
            let initial = Vehicle.createDefaultFromLegacy()
            persistVehicles([initial])
            return [initial]
        }
    }

    private func persistLocalVehicles() {
        persistVehicles(vehicles)
    }

    private func persistVehicles(_ list: [Vehicle]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(list)
            try data.write(to: localStorageVehiclesURL, options: .atomic)
        } catch {
            print("Failed to save local vehicles: \(error)")
        }
    }

    // MARK: - Vehicle Management & CRUD

    func addVehicle(_ vehicle: Vehicle, setAsActive: Bool = true) {
        var newVehicle = vehicle
        if vehicles.isEmpty {
            newVehicle.isDefault = true
        } else if newVehicle.isDefault {
            for i in 0..<vehicles.count {
                vehicles[i].isDefault = false
            }
        }
        vehicles.append(newVehicle)
        persistLocalVehicles()
        
        if setAsActive {
            selectVehicle(id: newVehicle.id)
        }
        
        if let userID {
            try? vehiclesCollection(for: userID).document(newVehicle.id).setData(from: newVehicle)
        }
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else {
            addVehicle(vehicle)
            return
        }
        
        if vehicle.isDefault {
            for i in 0..<vehicles.count {
                if vehicles[i].id != vehicle.id {
                    vehicles[i].isDefault = false
                }
            }
        }
        
        vehicles[index] = vehicle
        persistLocalVehicles()
        
        if let userID {
            try? vehiclesCollection(for: userID).document(vehicle.id).setData(from: vehicle)
        }
    }

    func setDefaultVehicle(_ vehicle: Vehicle) {
        for i in 0..<vehicles.count {
            vehicles[i].isDefault = (vehicles[i].id == vehicle.id)
            if let userID {
                try? vehiclesCollection(for: userID).document(vehicles[i].id).setData(from: vehicles[i])
            }
        }
        persistLocalVehicles()
    }

    func deleteVehicle(_ vehicle: Vehicle, reassignSessionsTo replacementId: String? = nil) {
        guard vehicles.count > 1 else {
            alerts.report(AppAlert(title: "Cannot Delete Vehicle", message: "Your garage must have at least one vehicle profile."))
            return
        }
        
        let targetReassignId = replacementId ?? vehicles.first(where: { $0.id != vehicle.id })?.id
        
        // Reassign sessions
        var sessionsModified = false
        for i in 0..<sessions.count {
            if sessions[i].vehicleId == vehicle.id {
                sessions[i].vehicleId = targetReassignId
                sessionsModified = true
                if let userID, let docId = sessions[i].id {
                    try? sessionsCollection(for: userID).document(docId).setData(from: sessions[i])
                }
            }
        }
        if sessionsModified {
            persistLocalSessions()
        }
        
        // Remove vehicle
        vehicles.removeAll { $0.id == vehicle.id }
        
        // Ensure one vehicle remains default
        if !vehicles.contains(where: { $0.isDefault }) {
            vehicles[0].isDefault = true
            if let userID {
                try? vehiclesCollection(for: userID).document(vehicles[0].id).setData(from: vehicles[0])
            }
        }
        
        if selectedVehicleId == vehicle.id {
            selectedVehicleId = vehicles.first(where: { $0.isDefault })?.id ?? vehicles.first?.id
            UserDefaults.standard.set(selectedVehicleId, forKey: "active_vehicle_id")
        }
        
        persistLocalVehicles()
        
        if let userID {
            vehiclesCollection(for: userID).document(vehicle.id).delete()
        }
    }

    func selectVehicle(id: String?) {
        selectedVehicleId = id
        UserDefaults.standard.set(id, forKey: "active_vehicle_id")
    }

    // MARK: - Deduplication

    /// Scans a list of sessions, identifying duplicates and preserving the richest record for each unique event.
    static func findDuplicates(in sessions: [ChargingSession]) -> (unique: [ChargingSession], duplicatesToRemove: [ChargingSession]) {
        var unique: [ChargingSession] = []
        var duplicates: [ChargingSession] = []

        // Sort by date descending
        let sorted = sessions.sorted { $0.date > $1.date }

        for session in sorted {
            if let existingIndex = unique.firstIndex(where: { $0.isDuplicate(of: session) }) {
                // Merge info into the existing unique session to retain the best metadata
                unique[existingIndex] = unique[existingIndex].merged(with: session)
                duplicates.append(session)
            } else {
                unique.append(session)
            }
        }

        return (unique, duplicates)
    }

    /// Total count of detected duplicate sessions in the current session list.
    var duplicateSessionsCount: Int {
        let (_, duplicates) = Self.findDuplicates(in: sessions)
        return duplicates.count
    }

    /// Scans current sessions, merges metadata into canonical records, and removes duplicate records from memory, local storage, and Firestore.
    func cleanDuplicates(completion: ((_ removedCount: Int) -> Void)? = nil) {
        let (uniqueSessions, duplicates) = Self.findDuplicates(in: self.sessions)
        guard !duplicates.isEmpty else {
            alerts.report(AppAlert(title: "No Duplicates Found", message: "Your charging history contains no duplicate records."))
            completion?(0)
            return
        }

        let removedCount = duplicates.count
        self.sessions = uniqueSessions
        self.persistLocalSessions()

        if let userID {
            let collection = sessionsCollection(for: userID)
            let group = DispatchGroup()

            // Update any merged unique sessions that may have been enriched
            let pendingUpdates: [(DocumentReference, ChargingSession)] = uniqueSessions.compactMap { session in
                guard let id = session.id, !id.isEmpty else { return nil }
                return (collection.document(id), session)
            }
            if !pendingUpdates.isEmpty {
                write(pendingUpdates) { _, _, _ in }
            }

            // Delete duplicates from Firestore (only if their ID is not retained as a unique session's ID)
            let uniqueIDs = Set(uniqueSessions.compactMap(\.id))
            for dup in duplicates {
                if let dupId = dup.id, !dupId.isEmpty, !uniqueIDs.contains(dupId) {
                    group.enter()
                    collection.document(dupId).delete { _ in
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                self.alerts.report(AppAlert(
                    title: "Deduplication Complete",
                    message: "Cleaned up \(removedCount) duplicate \(removedCount == 1 ? "record" : "records")."
                ))
                completion?(removedCount)
            }
        } else {
            alerts.report(AppAlert(
                title: "Deduplication Complete",
                message: "Cleaned up \(removedCount) duplicate \(removedCount == 1 ? "record" : "records")."
            ))
            completion?(removedCount)
        }
    }

    // MARK: - Paths

    /// Every session lives under its owner, so the security rules can scope access by UID.
    private func sessionsCollection(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("sessions")
    }

    private func vehiclesCollection(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("vehicles")
    }

    /// The flat, pre-auth collection. Read once per user by the migration below, never written.
    private var legacySessionsCollection: CollectionReference {
        db.collection("sessions")
    }

    // MARK: - Connection & Cloud Sync

    /// Binds the store to a signed-in user and synchronizes local and cloud sessions and vehicles.
    func connect(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        self.syncStatus = .syncing
        
        startListening(userID: userID)
        startListeningVehicles(userID: userID)
        syncLocalSessionsToCloud(userID: userID)
        syncLocalVehiclesToCloud(userID: userID)
        migrateLegacySessionsIfNeeded(userID: userID)
    }

    func disconnect(clearLocalData: Bool = false) {
        userID = nil
        listenerRegistration?.remove()
        listenerRegistration = nil
        vehicleListenerRegistration?.remove()
        vehicleListenerRegistration = nil
        syncStatus = .localOnly
        
        if clearLocalData {
            sessions = []
            try? FileManager.default.removeItem(at: localStorageURL)
            try? FileManager.default.removeItem(at: localStorageVehiclesURL)
            let defaultV = Vehicle.createDefaultFromLegacy()
            vehicles = [defaultV]
            selectedVehicleId = defaultV.id
        }
    }

    func forceSync() {
        guard let userID else {
            syncStatus = .localOnly
            return
        }
        syncStatus = .syncing
        
        // Sync vehicles
        vehiclesCollection(for: userID)
            .getDocuments { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents, !docs.isEmpty else { return }
                let cloudVehicles = docs.compactMap { try? $0.data(as: Vehicle.self) }
                if !cloudVehicles.isEmpty {
                    self.vehicles = cloudVehicles
                    self.persistLocalVehicles()
                }
            }
        
        // Sync sessions
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
                let (uniqueRemote, _) = Self.findDuplicates(in: remoteSessions)
                self.sessions = uniqueRemote
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
                let (uniqueCloudSessions, _) = Self.findDuplicates(in: cloudSessions)
                
                self.sessions = uniqueCloudSessions
                self.persistLocalSessions()
                self.syncStatus = .synced(lastSync: Date())
            }
    }

    private func startListeningVehicles(userID: String) {
        vehicleListenerRegistration?.remove()
        vehicleListenerRegistration = vehiclesCollection(for: userID)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self else { return }
                guard self.userID == userID else { return }

                if let error {
                    print("Failed to load cloud vehicles: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    // If cloud vehicles are empty, upload local vehicles
                    self.syncLocalVehiclesToCloud(userID: userID)
                    return
                }

                let cloudVehicles = documents.compactMap { document -> Vehicle? in
                    try? document.data(as: Vehicle.self)
                }
                if !cloudVehicles.isEmpty {
                    self.vehicles = cloudVehicles
                    if self.selectedVehicleId == nil || !cloudVehicles.contains(where: { $0.id == self.selectedVehicleId }) {
                        self.selectedVehicleId = cloudVehicles.first(where: { $0.isDefault })?.id ?? cloudVehicles.first?.id
                    }
                    self.persistLocalVehicles()
                }
            }
    }

    private func syncLocalVehiclesToCloud(userID: String) {
        let localVehicles = self.vehicles
        guard !localVehicles.isEmpty else { return }

        let collection = vehiclesCollection(for: userID)
        collection.getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                print("Could not query existing cloud vehicles: \(error)")
                return
            }

            let remoteDocs = snapshot?.documents ?? []
            let remoteIDs = Set(remoteDocs.map(\.documentID))

            for vehicle in localVehicles {
                if !remoteIDs.contains(vehicle.id) {
                    try? collection.document(vehicle.id).setData(from: vehicle)
                }
            }
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
            
            let remoteDocs = snapshot?.documents ?? []
            let remoteIDs = Set(remoteDocs.map(\.documentID))
            let remoteSessions = remoteDocs.compactMap { try? $0.data(as: ChargingSession.self) }

            let pendingUploads: [(DocumentReference, ChargingSession)] = localSessions.compactMap { session in
                // Skip if already in cloud by ID
                if let id = session.id, remoteIDs.contains(id) {
                    return nil
                }
                // Skip if semantically duplicate with an existing remote session
                if remoteSessions.contains(where: { $0.isDuplicate(of: session) }) {
                    return nil
                }

                let docRef = (session.id != nil && !session.id!.isEmpty) ? collection.document(session.id!) : collection.document()
                var updated = session
                updated.id = docRef.documentID
                if updated.vehicleId == nil || updated.vehicleId?.isEmpty == true {
                    updated.vehicleId = self.activeVehicle.id
                }
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
        if sessionToSave.vehicleId == nil || sessionToSave.vehicleId?.isEmpty == true {
            sessionToSave.vehicleId = activeVehicle.id
        }
        
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

        let defaultVehId = defaultVehicle.id
        let activeVehId = selectedVehicleId ?? defaultVehId

        // Filter duplicates against existing sessions and within the import batch itself
        var nonDuplicateSessions: [ChargingSession] = []
        var duplicateCount = 0

        for var session in importedSessions {
            if let rawVid = session.vehicleId, !rawVid.isEmpty {
                if let matched = self.vehicles.first(where: { $0.id == rawVid || $0.name.localizedCaseInsensitiveCompare(rawVid) == .orderedSame }) {
                    session.vehicleId = matched.id
                } else if self.vehicles.count == 1 {
                    session.vehicleId = defaultVehId
                }
            } else {
                session.vehicleId = activeVehId
            }

            let isDupOfExisting = self.sessions.contains(where: { $0.isDuplicate(of: session) })
            let isDupOfBatch = nonDuplicateSessions.contains(where: { $0.isDuplicate(of: session) })

            if isDupOfExisting || isDupOfBatch {
                duplicateCount += 1
            } else {
                nonDuplicateSessions.append(session)
            }
        }

        guard !nonDuplicateSessions.isEmpty else {
            alerts.report(AppAlert(
                title: "Import Complete",
                message: Self.importSummary(written: 0, skipped: skippedRows, duplicates: duplicateCount, encodingFailures: 0)
            ))
            return
        }

        if let userID {
            // Cloud batch import
            let collection = sessionsCollection(for: userID)
            var documents: [(DocumentReference, ChargingSession)] = []
            for session in nonDuplicateSessions {
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
                    message: Self.importSummary(written: written, skipped: skippedRows, duplicates: duplicateCount, encodingFailures: encodingFailures)
                ))
            }
        } else {
            // Local-only import
            var addedCount = 0
            for session in nonDuplicateSessions {
                var newSession = session
                if newSession.id == nil || newSession.id?.isEmpty == true {
                    newSession.id = UUID().uuidString
                }
                upsertLocalSession(newSession)
                addedCount += 1
            }
            
            alerts.report(AppAlert(
                title: "Import Complete",
                message: Self.importSummary(written: addedCount, skipped: skippedRows, duplicates: duplicateCount, encodingFailures: 0)
            ))
        }
    }

    private static func importSummary(written: Int, skipped: Int, duplicates: Int = 0, encodingFailures: Int = 0) -> String {
        var parts = ["Imported \(written) \(written == 1 ? "session" : "sessions")."]
        if duplicates > 0 {
            parts.append("\(duplicates) duplicate \(duplicates == 1 ? "session was" : "sessions were") skipped.")
        }
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
