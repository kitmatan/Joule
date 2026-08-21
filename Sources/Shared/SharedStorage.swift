import Foundation

/// The App Group container that the app, the widgets, and the watch app read and write.
///
/// Each device keeps its own container: the phone writes what it computes, and the watch writes
/// whatever arrived over `WCSession`. The identifier is deliberately the same on both so the
/// widget code does not need to know which device it is running on.
enum SharedStorage {
    static let appGroupID = "group.com.kmatan.ChargeLog"

    /// Deep link host used by widget taps. Handled in `JouleApp`.
    static let urlScheme = "joule"

    private static let snapshotFilename = "snapshot.json"

    /// `nil` when the App Group entitlement is missing or not yet provisioned. Callers degrade to
    /// the empty snapshot rather than trapping — a widget with no data is better than a crash loop.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFilename)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Snapshot I/O

    /// Returns the published snapshot, or `nil` if nothing has been written, the payload is
    /// unreadable, or it came from an incompatible build.
    static func loadSnapshot() -> JouleSnapshot? {
        guard let snapshotURL, let data = try? Data(contentsOf: snapshotURL) else { return nil }
        guard let snapshot = try? decoder.decode(JouleSnapshot.self, from: data) else { return nil }
        guard snapshot.version == JouleSnapshot.currentVersion else { return nil }
        return snapshot
    }

    /// Writes the snapshot for the widgets on this device. Returns whether it landed, so the
    /// caller can skip the widget reload when there was nothing to reload.
    @discardableResult
    static func save(_ snapshot: JouleSnapshot) -> Bool {
        guard let snapshotURL, let data = try? encoder.encode(snapshot) else { return false }
        do {
            try data.write(to: snapshotURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Transport encoding

    /// Encodes for `WCSession`, which takes plain dictionaries rather than `Codable` values.
    static func encodeForTransfer(_ snapshot: JouleSnapshot) -> [String: Any]? {
        guard let data = try? encoder.encode(snapshot) else { return nil }
        return [transferKey: data]
    }

    static func decodeFromTransfer(_ payload: [String: Any]) -> JouleSnapshot? {
        guard let data = payload[transferKey] as? Data else { return nil }
        return try? decoder.decode(JouleSnapshot.self, from: data)
    }

    private static let transferKey = "snapshot"

    /// Message key the watch uses to pull a fresh snapshot from the phone on demand.
    static let refreshRequestKey = "requestSnapshot"
}
