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
        
        func title(unit: UnitSystem) -> String {
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
        let dates = filteredPoints.map(\.date)
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
        service.calculateSummary(from: vehicleSessions)
    }

    private var behaviorAnalysis: ChargingBehaviorAnalysis {
        ChargingBehaviorService.analyze(sessions: vehicleSessions, vehicle: targetVehicle)
    }
    
    @State private var showingSettings = false
    @State private var showingBestPracticesSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let summary = summary, !allPoints.isEmpty {
                    heroCard(summary: summary)
                    metricsGrid(summary: summary)
                    chartsSection(summary: summary)
                    chargingHabitsSection(summary: summary)
                    recentEstimatesSection
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
            .frame(maxWidth: isWide ? 1100 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Battery Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                GarageSwitcherMenu(allowAllOption: false)
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
        .sheet(isPresented: $showingBestPracticesSheet) {
            ChargingBestPracticesSheet(vehicle: targetVehicle)
        }
    }
    
    // MARK: - Hero Card
    private func heroCard(summary: BatteryHealthSummary) -> some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    heroTextContent(summary: summary)
                    Spacer()
                    circularCapacityGauge(summary: summary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    heroTextContent(summary: summary)
                    HStack {
                        Spacer()
                        circularCapacityGauge(summary: summary)
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining Usable Capacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f / %.1f kWh", summary.currentCapacityKWh, summary.nominalCapacityKWh))
                        .font(.subheadline).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Capacity Loss")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "-%.1f kWh (-%.1f%%)", summary.capacityLostKWh, summary.totalDegradationPercentage))
                        .font(.subheadline).bold()
                        .foregroundColor(summary.capacityLostKWh > 0.5 ? .orange : .secondary)
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        // A hairline shadow disappears against a dark background, so lean on a deeper one there to
        // keep the card lifted off the grouped backdrop.
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, x: 0, y: 3)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery State of Health: \(String(format: "%.1f%%", summary.currentSoH)), \(summary.assessment.title)")
        .accessibilityValue("Usable capacity: \(String(format: "%.1f", summary.currentCapacityKWh)) of \(String(format: "%.1f", summary.nominalCapacityKWh)) kilowatt-hours nominal. Capacity loss: \(String(format: "%.1f", summary.capacityLostKWh)) kilowatt-hours (\(String(format: "%.1f%%", summary.totalDegradationPercentage)))")
    }

    private func heroTextContent(summary: BatteryHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: summary.assessment.icon)
                    .foregroundColor(assessmentColor(summary.assessment))
                Text(summary.assessment.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(assessmentColor(summary.assessment))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(assessmentColor(summary.assessment).opacity(0.12))
            .clipShape(Capsule())
            
            Text(String(format: "%.1f%%", summary.currentSoH))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Estimated State of Health (SoH)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func circularCapacityGauge(summary: BatteryHealthSummary) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, summary.currentSoH / 100.0)))
                .stroke(
                    LinearGradient(
                        colors: [assessmentColor(summary.assessment), .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 2) {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(String(format: "%.1f", summary.currentCapacityKWh))
                    .font(.headline)
                    .bold()
                Text("kWh")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)
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
                    color: .mint
                )
                
                StatCard(
                    title: "Annual Rate",
                    value: summary.degradationPerYear != nil
                        ? (summary.degradationPerYear! > 0.05
                            ? String(format: "-%.2f%% / yr", summary.degradationPerYear!)
                            : "< 0.1% / yr")
                        : "Calibrating",
                    icon: "calendar.badge.clock",
                    color: .cyan
                )
                
                StatCard(
                    title: "Full Cycles (EFC)",
                    value: String(format: "%.1f cycles", summary.equivalentFullCycles),
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Projected 100% Range",
                    value: unitSystem.formatDistance(km: summary.currentProjectedRangeKm ?? summary.nominalRangeKm),
                    icon: "car.fill",
                    color: .green
                )
            }

            if isDegradationCalibrating || isAnnualCalibrating {
                calibrationExplanationView(summary: summary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calibration Explanation
    private func calibrationExplanationView(summary: BatteryHealthSummary) -> some View {
        let isDegradationCalibrating = summary.degradationPer10kDistance(unit: unitSystem) == nil
        let isAnnualCalibrating = summary.degradationPerYear == nil
        let distanceThreshold = unitSystem.formatDistance(km: 2500)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundColor(.cyan)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Why are rates calibrating?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

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
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else if isDegradationCalibrating {
                    Text("**Degradation Rate** requires at least 4 sessions with odometer readings spanning \(distanceThreshold) of driving to establish a reliable distance-based trend.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if isAnnualCalibrating {
                    Text("**Annual Rate** requires at least 60 days of charging history to compute a yearly degradation trend.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.cyan.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Charts Section
    private func chartsSection(summary: BatteryHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Deterioration Trends")
                    .font(.title2).bold()
                Spacer()
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(ChartTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
            
            Picker("Mode", selection: $selectedChartMode) {
                ForEach(ChartMode.allCases) { mode in
                    Text(mode.title(unit: unitSystem)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
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
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Chart 1: SoH Over Time
    private var sohOverTimeChart: some View {
        let chart = Chart {
            // 100% Reference Baseline
            RuleMark(y: .value("100% Nominal", 100.0))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("100% Factory")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            
            // Raw Session Samples
            ForEach(filteredPoints) { point in
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
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
                
                AreaMark(
                    x: .value("Date", trend.date),
                    yStart: .value("Baseline", 80.0),
                    yEnd: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if let selPoint = selectedHealthPoint {
                RuleMark(x: .value("Selected Date", selPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selPoint.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 5) {
                                    Circle().fill(pointColor(for: selPoint.confidence)).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", selPoint.stateOfHealth))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                Text(String(format: "%.1f kWh • %@", selPoint.estimatedCapacityKWh, selPoint.confidence.rawValue))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if let trend = selectedHealthTrend {
                                    Text(String(format: "Trend: %.1f%%", trend.smoothedSoH))
                                        .font(.caption2)
                                        .foregroundColor(.blue)
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
                AxisGridLine()
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
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
                .foregroundStyle(Color.secondary.opacity(0.4))
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
                .foregroundStyle(.mint)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Mileage", unitSystem.convertFromKm(trend.mileage!)),
                    yStart: .value("Baseline", 80.0),
                    yEnd: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.2), Color.mint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if let selPoint = selectedMileagePoint, let mileage = selPoint.mileage {
                let convertedMileage = unitSystem.convertFromKm(mileage)
                RuleMark(x: .value("Selected Mileage", convertedMileage))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(Int(convertedMileage.rounded())) \(unitSystem.distanceUnit)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 5) {
                                    Circle().fill(pointColor(for: selPoint.confidence)).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", selPoint.stateOfHealth))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                Text(String(format: "%.1f kWh • %@", selPoint.estimatedCapacityKWh, selPoint.confidence.rawValue))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if let trend = selectedMileageTrend {
                                    Text(String(format: "Trend: %.1f%%", trend.smoothedSoH))
                                        .font(.caption2)
                                        .foregroundColor(.mint)
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
                AxisGridLine()
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
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
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Factory \(Int(nominalConverted)) \(unitSystem.distanceUnit) (\(standardTag))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            
            ForEach(rangePoints) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Range", unitSystem.convertFromKm(point.projectedFullRangeKm!))
                )
                .foregroundStyle(.green.opacity(0.7))
                .symbolSize(35)
            }
            
            let validTrend = trendPoints.filter { $0.projectedFullRangeKm != nil }
            ForEach(validTrend) { trend in
                LineMark(
                    x: .value("Date", trend.date),
                    y: .value("Range", unitSystem.convertFromKm(trend.projectedFullRangeKm!))
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Date", trend.date),
                    yStart: .value("Baseline", minBound),
                    yEnd: .value("Range", unitSystem.convertFromKm(trend.projectedFullRangeKm!))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.green.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if let selPoint = selectedRangePoint, let rangeKm = selPoint.projectedFullRangeKm {
                let convertedRange = unitSystem.convertFromKm(rangeKm)
                RuleMark(x: .value("Selected Date", selPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selPoint.date.formatted(.dateTime.year().month(.abbreviated).day()))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 5) {
                                    Circle().fill(Color.green).frame(width: 7, height: 7)
                                    Text("\(Int(convertedRange.rounded())) \(unitSystem.distanceUnit)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                let diff = Int(convertedRange.rounded() - nominalConverted.rounded())
                                Text(String(format: "%+d %@ vs rated", diff, unitSystem.distanceUnit))
                                    .font(.caption2)
                                    .foregroundColor(diff < 0 ? .orange : .secondary)
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Date", selPoint.date),
                    y: .value("Range", convertedRange)
                )
                .foregroundStyle(.green)
                .symbolSize(90)
            }
        }
        .chartXSelection(value: $selectedRangeDate)
        .chartYScale(domain: minBound...maxBound)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
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
                AxisGridLine()
                AxisTick()
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(yStart: -10)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltipCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isNearVehicle ? "Your Vehicle" : "\(chemistryName) Benchmark")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 5) {
                                    Circle().fill(isNearVehicle ? Color.blue : Color.secondary).frame(width: 7, height: 7)
                                    Text(String(format: "%.1f%% SoH", yVal))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                Text(String(format: "%.1f Full Cycles", xPos))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if isNearVehicle {
                                    let diff = summary.currentSoH - theoreticalSoH
                                    Text(String(format: "%+.1f%% vs benchmark", diff))
                                        .font(.caption2)
                                        .foregroundColor(diff >= 0 ? .green : .orange)
                                }
                            }
                        }
                    }

                PointMark(
                    x: .value("Selected Cycles", xPos),
                    y: .value("Actual SoH", yVal)
                )
                .foregroundStyle(isNearVehicle ? Color.blue : Color.secondary)
                .symbolSize(80)
            }
        }
        .chartXSelection(value: $selectedCycle)
        .chartForegroundStyleScale([
            "Your Vehicle": Color.blue,
            benchmarkLabel: Color.secondary
        ])
        .chartYScale(domain: 80...105)
        .chartYAxis {
            AxisMarks(position: .leading, values: [80, 90, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
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
                        .font(.title2).bold()
                    Text("Habit review and longevity impact for \(targetVehicle.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    showingBestPracticesSheet = true
                } label: {
                    Label("Best Practices", systemImage: "book.closed.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.blue)
                .accessibilityLabel("Open EV Battery Charging Best Practices Guide")
            }
            .padding(.horizontal)
            
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
            .padding(.horizontal)
        }
    }

    // MARK: - Behavior Hero Card
    private func behaviorHeroCard(analysis: ChargingBehaviorAnalysis) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(analysis.grade.rawValue)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(analysis.grade.color)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Image(systemName: analysis.assessment.icon)
                                    .font(.caption)
                                    .foregroundColor(analysis.grade.color)
                                Text(analysis.assessment.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(analysis.grade.color)
                            }
                            Text(analysis.grade.title)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(analysis.summaryText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Circular Behavior Score Gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, analysis.overallScore / 100.0)))
                        .stroke(
                            LinearGradient(
                                colors: [analysis.grade.color, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("\(Int(analysis.overallScore.rounded()))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("/ 100")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 76, height: 76)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, x: 0, y: 3)
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
                color: .blue,
                detail: String(format: "%.0f%% AC / %.0f%% DC", m.acEnergyRatio * 100, m.dcEnergyRatio * 100),
                progress: m.acEnergyRatio,
                progressColor: .blue
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
                color: targetVehicle.chemistry == .lfp ? .green : .purple,
                detail: targetDetail,
                progress: analysis.targetSoCScore / 100.0,
                progressColor: targetVehicle.chemistry == .lfp ? .green : .purple
            )

            // Dimension 3: Low-SoC Buffer
            let bufferDetail = m.averageStartSoC != nil
                ? String(format: "Avg start: %.0f%%", m.averageStartSoC!)
                : (m.sessionsStartingBelow15Count == 0 ? "Protected (>15%)" : "\(m.sessionsStartingBelow15Count) low starts")
            dimensionTile(
                title: "Discharge Floor",
                score: analysis.dischargeBufferScore,
                icon: "battery.25",
                color: .orange,
                detail: bufferDetail,
                progress: analysis.dischargeBufferScore / 100.0,
                progressColor: .orange
            )

            // Dimension 4: Cycle Consistency
            let cycleDetail = m.averageDeltaSoC != nil
                ? String(format: "Avg DoD: Δ%.0f%%", m.averageDeltaSoC!)
                : "Consistent cycles"
            dimensionTile(
                title: "Cycle Regularity",
                score: analysis.cycleConsistencyScore,
                icon: "arrow.triangle.2.circlepath.circle.fill",
                color: .mint,
                detail: cycleDetail,
                progress: analysis.cycleConsistencyScore / 100.0,
                progressColor: .mint
            )
        }
    }

    private func dimensionTile(
        title: String,
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
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(score.rounded()))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(score >= 80 ? .primary : .orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, progress)))), height: 6)
                }
            }
            .frame(height: 6)

            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(score)) percent, \(detail)")
    }

    // MARK: - Recommendations Card
    private func recommendationsCard(analysis: ChargingBehaviorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actionable Recommendations", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text("\(analysis.recommendations.count) tips")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(analysis.recommendations) { rec in
                    recommendationRow(rec: rec)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, x: 0, y: 3)
    }

    private func recommendationRow(rec: ChargingRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rec.level.icon)
                .font(.body)
                .foregroundColor(rec.level.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(rec.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(rec.observedMetricFormatted)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rec.level.color.opacity(0.12))
                        .foregroundColor(rec.level.color)
                        .clipShape(Capsule())
                }

                Text(rec.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(rec.level.color)
                    Text(rec.actionableAdvice)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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
                .foregroundColor(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(targetVehicle.name) (\(targetVehicle.chemistry.rawValue)) Battery Care")
                    .font(.subheadline).bold()
                Text(targetVehicle.batteryCareTip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(targetVehicle.name) \(targetVehicle.chemistry.rawValue) battery care tip: \(targetVehicle.batteryCareTip)")
    }
    
    // MARK: - Recent Estimates Section
    private var recentEstimatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Capacity Calculations")
                    .font(.title2).bold()
                Spacer()
                Text("\(allPoints.count) sessions analyzed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(Array(allPoints.suffix(5).reversed().enumerated()), id: \.element.id) { index, point in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(point.date.formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US_POSIX"))))
                                    .font(.subheadline).bold()
                                
                                Text(point.chargingType.rawValue)
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background((point.chargingType == .dc ? Color.orange : Color.blue).opacity(0.15))
                                    .foregroundColor(point.chargingType == .dc ? .orange : .blue)
                                    .clipShape(Capsule())
                            }
                            
                            Text(String(format: "SoC: %.0f%% → %.0f%% (Δ%.0f%%) • %.1f kWh added", point.startSoC, point.endSoC, point.socDelta, point.energyAdded))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f kWh", point.estimatedCapacityKWh))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(pointColor(for: point.confidence))
                                    .frame(width: 6, height: 6)
                                Text(String(format: "%.1f%% SoH", point.stateOfHealth))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(pointColor(for: point.confidence))
                            }
                        }
                    }
                    .padding()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(point.date.formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US_POSIX")))), \(point.chargingType.rawValue) session")
                    .accessibilityValue("SoC changed from \(Int(point.startSoC))% to \(Int(point.endSoC))%, \(String(format: "%.1f kWh", point.energyAdded)) added. Estimated pack capacity \(String(format: "%.1f kWh", point.estimatedCapacityKWh)), \(String(format: "%.1f%%", point.stateOfHealth)) State of Health, \(point.confidence.description) confidence")
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text("Insufficient Data for Battery Health")
                .font(.title3).bold()
            
            Text("Log charging sessions with both Start SoC and End SoC to enable capacity estimation and degradation tracking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Helpers
    private func pointColor(for confidence: BatteryHealthConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .blue
        case .low: return .orange
        case .unreliable: return .gray.opacity(0.5)
        }
    }
    
    private func assessmentColor(_ assessment: BatteryHealthSummary.BatteryAssessment) -> Color {
        switch assessment {
        case .excellent, .good: return .green
        case .normal: return .blue
        case .degraded: return .orange
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
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("Battery Longevity Principles")
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        Text("EV battery degradation is driven by four primary stressors: high cell temperature, extreme State of Charge (>90% or <10%), high charging current (DC fast charge C-rate), and time spent at high voltage. Follow these proven practices to maximize pack life and resale value.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(14)

                    // Active Vehicle Chemistry Callout
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "car.side.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(vehicle.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(vehicle.chemistry.fullName)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }

                            Text(vehicle.batteryCareTip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )

                    // Filter Picker
                    Picker("Filter Practices", selection: $selectedFilter) {
                        ForEach(PracticeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
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
                    .font(.title2)
                    .foregroundColor(practice.color)
                    .frame(width: 32, height: 32)
                    .background(practice.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(practice.category)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(practice.color)
                            .textCase(.uppercase)

                        Spacer()

                        Text(practice.chemistryApplicability.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(practice.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }

            Text(practice.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(practice.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(practice.color)
                            .padding(.top, 2)
                        Text(bullet)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(practice.title): \(practice.summary)")
    }
}
