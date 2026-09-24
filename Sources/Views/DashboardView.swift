import SwiftUI
import Charts

struct MonthlyStat: Identifiable {
    let month: Date
    var cost: Double = 0
    var acCost: Double = 0
    var dcCost: Double = 0
    var untypedCost: Double = 0
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
    @State private var selectedEfficiencyDate: Date? = nil

    private var selectedCostStat: MonthlyStat? {
        guard let selectedCostMonth else { return nil }
        return monthlyStats.min(by: {
            abs($0.month.timeIntervalSince(selectedCostMonth)) < abs($1.month.timeIntervalSince(selectedCostMonth))
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
            case .ac:
                stat.acEnergy += session.energyAdded
                stat.acCost += session.totalPrice
            case .dc:
                stat.dcEnergy += session.energyAdded
                stat.dcCost += session.totalPrice
            case nil:
                stat.untypedEnergy += session.energyAdded
                stat.untypedCost += session.totalPrice
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

    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator

    @State private var showingSettings = false
    @State private var showingAddSession = false
    @State private var trendMetric: TrendMetric = .spend

    /// Hero figures: this month or lifetime. Shares its key with the widgets' deep-link state.
    @AppStorage("heroShowsTotalSpend") private var showsTotalSpend: Bool = false
    /// Rate tile: average charging price or driving cost per distance.
    @AppStorage("heroShowsDrivingCost") private var showsDrivingCost: Bool = false
    /// Efficiency tile: distance per kWh or kWh per 100 distance.
    @AppStorage("heroShowsConsumption") private var showsConsumption: Bool = false

    enum TrendMetric: Hashable {
        case spend, energy
    }

    // MARK: - Hero State

    private var spendTitle: String {
        showsTotalSpend
            ? String(localized: "Total Spent")
            : String(format: String(localized: "Spent in %@"), Date().formatted(.dateTime.month(.wide)))
    }

    private var spendCost: Double { showsTotalSpend ? totalCost : currentMonthCost }
    private var spendEnergy: Double { showsTotalSpend ? totalEnergy : currentMonthEnergy }
    private var spendSavings: GasSavingsSummary { showsTotalSpend ? lifetimeGasSavings : currentMonthGasSavings }

    private var rateTitle: String {
        showsDrivingCost ? String(localized: "Driving Cost") : String(localized: "Avg Rate")
    }

    private var rateValue: (value: String, unit: String) {
        if showsDrivingCost {
            guard hasDrivingData, costPerDistance > 0 else { return ("—", "") }
            return (appCurrency.format(costPerDistance), String(format: String(localized: "per %@"), unitSystem.distanceUnit))
        }
        guard averagePricePerKWh > 0 else { return ("—", "") }
        return (appCurrency.format(averagePricePerKWh), String(localized: "per kWh"))
    }

    private var efficiencyTitle: String {
        showsConsumption ? String(localized: "Consumption") : String(localized: "Efficiency")
    }

    private var efficiencyValue: (value: String, unit: String) {
        guard hasDrivingData, energyEfficiency > 0 else { return ("—", "") }
        let value = showsConsumption
            ? unitSystem.consumptionValue(kmPerKWh: energyEfficiency)
            : unitSystem.convertFromKm(energyEfficiency)
        return (String(format: "%.1f", value), showsConsumption ? unitSystem.consumptionUnit : unitSystem.efficiencyUnit)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar

                    if displayedSessions.isEmpty {
                        welcomeSection
                    } else if isWide {
                        wideLayout
                    } else {
                        compactLayout
                    }
                }
                .padding(.horizontal, isWide ? 32 : 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: isWide ? 1100 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .jouleTabBarClearance()
            .joulePage()
            .jouleStatusBarBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView()
            }
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 28) {
            spendSection
            statStrip
            if currentMonthDeferredCost > 0 {
                deferredBanner
            }
            batteryCard
            gasSavingsSection
            smartChargingSection
            trendSection
            drivingEfficiencySection
            if !topLocations.isEmpty {
                topLocationsSection
            }
            lifetimeSection
        }
    }

    /// iPad and Mac: the headline pair side by side, then the detail sections two to a row.
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 20) {
                    spendSection
                    statStrip
                    if currentMonthDeferredCost > 0 {
                        deferredBanner
                    }
                }
                .jouleCard(padding: 24, radius: 22)
                .frame(maxWidth: .infinity)

