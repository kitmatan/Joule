import SwiftUI
import Charts

struct BatteryHealthView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    
    @State private var selectedTimeRange: ChartTimeRange = .all
    @State private var selectedChartMode: ChartMode = {
        if let mode = ProcessInfo.processInfo.environment["BATTERY_CHART_MODE"] {
            switch mode {
            case "mileage": return .mileage
            case "range": return .range
            case "cycles": return .cycles
            default: return .time
            }
        }
        return .mileage
    }()

    @State private var selectedDate: Date? = nil
    @State private var selectedMileage: Double? = nil
    @State private var selectedRangeDate: Date? = nil
    @State private var selectedCycle: Double? = nil

    private var selectedHealthPoint: BatteryHealthDataPoint? {
        guard let selectedDate, !filteredPoints.isEmpty else { return nil }
        return filteredPoints.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var selectedHealthTrend: BatteryHealthTrendPoint? {
        guard let selectedDate, !trendPoints.isEmpty else { return nil }
        return trendPoints.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var selectedMileagePoint: BatteryHealthDataPoint? {
        guard let selectedMileage else { return nil }
        let mileagePoints = filteredPoints.filter { $0.mileage != nil }
        guard !mileagePoints.isEmpty else { return nil }
        return mileagePoints.min(by: {
            let m0 = unitSystem.convertFromKm($0.mileage!)
            let m1 = unitSystem.convertFromKm($1.mileage!)
            return abs(m0 - selectedMileage) < abs(m1 - selectedMileage)
        })
    }

    private var selectedMileageTrend: BatteryHealthTrendPoint? {
        guard let selectedMileage else { return nil }
        let validTrend = trendPoints.filter { $0.mileage != nil }
        guard !validTrend.isEmpty else { return nil }
        return validTrend.min(by: {
            let m0 = unitSystem.convertFromKm($0.mileage!)
            let m1 = unitSystem.convertFromKm($1.mileage!)
            return abs(m0 - selectedMileage) < abs(m1 - selectedMileage)
        })
    }

    private var selectedRangePoint: BatteryHealthDataPoint? {
        guard let selectedRangeDate else { return nil }
        let rangePoints = filteredPoints.filter { $0.projectedFullRangeKm != nil }
        guard !rangePoints.isEmpty else { return nil }
        return rangePoints.min(by: {
            abs($0.date.timeIntervalSince(selectedRangeDate)) < abs($1.date.timeIntervalSince(selectedRangeDate))
        })
    }

    private var selectedRangeTrend: BatteryHealthTrendPoint? {
        guard let selectedRangeDate else { return nil }
        let validTrend = trendPoints.filter { $0.projectedFullRangeKm != nil }
        guard !validTrend.isEmpty else { return nil }
        return validTrend.min(by: {
            abs($0.date.timeIntervalSince(selectedRangeDate)) < abs($1.date.timeIntervalSince(selectedRangeDate))
        })
    }
    
    private var isWide: Bool { horizontalSizeClass == .regular }
    
    enum ChartTimeRange: String, CaseIterable, Identifiable {
        case all = "All Time"
        case pastYear = "1 Year"
        case pastSixMonths = "6 Months"
        
        var id: String { rawValue }
    }
    
    enum ChartMode: String, CaseIterable, Identifiable {
        case time = "Over Time"
        case mileage = "Vs. Mileage"
        case range = "Range"
        case cycles = "Cycle Wear"
        
        var id: String { rawValue }
        
        func title(unit: UnitSystem) -> LocalizedStringKey {
            switch self {
            case .time: return "Over Time"
            case .mileage: return "Vs. Mileage"
            case .range: return "Range (\(unit.distanceUnit))"
            case .cycles: return "Cycle Wear"
            }
        }
    }
    
    private var targetVehicle: Vehicle {
        store.activeVehicle
    }
    
    private var service: BatteryHealthService {
        BatteryHealthService(vehicle: targetVehicle)
    }
    
    private var vehicleSessions: [ChargingSession] {
        store.sessions(for: targetVehicle.id)
    }
    
    private var allPoints: [BatteryHealthDataPoint] {
        service.calculateDataPoints(from: vehicleSessions)
    }
    
    private var referenceReadings: [BatteryHealthReference] {
        targetVehicle.referenceReadings
    }
    
    /// Service readings inside the selected chart window, so the chart and the session samples
    /// always cover the same span.
    private var filteredReferences: [BatteryHealthReference] {
        let calendar = Calendar.current
        let now = Date()
        return referenceReadings.filter { reading in
            switch selectedTimeRange {
            case .all:
                return true
            case .pastYear:
                guard let cutoff = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
                return reading.date >= cutoff
            case .pastSixMonths:
                guard let cutoff = calendar.date(byAdding: .month, value: -6, to: now) else { return true }
                return reading.date >= cutoff
            }
        }
    }
    
    private var filteredPoints: [BatteryHealthDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        return allPoints.filter { point in
            switch selectedTimeRange {
            case .all:
                return true
            case .pastYear:
                guard let cutoff = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
                return point.date >= cutoff
            case .pastSixMonths:
                guard let cutoff = calendar.date(byAdding: .month, value: -6, to: now) else { return true }
                return point.date >= cutoff
            }
        }
    }
    
    private var trendPoints: [BatteryHealthTrendPoint] {
        service.calculateTrend(from: filteredPoints)
    }
    
    private var dateSpanDays: Double {
        let dates = filteredPoints.map(\.date)
        guard let minD = dates.min(), let maxD = dates.max() else { return 0 }
        return max(1.0, maxD.timeIntervalSince(minD) / 86400.0)
    }

    private var dateDomain: ClosedRange<Date>? {
        let dates = filteredPoints.map(\.date) + filteredReferences.map(\.date)
        guard let minD = dates.min(), let maxD = dates.max() else { return nil }
        let span = maxD.timeIntervalSince(minD)
        if span < 86400 {
            return minD.addingTimeInterval(-43200)...maxD.addingTimeInterval(43200)
        }
        let buffer = span * 0.08
        return minD.addingTimeInterval(-buffer)...maxD.addingTimeInterval(buffer)
    }

    private var mileageDomain: ClosedRange<Double>? {
        let mileages = filteredPoints.compactMap(\.mileage).map { unitSystem.convertFromKm($0) }
        guard let minM = mileages.min(), let maxM = mileages.max(), maxM > minM else { return nil }
        let buffer = (maxM - minM) * 0.08
        return max(0, minM - buffer)...(maxM + buffer)
    }

    private func formatMileageAxis(_ value: Double) -> String {
        let mileages = filteredPoints.compactMap(\.mileage).map { unitSystem.convertFromKm($0) }
        let maxM = mileages.max() ?? value
        if maxM < 5000 {
            let roundedVal = Int(value.rounded())
            if roundedVal >= 1000 {
                return "\(roundedVal.formatted(.number)) \(unitSystem.distanceUnit)"
            } else {
                return "\(roundedVal) \(unitSystem.distanceUnit)"
            }
        } else if maxM < 20000 {
            let kVal = value / 1000.0
            if kVal.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "%.0fk %@", kVal, unitSystem.distanceUnit)
            } else {
                return String(format: "%.1fk %@", kVal, unitSystem.distanceUnit)
            }
        } else {
            let kVal = (value / 1000.0).rounded()
            return String(format: "%.0fk %@", kVal, unitSystem.distanceUnit)
        }
    }

    private func formatAxisDate(_ date: Date) -> String {
        if dateSpanDays <= 90 {
            return date.formatted(.dateTime.month(.abbreviated).day())
        } else if dateSpanDays <= 365 * 2 {
            let month = date.formatted(.dateTime.month(.abbreviated))
            let year = date.formatted(.dateTime.year(.twoDigits))
            return "\(month) '\(year)"
        } else {
            return date.formatted(.dateTime.year())
        }
    }

    private var summary: BatteryHealthSummary? {
        service.calculateSummary(from: vehicleSessions, references: referenceReadings)
    }

    private var behaviorAnalysis: ChargingBehaviorAnalysis {
        ChargingBehaviorService.analyze(sessions: vehicleSessions, vehicle: targetVehicle)
    }
    
    @State private var showingSettings = false
    @State private var showingBestPracticesSheet = false
    @State private var showingCertificateSheet = false
    @State private var showingReferenceEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if let summary = summary, !allPoints.isEmpty {
                    heroCard(summary: summary)
                    metricsGrid(summary: summary)
                    chartsSection(summary: summary)
                    chargingHabitsSection(summary: summary)
                    recentEstimatesSection
                } else {
                    // A service reading is worth showing even with no charging history behind it —
                    // it is often the only battery figure a new owner has.
                    if let reading = referenceReadings.last {
                        referenceBand(
                            BatteryReferenceComparison(reference: reading, estimatedSoHAtReadingDate: nil)
                        )
                    } else {
                        // With no sessions there is no hero card to host it, and the toolbar no
                        // longer carries the button, so this is the only way in.
                        addReferenceButton
                    }
                    emptyState
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
        .navigationTitle("Battery Health")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingBestPracticesSheet) {
            ChargingBestPracticesSheet(vehicle: targetVehicle)
        }
        .sheet(isPresented: $showingReferenceEditor) {
            BatteryReferenceEditorView(vehicle: targetVehicle)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingCertificateSheet) {
            if let summary = summary {
                BatteryHealthCertificateView(
                    vehicle: targetVehicle,
                    summary: summary,
                    behavior: behaviorAnalysis,
                    unitSystem: unitSystem,
                    currency: VehicleProfile.currency,
                    totalSessions: vehicleSessions.count
                )
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GarageSwitcherMenu(allowAllOption: false)
                Spacer()
                if summary != nil, !allPoints.isEmpty {
                    Button {
                        showingCertificateSheet = true
                    } label: {
                        Label("Battery Certificate", systemImage: "square.and.arrow.up")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(JouleOutlineButtonStyle())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Battery Health")
                    .font(.jouleDisplay(34, relativeTo: .largeTitle))
                    .foregroundStyle(Color.jouleInk)
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: "%@ · %.1f kWh · %@", targetVehicle.name, targetVehicle.nominalCapacityKWh, targetVehicle.chemistry.badgeTitle))
                    .font(.jouleText(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.jouleMuted)
            }
        }
    }

    // MARK: - Hero Card
    private func heroCard(summary: BatteryHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                JouleTag(LocalizedStringKey(summary.assessment.title), foreground: .jouleVolt, background: .jouleInverse)
                JouleLabel("Estimated State of Health (SoH)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            (Text(String(format: "%.1f", summary.currentSoH))
                .font(.jouleDisplay(isWide ? 96 : 104, relativeTo: .largeTitle))
             + Text("%")
                .font(.jouleDisplay(48, relativeTo: .largeTitle)))
                .tracking(-3)
                .foregroundStyle(Color.jouleInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            batteryGauge(fraction: summary.currentSoH / 100)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining Usable Capacity")
                        .font(.jouleText(13, relativeTo: .footnote))
                        .foregroundStyle(Color.jouleMuted)
                    Text(String(format: "%.1f / %.1f kWh", summary.currentCapacityKWh, summary.nominalCapacityKWh))
                        .font(.jouleDisplay(22, relativeTo: .title2))
                        .foregroundStyle(Color.jouleInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Capacity Loss")
                        .font(.jouleText(13, relativeTo: .footnote))
                        .foregroundStyle(Color.jouleMuted)
                    Text(String(format: "%.1f kWh · %.1f%%", summary.capacityLostKWh, summary.totalDegradationPercentage))
                        .font(.jouleDisplay(22, relativeTo: .title2))
                        .foregroundStyle(Color.jouleDanger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let comparison = summary.referenceComparison {
                referenceBand(comparison)
            } else {
                addReferenceButton
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery State of Health: \(String(format: "%.1f%%", summary.currentSoH)), \(summary.assessment.title)")
        .accessibilityValue("Usable capacity: \(String(format: "%.1f", summary.currentCapacityKWh)) of \(String(format: "%.1f", summary.nominalCapacityKWh)) kilowatt-hours nominal. Capacity loss: \(String(format: "%.1f", summary.capacityLostKWh)) kilowatt-hours (\(String(format: "%.1f%%", summary.totalDegradationPercentage)))")
    }

    /// The pack drawn as a battery: ten cells in an outlined case with a terminal nub.
    private func batteryGauge(fraction: Double) -> some View {
        HStack(spacing: 4) {
            CellGauge(fraction: fraction, cells: 10, height: 50, spacing: 4, track: .jouleSunken, cornerRadius: 6)
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.jouleInk, lineWidth: 2)
                )
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 3, topTrailingRadius: 3)
                .fill(Color.jouleInk)
                .frame(width: 6, height: 22)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Service Reading Band
    
    /// The externally measured figure, shown as its own dated and attributed record rather than
    /// blended into the headline number above it. The two are different measurements; presenting
    /// them as one would misrepresent both.
    private func referenceBand(_ comparison: BatteryReferenceComparison) -> some View {
        Button {
            showingReferenceEditor = true
        } label: {
            referenceBandContent(comparison)
        }
        .buttonStyle(.plain)
    }
    
    /// Shown in place of the band when nothing has been measured yet, so the feature is reachable
    /// from the screen it affects rather than only from the toolbar.
    private var addReferenceButton: some View {
        Button {
            showingReferenceEditor = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.joule(.subheadline))
                    .foregroundColor(.jouleInk2)
                Text("Add a service reading")
                    .font(.joule(.subheadline))
                    .fontWeight(.medium)
                    .foregroundColor(.jouleInk)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.joule(.caption2))
                    .foregroundColor(.jouleMuted)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.jouleMuted.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func referenceBandContent(_ comparison: BatteryReferenceComparison) -> some View {
        let reading = comparison.reference
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: reading.source.icon)
                    .font(.joule(.caption))
                    .foregroundColor(.jouleReference)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Service Reading")
                        .font(.joule(.caption))
                        .fontWeight(.semibold)
                        .foregroundColor(.jouleMuted)
                    
                    HStack(spacing: 6) {
                        Text(reading.source.displayName)
                        Text("•")
                        Text(reading.date.formatted(.dateTime.year().month(.abbreviated).day()))
                    }
                    .font(.joule(.caption2))
                    .foregroundColor(.jouleMuted)
                }
                
                Spacer()
                
                Text(String(format: "%.1f%%", reading.sohPercent))
                    .font(.joule(.title3))
                    .fontWeight(.bold)
                    .foregroundColor(.jouleReference)
                
                Image(systemName: "chevron.right")
                    .font(.joule(.caption2))
                    .foregroundColor(.jouleMuted)
            }
            
            if let delta = comparison.delta, let estimate = comparison.estimatedSoHAtReadingDate {
                Text(String(
                    format: String(localized: "%@ vs Joule's %.1f%% estimate for that date"),
                    signedDelta(delta),
                    estimate
                ))
                .font(.joule(.caption2))
                .foregroundColor(.jouleMuted)
            } else {
                Text("No charging history near this date to compare against.")
                    .font(.joule(.caption2))
                    .foregroundColor(.jouleMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.jouleReferenceSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Service reading: \(String(format: "%.1f%%", reading.sohPercent)) measured \(reading.date.formatted(.dateTime.year().month(.wide).day()))")
    }
    
    private func signedDelta(_ delta: Double) -> String {
        String(format: delta >= 0 ? "+%.1f pts" : "%.1f pts", delta)
    }
    
    // MARK: - Why The Two Numbers Differ
    
    /// Pre-empts the obvious question a second SoH number raises. Without this the app looks like
    /// it is contradicting itself; with it, the gap reads as two honest methods disagreeing by
    /// about as much as they should.
    private func referenceExplanationView(_ comparison: BatteryReferenceComparison) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.joule(.body))
                .foregroundColor(.jouleReference)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Why don't these two numbers match?")
                    .font(.joule(.subheadline))
                    .fontWeight(.semibold)
                    .foregroundColor(.jouleInk)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("•").bold()
                        Text("**Joule** measures from the charger: energy delivered at the plug, divided by the SoC it moved. It depends on the charging efficiency you have configured.")
                    }
                    HStack(alignment: .top, spacing: 4) {
                        Text("•").bold()
                        Text("**A service tool** reads the pack's own capacity model, often against gross rather than usable capacity, and usually rounds to a whole percent.")
                    }
                    
                    switch comparison.agreement {
                    case .withinExpectedOffset:
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").bold()
                            Text("The two agree to within the offset these methods normally differ by. Joule keeps showing its own estimate because it tracks the **trend** between service visits.")
                        }
                    case .exceedsExpectedOffset:
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").bold()
                            Text("The gap is wider than the methods usually differ by. Check that the nominal pack capacity and charging efficiency in your vehicle settings match the figures your service tool assumes.")
                        }
                    case .notComparable:
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").bold()
                            Text("There is no charging history near the measurement date, so the two cannot be compared directly.")
                        }
                    }
                }
                .font(.joule(.caption))
                .foregroundColor(.jouleMuted)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.jouleReferenceSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Metrics Grid
    private func metricsGrid(summary: BatteryHealthSummary) -> some View {
        let columns: [GridItem] = {
            if dynamicTypeSize.isAccessibilitySize {
                return [GridItem(.flexible())]
            }
            if isWide {
                return [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)]
            }
            return [GridItem(.flexible()), GridItem(.flexible())]
        }()

        let isDegradationCalibrating = summary.degradationPer10kDistance(unit: unitSystem) == nil
        let isAnnualCalibrating = summary.degradationPerYear == nil

        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: columns,
                spacing: 16
            ) {
                StatCard(
                    title: "Degradation Rate",
                    value: summary.formattedDegradationRate(unit: unitSystem),
                    icon: "gauge.with.needle.fill",
                    color: .joulePositive,
                    valueColor: isDegradationCalibrating ? nil : .jouleDanger
                )
                
                StatCard(
                    title: "Annual Rate",
                    value: summary.degradationPerYear != nil
                        ? (summary.degradationPerYear! > 0.05
                            ? String(format: "%.2f%% / yr", summary.degradationPerYear!)
                            : "< 0.1% / yr")
                        : "Calibrating",
                    icon: "calendar.badge.clock",
                    color: .jouleInk2,
                    valueColor: isAnnualCalibrating ? nil : .jouleDanger
                )
                
                StatCard(
                    title: "Full Cycles (EFC)",
                    value: String(format: "%.1f cycles", summary.equivalentFullCycles),
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: .jouleInk2
                )
                
                StatCard(
                    title: "Projected 100% Range",
                    value: unitSystem.formatDistance(km: summary.currentProjectedRangeKm ?? summary.nominalRangeKm),
                    icon: "car.fill",
                    color: .joulePositive
                )
            }

            if isDegradationCalibrating || isAnnualCalibrating {
                calibrationExplanationView(summary: summary)
            }

            if let comparison = summary.referenceComparison {
                referenceExplanationView(comparison)
            }
        }
    }

    // MARK: - Calibration Explanation
    private func calibrationExplanationView(summary: BatteryHealthSummary) -> some View {
        let isDegradationCalibrating = summary.degradationPer10kDistance(unit: unitSystem) == nil
        let isAnnualCalibrating = summary.degradationPerYear == nil
        let distanceThreshold = unitSystem.formatDistance(km: 2500)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.joule(.body))
                .foregroundColor(.jouleInk2)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Why are rates calibrating?")
                    .font(.joule(.subheadline))
                    .fontWeight(.semibold)
                    .foregroundColor(.jouleInk)

                if isDegradationCalibrating && isAnnualCalibrating {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").bold()
                            Text("**Degradation Rate** requires at least 4 sessions with odometer readings spanning \(distanceThreshold) of driving.")
                        }
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").bold()
                            Text("**Annual Rate** requires at least 4 sessions spanning 60 days to calculate a yearly trend.")
                        }
                    }
                    .font(.joule(.caption))
                    .foregroundColor(.jouleMuted)
                } else if isDegradationCalibrating {
                    Text("**Degradation Rate** requires at least 4 sessions with odometer readings spanning \(distanceThreshold) of driving to establish a reliable distance-based trend.")
                        .font(.joule(.caption))
                        .foregroundColor(.jouleMuted)
                } else if isAnnualCalibrating {
                    Text("**Annual Rate** requires at least 60 days of charging history to compute a yearly degradation trend.")
                        .font(.joule(.caption))
                        .foregroundColor(.jouleMuted)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.jouleSunken.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Charts Section
    private func chartsSection(summary: BatteryHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            JouleSectionHeader("Deterioration Trends") {
                Menu {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(ChartTimeRange.allCases) { range in
                            Text(LocalizedStringKey(range.rawValue)).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey(selectedTimeRange.rawValue))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.jouleText(14, relativeTo: .subheadline).weight(.medium))
                    .foregroundStyle(Color.jouleInk)
                    .frame(minHeight: 44)
                }
            }

            JoulePillPicker(
                options: ChartMode.allCases.map { ($0, $0.title(unit: unitSystem)) },
                selection: $selectedChartMode,
                accessibilityTitle: "Mode"
            )
            
            Group {
                switch selectedChartMode {
                case .time:
                    sohOverTimeChart
                case .mileage:
                    sohVsMileageChart
                case .range:
                    rangeOverTimeChart(summary: summary)
                case .cycles:
                    cycleWearChart(summary: summary)
                }
            }
            .frame(minHeight: 260)
            .jouleCard(padding: 16)

            // The diamonds mean nothing without saying what they are.
            if selectedChartMode == .time && !filteredReferences.isEmpty {
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.jouleInk).frame(width: 7, height: 7)
                        Text("Joule estimate")
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.jouleReference)
                        Text("Service reading")
                    }
                    Spacer()
                }
                .font(.joule(.caption2))
                .foregroundColor(.jouleMuted)
            }
        }
    }
    
    // MARK: - Chart 1: SoH Over Time
    private var sohOverTimeChart: some View {
        let chart = Chart {
            // 100% Reference Baseline
            RuleMark(y: .value("100% Nominal", 100.0))
                .foregroundStyle(Color.jouleMuted.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("100% Factory")
                        .font(.joule(.caption2))
                        .foregroundColor(.jouleMuted)
                }
            
            // Raw Session Samples, each with the range its SoC readings actually support.
            ForEach(filteredPoints) { point in
                if point.sohUncertainty >= 1.0 {
                    RuleMark(
                        x: .value("Date", point.date),
                        yStart: .value("SoH low", point.stateOfHealth - point.sohUncertainty),
                        yEnd: .value("SoH high", point.stateOfHealth + point.sohUncertainty)
                    )
                    .foregroundStyle(pointColor(for: point.confidence).opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("SoH", point.stateOfHealth)
                )
                .foregroundStyle(pointColor(for: point.confidence))
                .symbolSize(point.confidence == .high ? 55 : (point.confidence == .medium ? 35 : 20))
            }
            
            // Smoothed Trend Line
            ForEach(trendPoints) { trend in
                LineMark(
                    x: .value("Date", trend.date),
                    y: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(Color.jouleInk)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
                
                AreaMark(
                    x: .value("Date", trend.date),
                    yStart: .value("Baseline", 80.0),
                    yEnd: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(Color.jouleAC.opacity(0.07))
                .interpolationMethod(.monotone)
            }

            // Externally measured readings, plotted as a distinct series against the trend.
            // Two visibly different sources that nearly agree read as corroboration; the same two
            // numbers shown on separate screens read as a bug.
            ForEach(filteredReferences) { reading in
                RuleMark(x: .value("Measured", reading.date))
                    .foregroundStyle(Color.jouleReference.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Measured", reading.date),
                    y: .value("SoH", reading.sohPercent)
                )
                .foregroundStyle(Color.jouleReference)
                .symbol(.diamond)
                .symbolSize(110)
                .annotation(position: .topTrailing, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                    Text(String(format: "%.0f%%", reading.sohPercent))
                        .font(.joule(.caption2))
                        .fontWeight(.bold)
                        .foregroundColor(.jouleReference)
                }
            }

            if let selPoint = selectedHealthPoint {
                RuleMark(x: .value("Selected Date", selPoint.date))
                    .foregroundStyle(Color.jouleMuted.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selPoint.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                    .font(.joule(.caption2))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.jouleMuted)
                                HStack(spacing: 5) {
                                    Circle().fill(pointColor(for: selPoint.confidence)).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", selPoint.stateOfHealth))
                                        .font(.joule(.subheadline))
                                        .fontWeight(.bold)
                                        .foregroundColor(.jouleInk)
                                }
                                Text(String(format: "%.1f kWh • %@", selPoint.estimatedCapacityKWh, selPoint.confidence.rawValue))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                                if selPoint.sohUncertainty >= 1.0 {
                                    Text(String(format: "± %.1f pts from SoC accuracy", selPoint.sohUncertainty))
                                        .font(.joule(.caption2))
                                        .foregroundColor(.jouleMuted)
                                }
                                if let trend = selectedHealthTrend {
                                    Text(String(format: "Trend: %.1f%%", trend.smoothedSoH))
                                        .font(.joule(.caption2))
                                        .foregroundColor(.jouleInk)
                                }
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Date", selPoint.date),
                    y: .value("SoH", selPoint.stateOfHealth)
                )
                .foregroundStyle(pointColor(for: selPoint.confidence))
                .symbolSize(90)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 80...105)
        .chartYAxis {
            AxisMarks(position: .leading, values: [80, 85, 90, 95, 100]) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisDate(date))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("State of Health Over Time")
        .accessibilityValue(summary != nil ? "Current SoH \(String(format: "%.1f%%", summary!.currentSoH)) across \(filteredPoints.count) analyzed points" : "Historical battery degradation curve")
        .accessibilityHint("Shows individual charging session estimates and smoothed trend line over time")

        return Group {
            if let domain = dateDomain {
                chart.chartXScale(domain: domain)
            } else {
                chart
            }
        }
    }
    
    // MARK: - Chart 2: SoH Vs Mileage
    private var sohVsMileageChart: some View {
        let mileagePoints = filteredPoints.filter { $0.mileage != nil }
        
        let chart = Chart {
            RuleMark(y: .value("100% Nominal", 100.0))
                .foregroundStyle(Color.jouleMuted.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            
            ForEach(mileagePoints) { point in
                PointMark(
                    x: .value("Mileage", unitSystem.convertFromKm(point.mileage!)),
                    y: .value("SoH", point.stateOfHealth)
                )
                .foregroundStyle(pointColor(for: point.confidence))
                .symbolSize(point.confidence == .high ? 55 : 35)
            }
            
            let sortedMileageTrend = trendPoints.filter { $0.mileage != nil }.sorted { ($0.mileage ?? 0) < ($1.mileage ?? 0) }
            ForEach(sortedMileageTrend) { trend in
                LineMark(
                    x: .value("Mileage", unitSystem.convertFromKm(trend.mileage!)),
                    y: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(Color.joulePositive)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Mileage", unitSystem.convertFromKm(trend.mileage!)),
                    yStart: .value("Baseline", 80.0),
                    yEnd: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(Color.jouleAC.opacity(0.07))
                .interpolationMethod(.monotone)
            }

            if let selPoint = selectedMileagePoint, let mileage = selPoint.mileage {
                let convertedMileage = unitSystem.convertFromKm(mileage)
                RuleMark(x: .value("Selected Mileage", convertedMileage))
                    .foregroundStyle(Color.jouleMuted.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(Int(convertedMileage.rounded())) \(unitSystem.distanceUnit)")
                                    .font(.joule(.caption2))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.jouleMuted)
                                HStack(spacing: 5) {
                                    Circle().fill(pointColor(for: selPoint.confidence)).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", selPoint.stateOfHealth))
                                        .font(.joule(.subheadline))
                                        .fontWeight(.bold)
                                        .foregroundColor(.jouleInk)
                                }
                                Text(String(format: "%.1f kWh • %@", selPoint.estimatedCapacityKWh, selPoint.confidence.rawValue))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                                if let trend = selectedMileageTrend {
                                    Text(String(format: "Trend: %.1f%%", trend.smoothedSoH))
                                        .font(.joule(.caption2))
                                        .foregroundColor(.joulePositive)
                                }
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Mileage", convertedMileage),
                    y: .value("SoH", selPoint.stateOfHealth)
                )
                .foregroundStyle(pointColor(for: selPoint.confidence))
                .symbolSize(90)
            }
        }
        .chartXSelection(value: $selectedMileage)
        .chartYScale(domain: 80...105)
        .chartYAxis {
            AxisMarks(position: .leading, values: [80, 85, 90, 95, 100]) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(formatMileageAxis(d))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("State of Health Versus Mileage")
        .accessibilityValue(summary?.degradationPer10kDistance(unit: unitSystem) != nil ? "Degradation rate \(String(format: "%.2f%% per %@", summary!.degradationPer10kDistance(unit: unitSystem)!, unitSystem.degradationDistanceDescription))" : "Plot of battery health versus odometer distance")
        .accessibilityHint("Plots capacity retention against distance driven in thousands of \(unitSystem.distanceUnitLong.lowercased())")

        return Group {
            if let domain = mileageDomain {
                chart.chartXScale(domain: domain)
            } else {
                chart
            }
        }
    }
    
    // MARK: - Chart 3: Projected Range Over Time
    private func rangeOverTimeChart(summary: BatteryHealthSummary) -> some View {
        let rangePoints = filteredPoints.filter { $0.projectedFullRangeKm != nil }
        let nominalConverted = unitSystem.convertFromKm(summary.nominalRangeKm)
        let minBound = max(unitSystem.convertFromKm(50.0), nominalConverted * 0.75)
        let maxBound = nominalConverted * 1.15
        let standardTag = VehicleProfile.rangeStandard.rawValue
        
        let chart = Chart {
            RuleMark(y: .value("Rated Range", nominalConverted))
                .foregroundStyle(Color.joulePositive.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Factory \(Int(nominalConverted)) \(unitSystem.distanceUnit) (\(standardTag))")
                        .font(.joule(.caption2))
                        .foregroundColor(.joulePositive)
                }
            
            ForEach(rangePoints) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Range", unitSystem.convertFromKm(point.projectedFullRangeKm!))
                )
                .foregroundStyle(Color.joulePositive.opacity(0.7))
                .symbolSize(35)
            }
            
            let validTrend = trendPoints.filter { $0.projectedFullRangeKm != nil }
            ForEach(validTrend) { trend in
                LineMark(
                    x: .value("Date", trend.date),
                    y: .value("Range", unitSystem.convertFromKm(trend.projectedFullRangeKm!))
                )
                .foregroundStyle(Color.joulePositive)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Date", trend.date),
                    yStart: .value("Baseline", minBound),
                    yEnd: .value("Range", unitSystem.convertFromKm(trend.projectedFullRangeKm!))
                )
                .foregroundStyle(Color.jouleAC.opacity(0.07))
                .interpolationMethod(.monotone)
            }

            if let selPoint = selectedRangePoint, let rangeKm = selPoint.projectedFullRangeKm {
                let convertedRange = unitSystem.convertFromKm(rangeKm)
                RuleMark(x: .value("Selected Date", selPoint.date))
                    .foregroundStyle(Color.jouleMuted.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selPoint.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                    .font(.joule(.caption2))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.jouleMuted)
                                HStack(spacing: 5) {
                                    Circle().fill(Color.joulePositive).frame(width: 7, height: 7)
                                    Text("\(Int(convertedRange.rounded())) \(unitSystem.distanceUnit)")
                                        .font(.joule(.subheadline))
                                        .fontWeight(.bold)
                                        .foregroundColor(.jouleInk)
                                }
                                let diff = Int(convertedRange.rounded() - nominalConverted.rounded())
                                Text(String(format: "%+d %@ vs rated", diff, unitSystem.distanceUnit))
                                    .font(.joule(.caption2))
                                    .foregroundColor(diff < 0 ? .jouleDeferred : .jouleMuted)
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Date", selPoint.date),
                    y: .value("Range", convertedRange)
                )
                .foregroundStyle(Color.joulePositive)
                .symbolSize(90)
            }
        }
        .chartXSelection(value: $selectedRangeDate)
        .chartYScale(domain: minBound...maxBound)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal) \(unitSystem.distanceUnit)")
                    } else if let dVal = value.as(Double.self) {
                        Text("\(Int(dVal)) \(unitSystem.distanceUnit)")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisDate(date))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Projected 100% Driving Range Over Time")
        .accessibilityValue("Estimated full range \(unitSystem.formatDistance(km: summary.currentProjectedRangeKm ?? summary.nominalRangeKm)) compared to nominal \(unitSystem.formatDistance(km: summary.nominalRangeKm))")
        .accessibilityHint("Tracks estimated driving range on full charge over time")

        return Group {
            if let domain = dateDomain {
                chart.chartXScale(domain: domain)
            } else {
                chart
            }
        }
    }
    
    // MARK: - Chart 4: Cycle Wear vs Theoretical Life
    private func cycleWearChart(summary: BatteryHealthSummary) -> some View {
        let maxCycles = max(300.0, summary.equivalentFullCycles * 2.5)
        let sampleSteps = stride(from: 0.0, through: maxCycles, by: maxCycles / 20.0)
        let benchmarkCycleLife = targetVehicle.cycleLifeTo80
        let chemistryName = targetVehicle.chemistry.rawValue
        let benchmarkLabel = "\(chemistryName) Benchmark (\(Int(benchmarkCycleLife)) cyc)"
        
        return Chart {
            // Theoretical Degradation Curve (80% retention at expected cycle life)
            ForEach(Array(sampleSteps), id: \.self) { cycle in
                let theoreticalSoH = 100.0 - (20.0 * (cycle / benchmarkCycleLife))
                LineMark(
                    x: .value("Cycles", cycle),
                    y: .value("Theoretical SoH", theoreticalSoH)
                )
                .foregroundStyle(by: .value("Type", benchmarkLabel))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                AreaMark(
                    x: .value("Cycles", cycle),
                    yStart: .value("Baseline", 80.0),
                    yEnd: .value("Theoretical SoH", theoreticalSoH)
                )
                .foregroundStyle(Color.jouleAC.opacity(0.07))
            }
            
            // Actual Measured Position
            PointMark(
                x: .value("Cycles", summary.equivalentFullCycles),
                y: .value("Actual SoH", summary.currentSoH)
            )
            .foregroundStyle(by: .value("Type", "Your Vehicle"))
            .symbolSize(120)

            if let cycle = selectedCycle {
                let isNearVehicle = abs(cycle - summary.equivalentFullCycles) < (maxCycles * 0.08)
                let xPos = isNearVehicle ? summary.equivalentFullCycles : cycle
                let theoreticalSoH = max(0, 100.0 - (20.0 * (xPos / benchmarkCycleLife)))
                let yVal = isNearVehicle ? summary.currentSoH : theoreticalSoH

                RuleMark(x: .value("Selected Cycles", xPos))
                    .foregroundStyle(Color.jouleMuted.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isNearVehicle ? "Your Vehicle" : "\(chemistryName) Benchmark")
                                    .font(.joule(.caption2))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.jouleMuted)
                                HStack(spacing: 5) {
                                    Circle().fill(isNearVehicle ? Color.jouleInk : Color.jouleMuted).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", yVal))
                                        .font(.joule(.subheadline))
                                        .fontWeight(.bold)
                                        .foregroundColor(.jouleInk)
                                }
                                Text(String(format: "%.1f Full Cycles", xPos))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                                if isNearVehicle {
                                    let diff = summary.currentSoH - theoreticalSoH
                                    Text(String(format: "%+.1f%% vs benchmark", diff))
                                        .font(.joule(.caption2))
                                        .foregroundColor(diff >= 0 ? .joulePositive : .jouleDeferred)
                                }
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Cycles", xPos),
                    y: .value("Actual SoH", yVal)
                )
                .foregroundStyle(isNearVehicle ? Color.jouleInk : Color.jouleMuted)
                .symbolSize(80)
            }
        }
        .chartXSelection(value: $selectedCycle)
        .chartForegroundStyleScale([
            "Your Vehicle": Color.jouleAC,
            benchmarkLabel: Color.jouleMuted
        ])
        .chartYScale(domain: 80...105)
        .chartYAxis {
            AxisMarks(position: .leading, values: [80, 90, 100]) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.jouleLine)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d.rounded())) cyc")
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle Wear Versus Chemistry Benchmark")
        .accessibilityValue("\(String(format: "%.1f", summary.equivalentFullCycles)) full cycles completed, current SoH \(String(format: "%.1f%%", summary.currentSoH))")
        .accessibilityHint("Compares actual vehicle degradation against standard \(chemistryName) laboratory cycle wear curve")
    }
    
    // MARK: - Charging Habits & Longevity Analysis Section
    private func chargingHabitsSection(summary: BatteryHealthSummary) -> some View {
        let analysis = behaviorAnalysis

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Charging Behavior & Battery Care")
                        .font(.joule(.title2))
                        .accessibilityAddTraits(.isHeader)
                    Text("Habit review and longevity impact for \(targetVehicle.name)")
                        .font(.joule(.caption))
                        .foregroundColor(.jouleMuted)
                }
                Spacer()
                Button {
                    showingBestPracticesSheet = true
                } label: {
                    Label("Best Practices", systemImage: "book.closed.fill")
                        .font(.joule(.caption))
                        .fontWeight(.semibold)
                }
                .buttonStyle(JouleOutlineButtonStyle())
                .accessibilityLabel("Open EV Battery Charging Best Practices Guide")
            }
            
            VStack(spacing: 16) {
                // Behavior Hero Card with Grade & Longevity Score
                behaviorHeroCard(analysis: analysis)

                // 4-Dimension Sub-Score Grid
                behaviorDimensionsGrid(analysis: analysis)

                // Actionable Personalized Recommendations
                if !analysis.recommendations.isEmpty {
                    recommendationsCard(analysis: analysis)
                }

                // Dynamic Battery Chemistry Tip
                chemistryTipCard
            }
        }
    }

    // MARK: - Behavior Hero Card
    private func behaviorHeroCard(analysis: ChargingBehaviorAnalysis) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(analysis.grade.rawValue)
                            .font(.jouleDisplay(24))
                            .foregroundColor(.jouleOnVolt)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.jouleVolt)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Image(systemName: analysis.assessment.icon)
                                    .font(.joule(.caption))
                                    .foregroundColor(analysis.grade.color)
                                Text(LocalizedStringKey(analysis.assessment.rawValue))
                                    .font(.joule(.subheadline))
                                    .fontWeight(.bold)
                                    .foregroundColor(analysis.grade.color)
                            }
                            Text(LocalizedStringKey(analysis.grade.title))
                                .font(.joule(.caption2))
                                .foregroundColor(.jouleMuted)
                        }
                    }

                    Text(LocalizedStringKey(analysis.summaryText))
                        .font(.joule(.subheadline))
                        .foregroundColor(.jouleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Circular Behavior Score Gauge
                ZStack {
                    Circle()
                        .stroke(Color.jouleSunken, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, analysis.overallScore / 100.0)))
                        .stroke(
                            Color.jouleInk,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("\(Int(analysis.overallScore.rounded()))")
                            .font(.jouleDisplay(24))
                            .foregroundColor(.jouleInk)
                        Text("/ 100")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.jouleMuted)
                    }
                }
                .frame(width: 76, height: 76)
            }
        }
        .padding(18)
        .jouleCard(padding: nil, radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Charging Behavior Score: \(Int(analysis.overallScore)) out of 100, Grade \(analysis.grade.rawValue), \(analysis.assessment.rawValue). \(analysis.summaryText)")
    }

    // MARK: - Behavior Dimensions Grid
    private func behaviorDimensionsGrid(analysis: ChargingBehaviorAnalysis) -> some View {
        let columns: [GridItem] = {
            if dynamicTypeSize.isAccessibilitySize {
                return [GridItem(.flexible())]
            }
            if isWide {
                return [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)]
            }
            return [GridItem(.flexible()), GridItem(.flexible())]
        }()

        let m = analysis.metrics

        return LazyVGrid(columns: columns, spacing: 14) {
            // Dimension 1: Speed Balance
            dimensionTile(
                title: "Speed Balance",
                score: analysis.speedBalanceScore,
                icon: "bolt.fill",
                color: .jouleInk,
                detail: String(format: "%.0f%% AC / %.0f%% DC", m.acEnergyRatio * 100, m.dcEnergyRatio * 100),
                progress: m.acEnergyRatio,
                progressColor: .jouleInk
            )

            // Dimension 2: Target SoC Control
            let targetDetail: String = {
                if targetVehicle.chemistry == .lfp {
                    if let days = m.daysSinceLastFullCharge {
                        return "\(days)d since 100%"
                    } else {
                        return m.sessionsEndingAt100Count > 0 ? "100% Calibrated" : "Needs 100%"
                    }
                } else {
                    return String(format: "%.0f%% <= 90%% limit", (1.0 - m.sessionsEndingAbove85Percentage) * 100)
                }
            }()
            dimensionTile(
                title: targetVehicle.chemistry == .lfp ? "100% Calibration" : "Daily SoC Ceiling",
                score: analysis.targetSoCScore,
                icon: "battery.100.bolt",
                color: targetVehicle.chemistry == .lfp ? .joulePositive : .jouleInk2,
                detail: targetDetail,
                progress: analysis.targetSoCScore / 100.0,
                progressColor: targetVehicle.chemistry == .lfp ? .joulePositive : .jouleInk2
            )

            // Dimension 3: Low-SoC Buffer
            let bufferDetail = m.averageStartSoC != nil
                ? String(format: "Avg start: %.0f%%", m.averageStartSoC!)
                : (m.sessionsStartingBelow15Count == 0 ? "Protected (>15%)" : "\(m.sessionsStartingBelow15Count) low starts")
            dimensionTile(
                title: "Discharge Floor",
                score: analysis.dischargeBufferScore,
                icon: "battery.25",
                color: .jouleDeferred,
                detail: bufferDetail,
                progress: analysis.dischargeBufferScore / 100.0,
                progressColor: .jouleDeferred
            )

            // Dimension 4: Cycle Consistency
            let cycleDetail = m.averageDeltaSoC != nil
                ? String(format: "Avg DoD: Δ%.0f%%", m.averageDeltaSoC!)
                : "Consistent cycles"
            dimensionTile(
                title: "Cycle Regularity",
                score: analysis.cycleConsistencyScore,
                icon: "arrow.triangle.2.circlepath.circle.fill",
                color: .joulePositive,
                detail: cycleDetail,
                progress: analysis.cycleConsistencyScore / 100.0,
                progressColor: .joulePositive
            )
        }
    }

    private func dimensionTile(
        title: LocalizedStringKey,
        score: Double,
        icon: String,
        color: Color,
        detail: String,
        progress: Double,
        progressColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.joule(.caption))
                    .foregroundColor(color)
                Text(title)
                    .font(.joule(.caption))
                    .fontWeight(.medium)
                    .foregroundColor(.jouleMuted)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(score.rounded()))%")
                    .font(.joule(.caption))
                    .fontWeight(.bold)
                    .foregroundColor(score >= 80 ? .jouleInk : .jouleDeferred)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.jouleSunken)
                        .frame(height: 6)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, progress)))), height: 6)
                }
            }
            .frame(height: 6)

            Text(detail)
                .font(.joule(.caption2))
                .foregroundColor(.jouleMuted)
                .lineLimit(1)
        }
        .padding(12)
        .jouleCard(padding: nil, radius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(score)) percent, \(detail)")
    }

    // MARK: - Recommendations Card
    private func recommendationsCard(analysis: ChargingBehaviorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actionable Recommendations", systemImage: "sparkles")
                    .font(.joule(.headline))
                Spacer()
                Text(String(format: String(localized: "%lld tips"), Int64(analysis.recommendations.count)))
                    .font(.joule(.caption2))
                    .foregroundColor(.jouleMuted)
            }

            VStack(spacing: 10) {
                ForEach(analysis.recommendations) { rec in
                    recommendationRow(rec: rec)
                }
            }
        }
        .padding(16)
        .jouleCard(padding: nil, radius: 18)
    }

    private func recommendationRow(rec: ChargingRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rec.level.icon)
                .font(.joule(.body))
                .foregroundColor(rec.level.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(rec.title))
                        .font(.joule(.subheadline))
                        .fontWeight(.bold)
                        .foregroundColor(.jouleInk)
                    Spacer()
                    Text(LocalizedStringKey(rec.observedMetricFormatted))
                        .font(.joule(.caption2))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rec.level.color.opacity(0.12))
                        .foregroundColor(rec.level.color)
                        .clipShape(Capsule())
                }

                Text(LocalizedStringKey(rec.summary))
                    .font(.joule(.caption))
                    .foregroundColor(.jouleMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                        .font(.joule(.caption))
                        .fontWeight(.bold)
                        .foregroundColor(rec.level.color)
                    Text(LocalizedStringKey(rec.actionableAdvice))
                        .font(.joule(.caption))
                        .fontWeight(.medium)
                        .foregroundColor(.jouleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(rec.level.color.opacity(0.06))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rec.title), \(rec.level.rawValue): \(rec.summary). Action: \(rec.actionableAdvice)")
    }

    // MARK: - Chemistry Tip Card
    private var chemistryTipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.jouleDeferred)
                .font(.joule(.title3))

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "%1$@ (%2$@) Battery Care"), targetVehicle.name, targetVehicle.chemistry.rawValue))
                    .font(.joule(.subheadline)).bold()
                Text(LocalizedStringKey(targetVehicle.batteryCareTip))
                    .font(.joule(.caption))
                    .foregroundColor(.jouleMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.jouleDeferred.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(targetVehicle.name) \(targetVehicle.chemistry.rawValue) battery care tip: \(targetVehicle.batteryCareTip)")
    }
    
    // MARK: - Recent Estimates Section
    private var recentEstimatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Capacity Calculations")
                    .font(.joule(.title2))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(String(format: String(localized: "%lld sessions analyzed"), Int64(allPoints.count)))
                    .font(.joule(.caption))
                    .foregroundColor(.jouleMuted)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(allPoints.suffix(5).reversed().enumerated()), id: \.element.id) { index, point in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(point.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.joule(.subheadline)).bold()
                                
                                Text(point.chargingType.rawValue)
                                    .font(.joule(.caption2)).bold()
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background((point.chargingType == .dc ? Color.jouleDC : Color.jouleAC).opacity(0.15))
                                    .foregroundColor(point.chargingType == .dc ? .jouleDC : .jouleAC)
                                    .clipShape(Capsule())
                            }
                            
                            Text(String(format: "SoC: %.0f%% → %.0f%% (Δ%.0f%%) • %.1f kWh added", point.startSoC, point.endSoC, point.socDelta, point.energyAdded))
                                .font(.joule(.caption))
                                .foregroundColor(.jouleMuted)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f kWh", point.estimatedCapacityKWh))
                                .font(.joule(.headline))
                                .foregroundColor(.jouleInk)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(pointColor(for: point.confidence))
                                    .frame(width: 6, height: 6)
                                Text(String(format: "%.1f%% SoH", point.stateOfHealth))
                                    .font(.joule(.caption))
                                    .bold()
                                    .foregroundColor(pointColor(for: point.confidence))
                            }
                            
                            // A shallow charge can only pin SoH to within several points. Printing
                            // one decimal and nothing else invites the reader to believe it.
                            if point.sohUncertainty >= 1.0 {
                                Text(String(format: "± %.1f pts", point.sohUncertainty))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                            }
                        }
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(point.date.formatted(.dateTime.month(.abbreviated).day().year())), \(point.chargingType.rawValue) session")
                    .accessibilityValue("SoC changed from \(Int(point.startSoC))% to \(Int(point.endSoC))%, \(String(format: "%.1f kWh", point.energyAdded)) added. Estimated pack capacity \(String(format: "%.1f kWh", point.estimatedCapacityKWh)), \(String(format: "%.1f%%", point.stateOfHealth)) State of Health, \(point.confidence.description) confidence")
                }
            }
            .jouleCard(padding: nil, radius: 14)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 48))
                .foregroundColor(.jouleInk)
                .padding(.top, 40)
            
            Text("Insufficient Data for Battery Health")
                .font(.joule(.title3)).bold()
            
            Text("Log charging sessions with both Start SoC and End SoC to enable capacity estimation and degradation tracking.")
                .font(.joule(.subheadline))
                .foregroundColor(.jouleMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Helpers
    private func pointColor(for confidence: BatteryHealthConfidence) -> Color {
        switch confidence {
        case .high: return .joulePositive
        case .medium: return .jouleInk
        case .low: return .jouleDeferred
        case .unreliable: return .jouleMuted.opacity(0.5)
        }
    }
    
    private func assessmentColor(_ assessment: BatteryHealthSummary.BatteryAssessment) -> Color {
        switch assessment {
        case .excellent, .good: return .joulePositive
        case .normal: return .jouleInk
        case .degraded: return .jouleDeferred
        }
    }
}

