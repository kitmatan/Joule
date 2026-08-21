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

struct DrivingEfficiencyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let distanceKm: Double
    let energyKWh: Double
    let kmPerKWh: Double
    let kwhPer100km: Double

    func value(for unitMode: EfficiencyChartUnit, unitSystem: UnitSystem) -> Double {
        switch unitMode {
        case .distancePerEnergy:
            return unitSystem.convertFromKm(kmPerKWh)
        case .consumption:
            let dist = unitSystem.convertFromKm(distanceKm)
            return dist > 0 ? (energyKWh / dist) * 100.0 : 0
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency
    @AppStorage("dashboard_efficiency_chart_unit") private var efficiencyChartUnit: EfficiencyChartUnit = .consumption
    @AppStorage("gas_baseline_preset") private var gasPreset: GasBaselinePreset = GasComparisonSettings.defaultPreset
    @AppStorage("gas_fuel_efficiency_km_per_l") private var gasEfficiencyKmPerL: Double = GasComparisonSettings.defaultEfficiencyKmPerL
    @AppStorage("gas_custom_fuel_price") private var gasFuelPrice: Double = GasComparisonSettings.defaultFuelPriceTHB

    @State private var selectedCostMonth: Date? = nil
    @State private var selectedEnergyMonth: Date? = nil
    @State private var selectedEfficiencyDate: Date? = nil

    private var selectedCostStat: MonthlyStat? {
        guard let selectedCostMonth else { return nil }
        return monthlyStats.min(by: {
            abs($0.month.timeIntervalSince(selectedCostMonth)) < abs($1.month.timeIntervalSince(selectedCostMonth))
        })
    }

    private var selectedEnergyStat: MonthlyStat? {
        guard let selectedEnergyMonth else { return nil }
        return monthlyStats.min(by: {
            abs($0.month.timeIntervalSince(selectedEnergyMonth)) < abs($1.month.timeIntervalSince(selectedEnergyMonth))
        })
    }

    private var selectedEfficiencyPoint: DrivingEfficiencyPoint? {
        guard let selectedEfficiencyDate, !drivingEfficiencyPoints.isEmpty else { return nil }
        return drivingEfficiencyPoints.min(by: {
            abs($0.date.timeIntervalSince(selectedEfficiencyDate)) < abs($1.date.timeIntervalSince(selectedEfficiencyDate))
        })
    }

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
    var displayedSessions: [ChargingSession] {
        store.sessions(for: store.selectedVehicleId)
    }

    /// The aggregates below all come from `ChargingStatistics`, which the widgets and the watch
    /// app read through as well. Keeping one implementation means the Home Screen can never
    /// disagree with the dashboard about what a month cost.
    private var stats: ChargingStatistics {
        ChargingStatistics(
            sessions: displayedSessions,
            vehicle: store.activeVehicle,
            currency: appCurrency,
            unitSystem: unitSystem
        )
    }

    var totalSessions: Int { stats.totalSessions }

    var totalCost: Double { stats.totalCost }

    var totalEnergy: Double { stats.totalEnergy }

    var drivingWindow: (distance: Double, energy: Double, cost: Double)? { stats.drivingWindow }

    var hasDrivingData: Bool { stats.hasDrivingData }

    var totalDistance: Double { stats.totalDistance }

    // MARK: - Computed Properties (Monthly)
    var uniqueMonthsCount: Int { stats.uniqueMonthsCount }

    var currentMonthSessions: [ChargingSession] { stats.currentMonthSessions }

    var currentMonthCost: Double { stats.currentMonthCost }

    var currentMonthEnergy: Double { stats.currentMonthEnergy }

    var currentMonthDeferredCost: Double { stats.currentMonthDeferredCost }

    // MARK: - Computed Properties (Averages)
    var averagePricePerKWh: Double { stats.averagePricePerKWh }

    var energyEfficiency: Double { stats.energyEfficiency }

    var costPerDistance: Double { stats.costPerDistance }

    // MARK: - Gas Comparison & Cost Savings
    var lifetimeGasSavings: GasSavingsSummary { stats.lifetimeGasSavings }

    var currentMonthGasSavings: GasSavingsSummary { stats.currentMonthGasSavings }

    // MARK: - Driving Efficiency Data
    var drivingEfficiencyPoints: [DrivingEfficiencyPoint] {
        let logged = displayedSessions
            .filter { $0.mileage != nil }
            .sorted { $0.date < $1.date }

        guard logged.count >= 2 else { return [] }

        var points: [DrivingEfficiencyPoint] = []
        for i in 1..<logged.count {
            let start = logged[i - 1]
            let end = logged[i]
            guard let startMileage = start.mileage, let endMileage = end.mileage, endMileage > startMileage else {
                continue
            }
            let distance = endMileage - startMileage
            let powering = displayedSessions.filter { $0.date >= start.date && $0.date < end.date }
            let energy = powering.reduce(0) { $0 + $1.energyAdded }
            guard energy > 0 else { continue }

            let kmPerKWh = distance / energy
            let kwhPer100km = (energy / distance) * 100.0
            points.append(DrivingEfficiencyPoint(
                date: end.date,
                distanceKm: distance,
                energyKWh: energy,
                kmPerKWh: kmPerKWh,
                kwhPer100km: kwhPer100km
            ))
        }
        return points
    }

    var averageDrivingEfficiencyForUnit: Double {
        switch efficiencyChartUnit {
        case .distancePerEnergy:
            return unitSystem.convertFromKm(energyEfficiency)
        case .consumption:
            let dist = unitSystem.convertFromKm(totalDistance)
            guard let window = drivingWindow, dist > 0 else { return 0 }
            return (window.energy / dist) * 100.0
        }
    }

    private var drivingEfficiencyDateSpanDays: Double {
        let dates = drivingEfficiencyPoints.map(\.date)
        guard let minD = dates.min(), let maxD = dates.max() else { return 0 }
        return max(1.0, maxD.timeIntervalSince(minD) / 86400.0)
    }

    private var drivingEfficiencyDateDomain: ClosedRange<Date>? {
        let dates = drivingEfficiencyPoints.map(\.date)
        guard let minD = dates.min(), let maxD = dates.max() else { return nil }
        let span = maxD.timeIntervalSince(minD)
        if span < 86400 {
            return minD.addingTimeInterval(-43200)...maxD.addingTimeInterval(43200)
        }
        let buffer = span * 0.08
        return minD.addingTimeInterval(-buffer)...maxD.addingTimeInterval(buffer)
    }

    private func formatEfficiencyDate(_ date: Date) -> String {
        if drivingEfficiencyDateSpanDays <= 90 {
            return date.formatted(.dateTime.month(.abbreviated).day())
        } else if drivingEfficiencyDateSpanDays <= 365 * 2 {
            let month = date.formatted(.dateTime.month(.abbreviated))
            let year = date.formatted(.dateTime.year(.twoDigits))
            return "\(month) '\(year)"
        } else {
            return date.formatted(.dateTime.year())
        }
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

        for session in displayedSessions where session.date >= cutoff {
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

    // MARK: - Location Stats
    var topLocations: [LocationStat] {
        let withNames = displayedSessions.compactMap { session -> (name: String, session: ChargingSession)? in
            guard let name = session.locationName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (name: name.trimmingCharacters(in: .whitespacesAndNewlines), session: session)
        }

        let grouped = Dictionary(grouping: withNames, by: { $0.name })
            .mapValues { $0.map(\.session) }

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
    @State private var showingAddSession = false
    @State private var navigateToBatteryHealth = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection

                    if displayedSessions.isEmpty {
                        ContentUnavailableView(
                            "No Charging Data",
                            systemImage: "bolt.car",
                            description: Text("Log your first charging session or import a CSV file to view your analytics.")
                        )
                        .padding(.top, 16)
                    } else {
                        monthlySection
                        if currentMonthDeferredCost > 0 {
                            pendingBillCard
                        }
                        gasSavingsSection
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
            .navigationTitle("")
            .navigationDestination(isPresented: $navigateToBatteryHealth) {
                BatteryHealthView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GarageSwitcherMenu(allowAllOption: true)
                }
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
            .sheet(isPresented: $showingAddSession) {
                AddSessionView()
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        DashboardHeroCard(
            vehicle: store.activeVehicle,
            isAllVehicles: store.selectedVehicleId == nil && store.vehicles.count > 1,
            vehicleCount: store.vehicles.count,
            sessions: displayedSessions,
            currentMonthCost: currentMonthCost,
            currentMonthEnergy: currentMonthEnergy,
            totalCost: totalCost,
            totalEnergy: totalEnergy,
            gasSavings: currentMonthGasSavings,
            lifetimeGasSavings: lifetimeGasSavings,
            batteryHealth: batteryHealthSummary,
            energyEfficiency: energyEfficiency,
            averagePricePerKWh: averagePricePerKWh,
            costPerDistance: costPerDistance,
            hasDrivingData: hasDrivingData,
            currency: appCurrency,
            unitSystem: unitSystem,
            isWide: isWide,
            onAddSession: {
                showingAddSession = true
            },
            onOpenBatteryHealth: {
                navigateToBatteryHealth = true
            }
        )
    }

    // MARK: - Battery Health Preview
    private var batteryHealthSummary: BatteryHealthSummary? {
        let targetSessions = store.sessions(for: store.activeVehicle.id)
        return BatteryHealthService(vehicle: store.activeVehicle).calculateSummary(from: targetSessions)
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
                StatCard(title: "Cost This Month", value: appCurrency.format(currentMonthCost), icon: "creditcard.fill", color: .green)
                StatCard(title: "Saved vs. Gas", value: currentMonthCost > 0 || currentMonthEnergy > 0 ? appCurrency.format(currentMonthGasSavings.netSavings) : "N/A", icon: "banknote.fill", color: .mint)
                StatCard(title: "Energy This Month", value: String(format: "%.1f kWh", currentMonthEnergy), icon: "bolt.batteryblock.fill", color: .blue)
                StatCard(title: "Avg Monthly Cost", value: appCurrency.format(totalCost / Double(uniqueMonthsCount)), icon: "calendar.badge.clock", color: .green)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Cost Savings vs. Gas Section
    @ViewBuilder
    private var gasSavingsSection: some View {
        let savings = lifetimeGasSavings
        if savings.gasCost > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cost Savings vs. Gas")
                        .font(.title2).bold()
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Baseline")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 16) {
                    // Top Hero Row: Total Savings & Percentage Badge
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Text(appCurrency.format(savings.netSavings))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)

                                if savings.savingsPercentage > 0 {
                                    Text(String(format: "%.0f%% Saved", savings.savingsPercentage))
                                        .font(.caption).bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.18))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.mint)
                                    .font(.subheadline)
                                Text(String(format: "%.0f %@", savings.fuelAvoided, savings.fuelUnit))
                                    .font(.subheadline).bold()
                                    .foregroundColor(.primary)
                            }
                            Text("Fuel Avoided")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Comparison Breakdown Grid
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("EV Spent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(appCurrency.format(savings.evCost))
                                .font(.headline)
                                .foregroundColor(.primary)
                            if savings.evCostPerDistance > 0 {
                                Text(appCurrency.formatCostPerDistance(cost: savings.evCostPerDistance, distanceUnit: unitSystem.distanceUnit))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "fuelpump.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Gas Equivalent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(appCurrency.format(savings.gasCost))
                                .font(.headline)
                                .foregroundColor(.primary)
                            if savings.gasCostPerDistance > 0 {
                                Text(appCurrency.formatCostPerDistance(cost: savings.gasCostPerDistance, distanceUnit: unitSystem.distanceUnit))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "banknote.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Per \(unitSystem.distanceUnit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(appCurrency.format(savings.costDifferencePerDistance))
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Saved/\(unitSystem.distanceUnit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Baseline info footer
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Baseline: \(gasPreset.title(for: unitSystem)) @ \(appCurrency.formatRate(GasComparisonSettings.effectiveFuelPrice(currency: appCurrency, unitSystem: unitSystem), unit: GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cost Savings vs Gas: \(appCurrency.format(savings.netSavings)) saved (\(String(format: "%.0f%%", savings.savingsPercentage))), \(String(format: "%.0f %@", savings.fuelAvoided, savings.fuelUnit)) fuel avoided")
            }
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
                Text(appCurrency.format(currentMonthDeferredCost))
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
        .accessibilityValue(appCurrency.format(currentMonthDeferredCost))
    }

    private var lifetimeTotalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Totals")
                .font(.title2).bold()
                .padding(.horizontal)

            LazyVGrid(columns: statColumns, spacing: 16) {
                StatCard(title: "Total Spent", value: appCurrency.format(totalCost), icon: "banknote.fill", color: .green)
                StatCard(title: "Total Energy", value: String(format: "%.1f kWh", totalEnergy), icon: "bolt.fill", color: .blue)
                StatCard(title: "Distance", value: hasDrivingData ? unitSystem.formatDistance(km: totalDistance) : "N/A", icon: "car.fill", color: .purple)
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
                StatCard(title: "Cost Efficiency", value: appCurrency.formatRate(averagePricePerKWh), icon: "tag.fill", color: .orange)
                StatCard(title: "Driving Eff.", value: hasDrivingData ? unitSystem.formatEfficiency(kmPerKWh: energyEfficiency) : "N/A", icon: "leaf.fill", color: .mint)
                StatCard(title: "Driving Cost", value: hasDrivingData ? appCurrency.formatCostPerDistance(cost: costPerDistance, distanceUnit: unitSystem.distanceUnit) : "N/A", icon: "road.lanes", color: .gray)
                StatCard(title: "Driving Eff. (100\(unitSystem.distanceUnit))", value: hasDrivingData ? unitSystem.formatConsumption(kmPerKWh: energyEfficiency) : "N/A", icon: "gauge.with.needle.fill", color: .teal)
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
                    drivingEfficiencyChart
                }
                .padding(.horizontal)
            } else {
                costChart
                energyChart
                drivingEfficiencyChart
            }
        }
    }

    private var costChart: some View {
        ChartCard(title: "Monthly Cost (\(appCurrency.code))", insetsHorizontally: !isWide) {
            Chart {
                ForEach(monthlyStats) { stat in
                    let isDimmed = selectedCostStat != nil && selectedCostStat?.id != stat.id
                    BarMark(
                        x: .value("Month", stat.month, unit: .month),
                        y: .value("Cost", stat.cost)
                    )
                    .foregroundStyle(.green.gradient)
                    .opacity(isDimmed ? 0.45 : 1.0)
                    .cornerRadius(4)
                }

                if let sel = selectedCostStat {
                    RuleMark(x: .value("Selected Month", sel.month, unit: .month))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .offset(yStart: -10)
                        .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            ChartTooltipCard {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sel.month.formatted(.dateTime.year().month(.wide)))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 5) {
                                        Circle().fill(Color.green).frame(width: 7, height: 7)
                                        Text(appCurrency.format(sel.cost))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    let totalKWh = sel.acEnergy + sel.dcEnergy + sel.untypedEnergy
                                    if totalKWh > 0 {
                                        Text(String(format: "%.1f kWh total", totalKWh))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                }
            }
            .chartXSelection(value: $selectedCostMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Monthly Charging Cost Trend")
            .accessibilityValue("Total cost across last 12 months: \(appCurrency.format(totalCost))")
            .accessibilityHint("Shows monthly charging cost trends in \(appCurrency.displayName) over the past year")
        }
    }

    private var energyChart: some View {
        ChartCard(title: "Monthly Energy by Type (kWh)", insetsHorizontally: !isWide) {
            Chart {
                ForEach(monthlyStats) { stat in
                    let isDimmed = selectedEnergyStat != nil && selectedEnergyStat?.id != stat.id
                    BarMark(
                        x: .value("Month", stat.month, unit: .month),
                        y: .value("kWh", stat.acEnergy)
                    )
                    .foregroundStyle(by: .value("Type", "AC"))
                    .opacity(isDimmed ? 0.45 : 1.0)
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Month", stat.month, unit: .month),
                        y: .value("kWh", stat.dcEnergy)
                    )
                    .foregroundStyle(by: .value("Type", "DC"))
                    .opacity(isDimmed ? 0.45 : 1.0)
                    .cornerRadius(4)

                    if showsUntypedEnergy {
                        BarMark(
                            x: .value("Month", stat.month, unit: .month),
                            y: .value("kWh", stat.untypedEnergy)
                        )
                        .foregroundStyle(by: .value("Type", "Unspecified"))
                        .opacity(isDimmed ? 0.45 : 1.0)
                        .cornerRadius(4)
                    }
                }

                if let sel = selectedEnergyStat {
                    RuleMark(x: .value("Selected Month", sel.month, unit: .month))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .offset(yStart: -10)
                        .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            ChartTooltipCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sel.month.formatted(.dateTime.year().month(.wide)))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    let totalKWh = sel.acEnergy + sel.dcEnergy + sel.untypedEnergy
                                    Text(String(format: "Total: %.1f kWh", totalKWh))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        if sel.acEnergy > 0 {
                                            HStack(spacing: 4) {
                                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                                Text(String(format: "AC: %.1f kWh", sel.acEnergy))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if sel.dcEnergy > 0 {
                                            HStack(spacing: 4) {
                                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                                Text(String(format: "DC: %.1f kWh", sel.dcEnergy))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if sel.untypedEnergy > 0 {
                                            HStack(spacing: 4) {
                                                Circle().fill(Color.gray).frame(width: 6, height: 6)
                                                Text(String(format: "Unspecified: %.1f kWh", sel.untypedEnergy))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                }
            }
            .chartXSelection(value: $selectedEnergyMonth)
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

    private var drivingEfficiencyChart: some View {
        ChartCard(
            title: efficiencyChartUnit == .consumption
                ? "Driving Efficiency — Recent (\(unitSystem.consumptionUnit))"
                : "Driving Efficiency — Recent (\(unitSystem.efficiencyUnit))",
            insetsHorizontally: !isWide
        ) {
            VStack(spacing: 12) {
                Picker("Efficiency Unit", selection: $efficiencyChartUnit) {
                    ForEach(EfficiencyChartUnit.allCases) { unit in
                        Text(unit.label(for: unitSystem)).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 2)

                if drivingEfficiencyPoints.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "leaf.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No Driving Efficiency Data")
                            .font(.subheadline).bold()
                            .foregroundColor(.primary)
                        Text("Log mileage on at least two charging sessions to view your driving efficiency trends over time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 24)
                } else {
                    let chart = Chart {
                        ForEach(drivingEfficiencyPoints) { point in
                            let yVal = point.value(for: efficiencyChartUnit, unitSystem: unitSystem)
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Efficiency", yVal)
                            )
                            .symbol(Circle())
                            .foregroundStyle(.teal)

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Efficiency", yVal)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal.opacity(0.25), .teal.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        if averageDrivingEfficiencyForUnit > 0 {
                            RuleMark(y: .value("Average", averageDrivingEfficiencyForUnit))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(.mint.opacity(0.8))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(String(format: "Avg: %.1f %@", averageDrivingEfficiencyForUnit, efficiencyChartUnit.label(for: unitSystem)))
                                        .font(.caption2).bold()
                                        .foregroundColor(.mint)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color(uiColor: .systemBackground).opacity(0.85))
                                        .cornerRadius(4)
                                }
                        }

                        if let sel = selectedEfficiencyPoint {
                            let selVal = sel.value(for: efficiencyChartUnit, unitSystem: unitSystem)
                            RuleMark(x: .value("Selected Date", sel.date))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .offset(yStart: -10)
                                .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                    ChartTooltipCard {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(sel.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                            HStack(spacing: 4) {
                                                Circle().fill(Color.teal).frame(width: 7, height: 7)
                                                Text(String(format: "%.1f %@", selVal, efficiencyChartUnit.label(for: unitSystem)))
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                            }
                                            let dist = unitSystem.convertFromKm(sel.distanceKm)
                                            Text(String(format: "%.0f %@ • %.1f kWh", dist, unitSystem.distanceUnit, sel.energyKWh))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                            PointMark(
                                x: .value("Selected Date", sel.date),
                                y: .value("Efficiency", selVal)
                            )
                            .symbol(Circle())
                            .symbolSize(90)
                            .foregroundStyle(.teal)
                        }
                    }
                    .chartXSelection(value: $selectedEfficiencyDate)
                    .chartXAxis {
                        AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(formatEfficiencyDate(date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            if let doubleValue = value.as(Double.self) {
                                AxisValueLabel {
                                    Text(String(format: "%.1f", doubleValue))
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Driving Efficiency Trend")
                    .accessibilityValue(
                        efficiencyChartUnit == .consumption
                            ? "Average consumption \(unitSystem.formatConsumption(kmPerKWh: energyEfficiency))"
                            : "Average efficiency \(unitSystem.formatEfficiency(kmPerKWh: energyEfficiency))"
                    )
                    .accessibilityHint("Line chart showing driving efficiency trends over time, switchable between \(unitSystem.efficiencyUnit) and \(unitSystem.consumptionUnit)")

                    Group {
                        if let domain = drivingEfficiencyDateDomain {
                            chart.chartXScale(domain: domain)
                        } else {
                            chart
                        }
                    }
                }
            }
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
                            Text(appCurrency.format(location.totalCost))
                                .font(.subheadline).bold()
                            if location.pricePerKWh > 0 {
                                Text(appCurrency.formatRate(location.pricePerKWh))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(location.name), \(location.sessionCount) sessions")
                    .accessibilityValue("\(String(format: "%.0f kWh", location.totalEnergy)), total \(appCurrency.format(location.totalCost))\(location.pricePerKWh > 0 ? String(format: ", %@ per kilowatt-hour", appCurrency.formatRate(location.pricePerKWh)) : "")")
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
                .frame(minHeight: 220, idealHeight: 240)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, insetsHorizontally ? 16 : 0)
        }
    }
}
