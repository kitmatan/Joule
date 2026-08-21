import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: JouleSnapshot

    /// True when the App Group holds no snapshot — either the app has never run, or the
    /// entitlement is missing. Widgets show an invitation to open the app rather than zeros,
    /// which would read as "you spent nothing" instead of "there is nothing here yet".
    let isUnconfigured: Bool
}

/// Supplies every Joule widget on both platforms.
///
/// The heavy lifting already happened in the app: this only reads a file. That is deliberate —
/// widget extensions run under a tight memory ceiling and are killed without ceremony when they
/// exceed it, so recomputing battery-health regressions here would be a reliability problem, not
/// just a slow one.
struct SnapshotTimelineProvider: TimelineProvider {
    /// The clock-driven refresh. Nothing in the snapshot changes on its own, but the relative
    /// timestamps ("2h ago") go stale, so the timeline is re-rendered hourly. Genuine data changes
    /// arrive out-of-band via `WidgetCenter.reloadAllTimelines()`.
    private static let refreshInterval: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder, isUnconfigured: false)
    }

    /// Drives the widget gallery preview, where real data would be arbitrary and often empty.
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(SnapshotEntry(date: Date(), snapshot: .placeholder, isUnconfigured: false))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Date().addingTimeInterval(Self.refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> SnapshotEntry {
        guard let snapshot = SharedStorage.loadSnapshot() else {
            return SnapshotEntry(date: Date(), snapshot: .empty, isUnconfigured: true)
        }
        return SnapshotEntry(date: Date(), snapshot: snapshot, isUnconfigured: false)
    }
}
