import WidgetKit
import SwiftUI

@main
struct JouleWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        JouleWatchOverviewComplication()
        JouleWatchBatteryComplication()
    }
}

/// Spend complication. The accessory views are shared with the iPhone Lock Screen — same
/// families, same rendering modes — so only the family list and the descriptions differ.
struct JouleWatchOverviewComplication: Widget {
    static let kind = "JouleWatchOverviewComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotTimelineProvider()) { entry in
            JouleWatchOverviewView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Charging Spend")
        .description("This month's charging cost and energy.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct JouleWatchOverviewView: View {
    let entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryOverviewRectangularView(snapshot: entry.snapshot, isUnconfigured: entry.isUnconfigured)
        case .accessoryInline:
            AccessoryOverviewInlineView(snapshot: entry.snapshot)
        case .accessoryCorner:
            AccessoryHealthCornerView(snapshot: entry.snapshot)
        default:
            AccessorySpendCircularView(snapshot: entry.snapshot)
        }
    }
}

/// Battery health complication.
struct JouleWatchBatteryComplication: Widget {
    static let kind = "JouleWatchBatteryComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotTimelineProvider()) { entry in
            JouleWatchBatteryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Battery Health")
        .description("Estimated State of Health for your EV.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct JouleWatchBatteryView: View {
    let entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryHealthRectangularView(snapshot: entry.snapshot)
        case .accessoryCorner:
            AccessoryHealthCornerView(snapshot: entry.snapshot)
        default:
            AccessoryHealthCircularView(snapshot: entry.snapshot)
        }
    }
}
