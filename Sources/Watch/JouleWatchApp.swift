import SwiftUI

@main
struct JouleWatchApp: App {
    @StateObject private var store = WatchSnapshotStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .task { store.activate() }
        }
    }
}

/// Vertical paging is the watchOS idiom for a handful of peer screens: it keeps every page one
/// crown turn away, with no chrome spent on navigation.
struct WatchRootView: View {
    @EnvironmentObject private var store: WatchSnapshotStore

    var body: some View {
        if let snapshot = store.snapshot, !snapshot.isEmpty {
            TabView {
                WatchOverviewView(snapshot: snapshot)
                WatchBatteryView(snapshot: snapshot)
                WatchSessionsView(snapshot: snapshot)
            }
            .tabViewStyle(.verticalPage)
        } else {
            WatchEmptyView()
        }
    }
}

/// Shown until the phone has delivered something. The distinction matters: an empty watch app
/// usually means the phone hasn't synced yet, not that the user has never logged a charge.
struct WatchEmptyView: View {
    @EnvironmentObject private var store: WatchSnapshotStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(WatchTheme.brandGradient)

                Text("No Data Yet")
                    .font(.headline)

                Text(store.lastRefreshFailed
                     ? "Couldn't reach your iPhone. Open Joule on your iPhone and try again."
                     : "Open Joule on your iPhone to sync your charging history.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
    }
}