// MARK: - Charging Best Practices Guide Sheet
struct ChargingBestPracticesSheet: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: PracticeFilter = .forVehicle

    enum PracticeFilter: String, CaseIterable, Identifiable {
        case forVehicle = "My Vehicle"
        case all = "All Guides"
        case lfp = "LFP"
        case nmc = "NMC / NCA"

        var id: String { rawValue }
    }

    private var filteredPractices: [ChargingBestPracticeItem] {
        ChargingBestPracticeItem.universalBestPractices.filter { item in
            switch selectedFilter {
            case .forVehicle:
                if vehicle.chemistry == .lfp {
                    return item.chemistryApplicability != .nmcNcaOnly
                } else if vehicle.chemistry == .nmc || vehicle.chemistry == .nca {
                    return item.chemistryApplicability != .lfpOnly
                } else {
                    return true
                }
            case .all:
                return true
            case .lfp:
                return item.chemistryApplicability == .lfpOnly || item.chemistryApplicability == .all
            case .nmc:
                return item.chemistryApplicability == .nmcNcaOnly || item.chemistryApplicability == .all
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.joule(.title3))
                                .foregroundColor(.jouleDeferred)
                            Text("Battery Longevity Principles")
                                .font(.joule(.title3))
                                .fontWeight(.bold)
                        }

                        Text("EV battery degradation is driven by four primary stressors: high cell temperature, extreme State of Charge (>90% or <10%), high charging current (DC fast charge C-rate), and time spent at high voltage. Follow these proven practices to maximize pack life and resale value.")
                            .font(.joule(.subheadline))
                            .foregroundColor(.jouleMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.jouleInk.opacity(0.08))
                    .cornerRadius(14)

                    // Active Vehicle Chemistry Callout
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "car.side.fill")
                            .font(.joule(.title3))
                            .foregroundColor(.jouleInk)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(vehicle.name)
                                    .font(.joule(.subheadline))
                                    .fontWeight(.bold)
                                Text(LocalizedStringKey(vehicle.chemistry.fullName))
                                    .font(.joule(.caption2))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.jouleInk.opacity(0.15))
                                    .foregroundColor(.jouleInk)
                                    .clipShape(Capsule())
                            }

                            Text(LocalizedStringKey(vehicle.batteryCareTip))
                                .font(.joule(.caption))
                                .foregroundColor(.jouleMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .jouleCard(padding: nil, radius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.jouleInk.opacity(0.2), lineWidth: 1)
                    )

                    // Filter Picker
                    Picker("Filter Practices", selection: $selectedFilter) {
                        ForEach(PracticeFilter.allCases) { filter in
                            Text(LocalizedStringKey(filter.rawValue)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Practices List
                    VStack(spacing: 16) {
                        ForEach(filteredPractices) { practice in
                            practiceCard(practice)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Charging Best Practices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func practiceCard(_ practice: ChargingBestPracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: practice.icon)
                    .font(.joule(.title2))
                    .foregroundColor(practice.color)
                    .frame(width: 32, height: 32)
                    .background(practice.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(LocalizedStringKey(practice.category))
                            .font(.joule(.caption2))
                            .fontWeight(.bold)
                            .foregroundColor(practice.color)
                            .textCase(.uppercase)

                        Spacer()

                        Text(LocalizedStringKey(practice.chemistryApplicability.rawValue))
                            .font(.joule(.caption2))
                            .foregroundColor(.jouleMuted)
                    }

                    Text(LocalizedStringKey(practice.title))
                        .font(.joule(.headline))
                        .foregroundColor(.jouleInk)
                }
            }

            Text(LocalizedStringKey(practice.summary))
                .font(.joule(.subheadline))
                .foregroundColor(.jouleMuted)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(practice.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.joule(.caption))
                            .foregroundColor(practice.color)
                            .padding(.top, 2)
                        Text(LocalizedStringKey(bullet))
                            .font(.joule(.caption))
                            .foregroundColor(.jouleInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .jouleCard(padding: nil, radius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(practice.title): \(practice.summary)")
    }
}