                batteryCard
                    .frame(maxWidth: .infinity)
            }

            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 28) {
                GridRow {
                    trendSection
                    drivingEfficiencySection
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 28) {
                        gasSavingsSection
                        smartChargingSection
                    }
                    VStack(alignment: .leading, spacing: 28) {
                        if !topLocations.isEmpty {
                            topLocationsSection
                        }
                        lifetimeSection
                    }
                }
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            GarageSwitcherMenu(allowAllOption: true)
            Spacer()
        }
    }

    // MARK: - Welcome (no sessions yet)
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Joule ⚡️")
                .font(.jouleDisplay(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.jouleInk)
            Text("Start tracking your charging sessions to unlock real-time monthly costs, gas savings comparison, and battery State of Health (SoH) analytics.")
                .font(.jouleText(16, relativeTo: .callout))
                .foregroundStyle(Color.jouleInk2)
                .fixedSize(horizontal: false, vertical: true)
            CellGauge(fraction: 0, height: 28, track: .jouleSunken)
            Button {
                navCoordinator.presentNewSession()
            } label: {
                Label("Log Charge", systemImage: "plus")
            }
            .buttonStyle(JoulePrimaryButtonStyle())
            Button {
                navCoordinator.triggerImport()
            } label: {
                Label("Import CSV…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(JouleDashedButtonStyle())
        }
        .padding(.top, 12)
    }

    // MARK: - Spend Hero
    private var spendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                JouleLabel(verbatim: spendTitle)
                Spacer(minLength: 8)
                JoulePillPicker(
                    options: [(false, "Month"), (true, "Lifetime")],
                    selection: $showsTotalSpend,
                    fillsWidth: false,
                    accessibilityTitle: "Period"
                )
                .fixedSize()
            }

            JouleAmount(formatted: appCurrency.format(spendCost), size: isWide ? 64 : 72)
                .contentTransition(.numericText())

            HStack(spacing: 10) {
                Text(String(format: String(localized: "%.1f kWh charged"), spendEnergy))
                    .font(.jouleText(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.jouleInk2)
                if spendSavings.netSavings > 0 {
                    JouleTag(
                        LocalizedStringKey(String(format: String(localized: "Saved %@"), appCurrency.format(spendSavings.netSavings))),
                        foreground: .joulePositive,
                        background: .joulePositiveSoft
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Stat Strip
    private var statStrip: some View {
        HStack(spacing: 0) {
            stripTile(
                label: rateTitle,
                value: rateValue.value,
                unit: rateValue.unit,
                hint: showsDrivingCost ? "Double tap to show average charging rate" : "Double tap to show driving cost per distance"
            ) {
                showsDrivingCost.toggle()
            }
            Rectangle().fill(Color.jouleLine).frame(width: 1)
            stripTile(
                label: efficiencyTitle,
                value: efficiencyValue.value,
                unit: efficiencyValue.unit,
                hint: showsConsumption ? "Double tap to show distance per kWh" : "Double tap to show consumption"
            ) {
                showsConsumption.toggle()
            }
            Rectangle().fill(Color.jouleLine).frame(width: 1)
            stripTile(
                label: String(localized: "Avg Monthly Cost"),
                value: appCurrency.format(totalCost / Double(max(uniqueMonthsCount, 1))),
                unit: String(format: "%.1f kWh", totalEnergy / Double(max(uniqueMonthsCount, 1))),
                hint: nil,
                action: nil
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .jouleCard(padding: 0)
    }

    private func stripTile(label: String, value: String, unit: String, hint: String?, action: (() -> Void)?) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                JouleLabel(verbatim: label)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if action != nil {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.jouleMuted)
                }
            }
            Text(value)
                .font(.jouleDisplay(20, relativeTo: .title3))
                .foregroundStyle(Color.jouleInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(unit.isEmpty ? " " : unit)
                .font(.jouleText(12, relativeTo: .caption))
                .foregroundStyle(Color.jouleMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .contentShape(Rectangle())

        return Group {
            if let action {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { action() }
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(LocalizedStringKey(hint ?? "")))
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Deferred Banner
    private var deferredBanner: some View {
        Button {
            navCoordinator.selectTab(.history)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.joulePaper)
                    .frame(width: 40, height: 40)
                    .background(Color.jouleDeferred, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deferred to Bill This Month")
                        .font(.jouleText(13, relativeTo: .footnote))
                        .foregroundStyle(Color.jouleDeferredOnSoft)
                    Text(appCurrency.format(currentMonthDeferredCost))
                        .font(.jouleText(17, relativeTo: .headline).weight(.semibold))
                        .foregroundStyle(Color.jouleInk)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.jouleDeferredOnSoft)
            }
            .joulePanel(.jouleDeferredSoft, padding: 14, radius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deferred to Electric Bill This Month")
        .accessibilityValue(appCurrency.format(currentMonthDeferredCost))
    }

    // MARK: - Battery Health Card
    private var batteryHealthSummary: BatteryHealthSummary? {
        let targetSessions = store.sessions(for: store.activeVehicle.id)
        return BatteryHealthService(vehicle: store.activeVehicle).calculateSummary(from: targetSessions)
    }

    @ViewBuilder
    private var batteryCard: some View {
        if let health = batteryHealthSummary {
            Button {
                navCoordinator.selectTab(.batteryHealth)
            } label: {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        JouleLabel("Battery Health")
                        Spacer()
                        JouleTag(LocalizedStringKey(health.assessment.title), foreground: .jouleVolt, background: .jouleInverse)
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(String(format: "%.1f", health.currentSoH))
                            .font(.jouleDisplay(64, relativeTo: .largeTitle))
                            .tracking(-2)
                        + Text("%")
                            .font(.jouleDisplay(32, relativeTo: .title))
                        Text("SoH")
                            .font(.jouleText(13, relativeTo: .footnote))
                            .foregroundStyle(Color.jouleMuted)
                    }
                    .foregroundStyle(Color.jouleInk)

                    CellGauge(fraction: health.currentSoH / 100, track: .jouleSunken)

                    HStack {
                        Text(String(format: "%.1f / %.1f kWh", health.currentCapacityKWh, health.nominalCapacityKWh))
                        Spacer()
                        Text(String(format: "%.1f cyc", health.equivalentFullCycles))
                    }
                    .font(.jouleMono(12))
                    .foregroundStyle(Color.jouleMuted)

                    HStack(alignment: .top, spacing: 12) {
                        batteryStat(
                            label: "Annual Rate",
                            value: health.degradationPerYear.map { String(format: "%.2f%%", abs($0)) } ?? "—",
                            color: health.degradationPerYear == nil ? .jouleInk : .jouleDanger
                        )
                        batteryStat(
                            label: "Projected 100% Range",
                            value: unitSystem.formatDistance(km: health.currentProjectedRangeKm ?? health.nominalRangeKm),
                            color: .jouleInk
                        )
                    }
                    .padding(.top, 16)
                    .overlay(alignment: .top) { Rectangle().fill(Color.jouleLine).frame(height: 1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .jouleCard(padding: 20, radius: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Battery Health: \(String(format: "%.1f%%", health.currentSoH)) State of Health, \(health.assessment.title)")
            .accessibilityValue("\(String(format: "%.1f", health.currentCapacityKWh)) usable of \(String(format: "%.1f", health.nominalCapacityKWh)) kWh nominal, \(String(format: "%.1f", health.equivalentFullCycles)) full cycles")
            .accessibilityHint("Double tap to open detailed battery health analytics")
        }
    }

    private func batteryStat(label: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.jouleDisplay(20, relativeTo: .title3))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.jouleText(12, relativeTo: .caption))
                .foregroundStyle(Color.jouleMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Smart Charging & TOU Section
    @ViewBuilder
    private var smartChargingSection: some View {
        let smart = stats.currentMonthSmartChargingSavings
        if smart.hasSavings {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(Color.joulePositive)
                    Text("Off-Peak Smart Charging")
                        .font(.jouleText(15, relativeTo: .headline).weight(.semibold))
                        .foregroundStyle(Color.jouleInk)
                    Spacer()
                    Text(String(format: "-%.0f%% vs Peak", smart.savingsPercentage))
                        .font(.jouleMono(12).weight(.medium))
                        .foregroundStyle(Color.joulePositive)
                }

                Text(String(format: String(localized: "Charging on %1$@ saved you %2$@ this month compared to peak daytime rates (%3$.1f kWh logged)."), smart.tariffName, appCurrency.format(smart.savingsAmount), smart.homeEnergyKWh))
                    .font(.jouleText(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.jouleInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .joulePanel(.joulePositiveSoft, padding: 16, radius: 16)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Cost Savings vs. Gas Section
    @ViewBuilder
    private var gasSavingsSection: some View {
        let savings = lifetimeGasSavings
        if savings.gasCost > 0 {
            VStack(alignment: .leading, spacing: 14) {
                JouleSectionHeader("Cost Savings vs. Gas") {
                    Button {
                        showingSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Baseline")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.jouleText(14, relativeTo: .subheadline).weight(.medium))
                        .foregroundStyle(Color.jouleInk)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            JouleLabel("Estimated Savings")
                            JouleAmount(
                                formatted: appCurrency.format(savings.netSavings),
                                size: 40,
                                color: .joulePositive,
                                fractionColor: .joulePositive.opacity(0.7)
                            )
                        }
                        Spacer(minLength: 8)
                        if savings.savingsPercentage > 0 {
                            JouleTag(
                                LocalizedStringKey(String(format: "%.0f%% Saved", savings.savingsPercentage)),
                                foreground: .joulePositive,
                                background: .joulePositiveSoft
                            )
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        JouleStat(
                            label: "EV Spent",
                            value: appCurrency.format(savings.evCost),
                            caption: savings.evCostPerDistance > 0 ? appCurrency.formatCostPerDistance(cost: savings.evCostPerDistance, distanceUnit: unitSystem.distanceUnit) : nil,
                            valueSize: 17
                        )
                        JouleStat(
                            label: "Gas Equivalent",
                            value: appCurrency.format(savings.gasCost),
                            caption: savings.gasCostPerDistance > 0 ? appCurrency.formatCostPerDistance(cost: savings.gasCostPerDistance, distanceUnit: unitSystem.distanceUnit) : nil,
                            valueSize: 17
                        )
                        JouleStat(
                            label: "Fuel Avoided",
                            value: String(format: "%.0f %@", savings.fuelAvoided, savings.fuelUnit),
                            caption: String(format: String(localized: "Saved/%@"), unitSystem.distanceUnit) + " " + appCurrency.format(savings.costDifferencePerDistance),
                            valueSize: 17
                        )
                    }
                    .padding(.top, 14)
                    .overlay(alignment: .top) { Rectangle().fill(Color.jouleLine).frame(height: 1) }

                    Text(String(format: String(localized: "Baseline: %1$@ @ %2$@"), gasPreset.localizedTitle(for: unitSystem), appCurrency.formatRate(GasComparisonSettings.effectiveFuelPrice(currency: appCurrency, unitSystem: unitSystem), unit: GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))))
                        .font(.jouleText(12, relativeTo: .caption))
                        .foregroundStyle(Color.jouleMuted)
                        .lineLimit(2)
                }
                .jouleCard(padding: 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cost Savings vs Gas: \(appCurrency.format(savings.netSavings)) saved (\(String(format: "%.0f%%", savings.savingsPercentage))), \(String(format: "%.0f %@", savings.fuelAvoided, savings.fuelUnit)) fuel avoided")
            }
        }
    }

    // MARK: - Lifetime & Averages
    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            JouleSectionHeader("Lifetime Totals")
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    JouleStat(label: "Total Spent", value: appCurrency.format(totalCost), valueSize: 20).padding(16)
                    JouleStat(label: "Total Energy", value: String(format: "%.1f kWh", totalEnergy), valueSize: 20).padding(16)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.jouleLine).frame(width: 1) }
                }
                Rectangle().fill(Color.jouleLine).frame(height: 1).gridCellColumns(2)
                GridRow {
                    JouleStat(label: "Distance", value: hasDrivingData ? unitSystem.formatDistance(km: totalDistance) : "—", valueSize: 20).padding(16)
                    JouleStat(label: "Sessions", value: "\(totalSessions)", valueSize: 20).padding(16)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.jouleLine).frame(width: 1) }
                }
            }
            .jouleCard(padding: 0)
        }
    }

    // MARK: - Trends
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            JouleSectionHeader("Trends") {
                JoulePillPicker(
                    options: [(TrendMetric.spend, "Spend"), (TrendMetric.energy, "Energy")],
                    selection: $trendMetric,
                    fillsWidth: false,
                    accessibilityTitle: "Trends"
                )
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    legendSwatch("AC", color: .jouleAC)
                    legendSwatch("DC", color: .jouleDC)
                    if showsUntypedEnergy {
                        legendSwatch("Unspecified", color: .jouleMuted)
                    }
                    Spacer()
                    Text(trendMetric == .spend ? appCurrency.code : "kWh")
                        .font(.jouleMono(11))
                        .foregroundStyle(Color.jouleMuted)
                }
                monthlyChart
                    .frame(height: 220)
            }
            .jouleCard(padding: 16)
        }
    }

    private func legendSwatch(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(title)
                .font(.jouleText(12, relativeTo: .caption))
                .foregroundStyle(Color.jouleInk2)
        }
    }

    private func trendValue(_ stat: MonthlyStat, _ type: ChargingType?) -> Double {
        switch (trendMetric, type) {
        case (.spend, .ac?): return stat.acCost
        case (.spend, .dc?): return stat.dcCost
        case (.spend, nil): return stat.untypedCost
        case (.energy, .ac?): return stat.acEnergy
        case (.energy, .dc?): return stat.dcEnergy
        case (.energy, nil): return stat.untypedEnergy
        }
    }

    private var monthlyChart: some View {
        let selected = selectedCostStat
        let typeSeries: [(ChargingType?, String)] = showsUntypedEnergy
            ? [(.ac, "AC"), (.dc, "DC"), (nil, "Unspecified")]
            : [(.ac, "AC"), (.dc, "DC")]

        return Chart {
            ForEach(monthlyStats) { stat in
                let isDimmed = selected != nil && selected?.id != stat.id
                ForEach(typeSeries, id: \.1) { type, name in
                    BarMark(
                        x: .value("Month", stat.month, unit: .month),
                        y: .value("Value", trendValue(stat, type))
                    )
                    .foregroundStyle(by: .value("Type", name))
                    .opacity(isDimmed ? 0.35 : 1.0)
                }
            }

            if let sel = selected {
                RuleMark(x: .value("Selected Month", sel.month, unit: .month))
                    .foregroundStyle(Color.jouleInk.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sel.month.formatted(.dateTime.year().month(.wide)))
                                    .font(.jouleMono(11))
                                    .foregroundStyle(Color.jouleMuted)
                                Text(appCurrency.format(sel.cost))
                                    .font(.jouleDisplay(17, relativeTo: .headline))
                                    .foregroundStyle(Color.jouleInk)
                                if sel.acEnergy > 0 {
                                    ChartTooltipRow(title: "AC", value: String(format: "%.1f kWh", sel.acEnergy), dotColor: .jouleAC)
                                }
                                if sel.dcEnergy > 0 {
                                    ChartTooltipRow(title: "DC", value: String(format: "%.1f kWh", sel.dcEnergy), dotColor: .jouleDC)
                                }
                                if sel.untypedEnergy > 0 {
                                    ChartTooltipRow(title: "Unspecified", value: String(format: "%.1f kWh", sel.untypedEnergy), dotColor: .jouleMuted)
                                }
                            }
                        }
                    }
            }
        }
        .chartXSelection(value: $selectedCostMonth)
        .chartForegroundStyleScale(
            domain: typeSeries.map(\.1),
            range: showsUntypedEnergy ? [Color.jouleAC, .jouleDC, .jouleMuted] : [Color.jouleAC, .jouleDC]
        )
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow))
                    .font(.jouleMono(11))
                    .foregroundStyle(Color.jouleMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel()
                    .font(.jouleMono(10))
                    .foregroundStyle(Color.jouleMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trendMetric == .spend ? "Monthly Charging Cost Trend" : "Monthly Energy Breakdown by Charging Type")
        .accessibilityValue(trendMetric == .spend
            ? "Total cost across last 12 months: \(appCurrency.format(totalCost))"
            : "Total energy \(String(format: "%.1f kWh", totalEnergy)) across AC and DC charging")
    }

    private var drivingEfficiencySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            JouleSectionHeader("Driving Efficiency")

            VStack(alignment: .leading, spacing: 12) {
                JoulePillPicker(
                    options: EfficiencyChartUnit.allCases.map { ($0, LocalizedStringKey($0.label(for: unitSystem))) },
                    selection: $efficiencyChartUnit,
                    accessibilityTitle: "Efficiency Unit"
                )

                if drivingEfficiencyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No Driving Efficiency Data")
                            .font(.jouleText(15, relativeTo: .headline).weight(.semibold))
                            .foregroundStyle(Color.jouleInk)
                        Text("Log mileage on at least two charging sessions to view your driving efficiency trends over time.")
                            .font(.jouleText(13, relativeTo: .footnote))
                            .foregroundStyle(Color.jouleMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                } else {
                    if averageDrivingEfficiencyForUnit > 0 {
                        HStack(spacing: 6) {
                            Rectangle()
                                .stroke(Color.jouleMuted, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: 16, height: 1)
                            Text(String(format: "Avg: %.1f %@", averageDrivingEfficiencyForUnit, efficiencyChartUnit.label(for: unitSystem)))
                                .font(.jouleMono(11))
                                .foregroundStyle(Color.jouleMuted)
                        }
                    }
                    Group {
                        if let domain = drivingEfficiencyDateDomain {
                            efficiencyChart.chartXScale(domain: domain)
                        } else {
                            efficiencyChart
                        }
                    }
                    .frame(height: 200)
                }
            }
            .jouleCard(padding: 16)
        }
    }

    private var efficiencyChart: some View {
        Chart {
            ForEach(drivingEfficiencyPoints) { point in
                let yVal = point.value(for: efficiencyChartUnit, unitSystem: unitSystem)
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Efficiency", yVal)
                )
                .foregroundStyle(Color.jouleInk)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Efficiency", yVal)
                )
                .foregroundStyle(Color.jouleAC)
                .symbolSize(30)
            }

            if averageDrivingEfficiencyForUnit > 0 {
                RuleMark(y: .value("Average", averageDrivingEfficiencyForUnit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.jouleMuted)
            }

            if let sel = selectedEfficiencyPoint {
                let selVal = sel.value(for: efficiencyChartUnit, unitSystem: unitSystem)
                RuleMark(x: .value("Selected Date", sel.date))
                    .foregroundStyle(Color.jouleInk.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sel.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                    .font(.jouleMono(11))
                                    .foregroundStyle(Color.jouleMuted)
                                Text(String(format: "%.1f %@", selVal, efficiencyChartUnit.label(for: unitSystem)))
                                    .font(.jouleDisplay(17, relativeTo: .headline))
                                    .foregroundStyle(Color.jouleInk)
                                let dist = unitSystem.convertFromKm(sel.distanceKm)
                                Text(String(format: "%.0f %@ • %.1f kWh", dist, unitSystem.distanceUnit, sel.energyKWh))
                                    .font(.jouleText(11, relativeTo: .caption2))
                                    .foregroundStyle(Color.jouleMuted)
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Date", sel.date),
                    y: .value("Efficiency", selVal)
                )
                .symbolSize(110)
                .foregroundStyle(Color.jouleVolt)
            }
        }
        .chartXSelection(value: $selectedEfficiencyDate)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatEfficiencyDate(date))
                            .font(.jouleMono(10))
                            .foregroundStyle(Color.jouleMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", doubleValue))
                            .font(.jouleMono(10))
                            .foregroundStyle(Color.jouleMuted)
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
    }

    // MARK: - Top Locations
    private var topLocationsSection: some View {
        let dearest = topLocations.map(\.pricePerKWh).max() ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            JouleSectionHeader("Top Locations")

            VStack(spacing: 0) {
                ForEach(Array(topLocations.enumerated()), id: \.element.id) { index, location in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(location.name)
                                .font(.jouleText(15, relativeTo: .headline).weight(.semibold))
                                .foregroundStyle(Color.jouleInk)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if location.pricePerKWh > 0 {
                                Text(appCurrency.formatRate(location.pricePerKWh))
                                    .font(.jouleMono(13, relativeTo: .subheadline).weight(.medium))
                                    .foregroundStyle(Color.jouleInk)
                            }
                        }
                        ShareBar(
                            fraction: dearest > 0 ? location.pricePerKWh / dearest : 0,
                            color: location.pricePerKWh >= dearest * 0.6 ? .jouleDC : .jouleAC
                        )
                        Text(String(format: String(localized: "%1$lld sessions • %2$.0f kWh"), Int64(location.sessionCount), location.totalEnergy) + " · " + appCurrency.format(location.totalCost))
                            .font(.jouleText(13, relativeTo: .footnote))
                            .foregroundStyle(Color.jouleMuted)
                    }
                    .padding(16)
                    .overlay(alignment: .top) {
                        if index > 0 { Rectangle().fill(Color.jouleLine).frame(height: 1) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(location.name), \(location.sessionCount) sessions")
                    .accessibilityValue("\(String(format: "%.0f kWh", location.totalEnergy)), total \(appCurrency.format(location.totalCost))\(location.pricePerKWh > 0 ? String(format: ", %@ per kilowatt-hour", appCurrency.formatRate(location.pricePerKWh)) : "")")
                }
            }
            .jouleCard(padding: 0)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    /// Optional tint for the value text; defaults to the standard label color.
    var valueColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            JouleLabel(title)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.jouleDisplay(24, relativeTo: .title2))
                .foregroundStyle(valueColor ?? .jouleInk)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .jouleCard(padding: 16, radius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}
