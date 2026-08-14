import SwiftUI
import Charts

struct MonthlyStat: Identifiable {
    let month: Date
    var cost: Double = 0
    var acEnergy: Double = 0
    var dcEnergy: Double = 0
    /// Sessions saved before the type was recorded, or imported from a file without the column.
    /// Kept apart rather than folded into DC so the chart never asserts a type the data lacks.
    var untypedEnergy: Double = 0

    var id: Date { month }
}

struct LocationStat: Identifiable {
    let name: String
    let sessionCount: Int
    let totalCost: Double
    let totalEnergy: Double

    var id: String { name }
    var pricePerKWh: Double { totalEnergy > 0 ? totalCost / totalEnergy : 0 }
}

struct DashboardView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Wide layout on Mac and iPad (regular width); compact two-column layout on iPhone.
    private var isWide: Bool { horizontalSizeClass == .regular }

    private var statColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        if isWide {
            return [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    // MARK: - Computed Properties (Totals)
    var totalSessions: Int { store.sessions.count }

    var totalCost: Double {
        store.sessions.reduce(0) { $0 + $1.totalPrice }
    }

    var totalEnergy: Double {
        store.sessions.reduce(0) { $0 + $1.energyAdded }
    }

    /// Odometer span, together with the energy and cost that actually powered it.
    var drivingWindow: (distance: Double, energy: Double, cost: Double)? {
        let logged = store.sessions
            .filter { $0.mileage != nil }
            .sorted { $0.date < $1.date }

        guard let firstLogged = logged.first, let lastLogged = logged.last else { return nil }

        let odometers = logged.compactMap(\.mileage)
        guard let startOdo = odometers.min(), let endOdo = odometers.max(), endOdo > startOdo else { return nil }

        let powering = store.sessions.filter { $0.date >= firstLogged.date && $0.date < lastLogged.date }
        return (
            distance: endOdo - startOdo,
            energy: powering.reduce(0) { $0 + $1.energyAdded },
            cost: powering.reduce(0) { $0 + $1.totalPrice }
        )
    }

    var hasDrivingData: Bool { drivingWindow != nil }

    var totalDistance: Double { drivingWindow?.distance ?? 0 }

    // MARK: - Computed Properties (Monthly)
    var uniqueMonthsCount: Int {
        let uniqueMonths = Set(store.sessions.map {
            Calendar.current.dateComponents([.year, .month], from: $0.date)
        })
        return max(1, uniqueMonths.count)
    }

    var currentMonthSessions: [ChargingSession] {
        store.sessions.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }
    }

    var currentMonthCost: Double {
        currentMonthSessions.reduce(0) { $0 + $1.totalPrice }
    }

    var currentMonthEnergy: Double {
        currentMonthSessions.reduce(0) { $0 + $1.energyAdded }
    }

    var currentMonthDeferredCost: Double {
        currentMonthSessions
            .filter { $0.paymentStatus == .deferred }
            .reduce(0) { $0 + $1.totalPrice }
    }

    // MARK: - Computed Properties (Averages)
    var averagePricePerKWh: Double {
        totalEnergy > 0 ? totalCost / totalEnergy : 0
    }

    var energyEfficiency: Double {
        guard let window = drivingWindow, window.energy > 0 else { return 0 }
        return window.distance / window.energy
    }

    var costPerKm: Double {
        guard let window = drivingWindow, window.distance > 0 else { return 0 }
        return window.cost / window.distance
    }

    var averageSpeed: Double {
        let speeds = store.sessions.map(\.speed).filter { $0 > 0 }
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    // MARK: - Chart Data
    /// Sessions aggregated per calendar month over the last 12 months.
    var monthlyStats: [MonthlyStat] {
        let calendar = Calendar.current
        let thisMonth = calendar.startOfMonth(for: Date())
        guard let cutoff = calendar.date(byAdding: .month, value: -11, to: thisMonth) else {
            return []
        }

        var byMonth: [Date: MonthlyStat] = [:]
        for offset in 0...11 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: cutoff) else { continue }
            byMonth[month] = MonthlyStat(month: month)
        }

        for session in store.sessions where session.date >= cutoff {
            let month = calendar.startOfMonth(for: session.date)
            var stat = byMonth[month] ?? MonthlyStat(month: month)
            stat.cost += session.totalPrice
            switch session.chargingType {
            case .ac: stat.acEnergy += session.energyAdded
            case .dc: stat.dcEnergy += session.energyAdded
            case nil: stat.untypedEnergy += session.energyAdded
            }
            byMonth[month] = stat
        }
        return byMonth.values.sorted { $0.month < $1.month }
    }

    var showsUntypedEnergy: Bool {
        monthlyStats.contains { $0.untypedEnergy > 0 }
    }

    var recentSpeedSessions: [ChargingSession] {
        Array(store.sessions.filter { $0.speed > 0 }.prefix(15)).reversed()
    }

    var topLocations: [LocationStat] {
        let grouped = Dictionary(grouping: store.sessions) { session in
            session.locationName?.isEmpty == false ? session.locationName! : "Unknown Location"
        }
        return grouped
            .map { name, sessions in
                LocationStat(
                    name: name,
                    sessionCount: sessions.count,
                    totalCost: sessions.reduce(0) { $0 + $1.totalPrice },
                    totalEnergy: sessions.reduce(0) { $0 + $1.energyAdded }
                )
            }
            .sorted { $0.sessionCount > $1.sessionCount }
            .prefix(3)
            .map { $0 }
    }

    @State private var showingSettings = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if store.sessions.isEmpty {
                        ContentUnavailableView(
                            "No Charging Data",
                            systemImage: "bolt.car",
                            description: Text("Log your first charging session in History or Import CSV to view your analytics.")
                        )
                        .padding(.top, 40)
                    } else {
                        monthlySection
                        if currentMonthDeferredCost > 0 {
                            pendingBillCard
                        }
                        batteryHealthPreviewSection
                        lifetimeTotalsSection
                        averagesSection
                        chartsSection
                        if !topLocations.isEmpty {
                            topLocationsSection
                        }
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: isWide ? 1100 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Battery Health Preview
    private var batteryHealthSummary: BatteryHealthSummary? {
        BatteryHealthService().calculateSummary(from: store.sessions)
    }

    @ViewBuilder
    private var batteryHealthPreviewSection: some View {
        if let health = batteryHealthSummary {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Battery Health")
                        .font(.title2).bold()
                    Spacer()
                    NavigationLink {
                        BatteryHealthView()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Details")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                NavigationLink {
                    BatteryHealthView()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "bolt.batteryblock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(health.currentSoH >= 90 ? .green : .orange)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(String(format: "%.1f%% SoH", health.currentSoH))
                                    .font(.title3).bold()
                                    .foregroundColor(.primary)

                                Text(health.assessment.title)
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((health.currentSoH >= 90 ? Color.green : Color.orange).opacity(0.15))
                                    .foregroundColor(health.currentSoH >= 90 ? .green : .orange)
                                    .clipShape(Capsule())
                            }

                            Text(String(format: "%.1f / %.1f kWh usable • %.1f full cycles", health.currentCapacityKWh, health.nominalCapacityKWh, health.equivalentFullCycles))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Battery Health: \(String(format: "%.1f%%", health.currentSoH)) State of Health, \(health.assessment.title)")
                .accessibilityValue("\(String(format: "%.1f", health.currentCapacityKWh)) usable of \(String(format: "%.1f", health.nominalCapacityKWh)) kWh nominal, \(String(format: "%.1f", health.equivalentFullCycles)) full cycles")
                .accessibilityHint("Double tap to open detailed battery health analytics")
            }
        }
    }

    // MARK: - Sections
    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Stats")
                .font(.title2).bold()
                .padding(.horizontal)

            LazyVGrid(columns: statColumns, spacing: 16) {
                StatCard(title: "Cost This Month", value: currentMonthCost.formatted(.currency(code: "THB").presentation(.narrow)), icon: "creditcard.fill", color: .green)
                StatCard(title: "Energy This Month", value: String(format: "%.1f kWh", currentMonthEnergy), icon: "bolt.batteryblock.fill", color: .blue)
                StatCard(title: "Avg Monthly Cost", value: (totalCost / Double(uniqueMonthsCount)).formatted(.currency(code: "THB").presentation(.narrow)), icon: "calendar.badge.clock", color: .green)
                StatCard(title: "Avg Monthly Energy", value: String(format: "%.1f kWh", totalEnergy / Double(uniqueMonthsCount)), icon: "bolt.fill", color: .blue)
            }
            .padding(.horizontal)
        }
    }

    private var pendingBillCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait.fill")
                .font(.title2)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Deferred to Bill This Month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(currentMonthDeferredCost.formatted(.currency(code: "THB").presentation(.narrow)))
                    .font(.title3).bold()
                    .foregroundColor(.orange)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deferred to Electric Bill This Month")
        .accessibilityValue(currentMonthDeferredCost.formatted(.currency(code: "THB").presentation(.narrow)))
    }

    private var lifetimeTotalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Totals")
                .font(.title2).bold()
                .padding(.horizontal)

            LazyVGrid(columns: statColumns, spacing: 16) {
                StatCard(title: "Total Spent", value: totalCost.formatted(.currency(code: "THB").presentation(.narrow)), icon: "banknote.fill", color: .green)
                StatCard(title: "Total Energy", value: String(format: "%.1f kWh", totalEnergy), icon: "bolt.fill", color: .blue)
                StatCard(title: "Distance", value: hasDrivingData ? String(format: "%.0f km", totalDistance) : "N/A", icon: "car.fill", color: .purple)
                StatCard(title: "Sessions", value: "\(totalSessions)", icon: "ev.charger.fill", color: .orange)
            }
            .padding(.horizontal)
        }
    }

    private var averagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Averages & Efficiency")
                .font(.title2).bold()
                .padding(.horizontal)

            LazyVGrid(columns: statColumns, spacing: 16) {
                StatCard(title: "Cost Efficiency", value: String(format: "฿%.2f/kWh", averagePricePerKWh), icon: "tag.fill", color: .orange)
                StatCard(title: "Driving Eff.", value: hasDrivingData ? String(format: "%.1f km/kWh", energyEfficiency) : "N/A", icon: "leaf.fill", color: .mint)
                StatCard(title: "Driving Cost", value: hasDrivingData ? String(format: "฿%.2f/km", costPerKm) : "N/A", icon: "road.lanes", color: .gray)
                StatCard(title: "Avg Speed", value: averageSpeed > 0 ? String(format: "%.1f kW", averageSpeed) : "N/A", icon: "bolt.badge.clock.fill", color: .yellow)
            }
            .padding(.horizontal)
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trends")
                .font(.title2).bold()
                .padding(.horizontal)

            if isWide {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                    costChart
                    energyChart
                    speedChart
                }
                .padding(.horizontal)
            } else {
                costChart
                energyChart
                speedChart
            }
        }
    }

    private var costChart: some View {
        ChartCard(title: "Monthly Cost (THB)", insetsHorizontally: !isWide) {
            Chart(monthlyStats) { stat in
                BarMark(
                    x: .value("Month", stat.month, unit: .month),
                    y: .value("Cost", stat.cost)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Monthly Charging Cost Trend")
            .accessibilityValue("Total cost across last 12 months: \(totalCost.formatted(.currency(code: "THB").presentation(.narrow)))")
            .accessibilityHint("Shows monthly charging cost trends in Thai Baht over the past year")
        }
    }

    private var energyChart: some View {
        ChartCard(title: "Monthly Energy by Type (kWh)", insetsHorizontally: !isWide) {
            Chart(monthlyStats) { stat in
                BarMark(
                    x: .value("Month", stat.month, unit: .month),
                    y: .value("kWh", stat.acEnergy)
                )
                .foregroundStyle(by: .value("Type", "AC"))
                .cornerRadius(4)

                BarMark(
                    x: .value("Month", stat.month, unit: .month),
                    y: .value("kWh", stat.dcEnergy)
                )
                .foregroundStyle(by: .value("Type", "DC"))
                .cornerRadius(4)

                if showsUntypedEnergy {
                    BarMark(
                        x: .value("Month", stat.month, unit: .month),
                        y: .value("kWh", stat.untypedEnergy)
                    )
                    .foregroundStyle(by: .value("Type", "Unspecified"))
                    .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(
                domain: showsUntypedEnergy ? ["AC", "DC", "Unspecified"] : ["AC", "DC"],
                range: showsUntypedEnergy ? [Color.blue, .orange, .gray] : [Color.blue, .orange]
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Monthly Energy Breakdown by Charging Type")
            .accessibilityValue("Total energy \(String(format: "%.1f kWh", totalEnergy)) across AC and DC charging")
            .accessibilityHint("Stacked bar chart showing monthly kilowatt-hours consumed")
        }
    }

    private var speedChart: some View {
        ChartCard(title: "Charging Speed — Recent Sessions (kW)", insetsHorizontally: !isWide) {
            Chart(recentSpeedSessions) { session in
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Speed", session.speed)
                )
                .symbol(Circle())
                .foregroundStyle(.orange)

                AreaMark(
                    x: .value("Date", session.date),
                    y: .value("Speed", session.speed)
                )
                .foregroundStyle(.orange.opacity(0.1))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recent Charging Speeds")
            .accessibilityValue("Average speed \(averageSpeed > 0 ? String(format: "%.1f kW", averageSpeed) : "N/A")")
            .accessibilityHint("Line chart showing power delivery rates for recent charging sessions")
        }
    }

    private var topLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Locations")
                .font(.title2).bold()
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(topLocations.enumerated()), id: \.element.id) { index, location in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(location.sessionCount) sessions • \(String(format: "%.0f kWh", location.totalEnergy))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(location.totalCost.formatted(.currency(code: "THB").presentation(.narrow)))
                                .font(.subheadline).bold()
                            if location.pricePerKWh > 0 {
                                Text(String(format: "฿%.2f/kWh", location.pricePerKWh))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(location.name), \(location.sessionCount) sessions")
                    .accessibilityValue("\(String(format: "%.0f kWh", location.totalEnergy)), total \(location.totalCost.formatted(.currency(code: "THB").presentation(.narrow)))\(location.pricePerKWh > 0 ? String(format: ", %.2f Baht per kilowatt-hour", location.pricePerKWh) : "")")
                }
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.title3)
                .bold()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    /// When the card sits directly in a scroll view it insets itself; inside a grid the grid provides the insets.
    var insetsHorizontally: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, insetsHorizontally ? 16 : 4)

            content
                .frame(minHeight: 200, idealHeight: 220)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, insetsHorizontally ? 16 : 0)
        }
    }
}
