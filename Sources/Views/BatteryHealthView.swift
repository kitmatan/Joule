import SwiftUI
import Charts

struct BatteryHealthView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedTimeRange: ChartTimeRange = .all
    @State private var selectedChartMode: ChartMode = .time
    
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
        case range = "Range (km)"
        case cycles = "Cycle Wear"
        
        var id: String { rawValue }
    }
    
    private var service: BatteryHealthService {
        BatteryHealthService()
    }
    
    private var allPoints: [BatteryHealthDataPoint] {
        service.calculateDataPoints(from: store.sessions)
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
    
    private var summary: BatteryHealthSummary? {
        service.calculateSummary(from: store.sessions)
    }
    
    @State private var showingSettings = false

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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Hero Card
    private func heroCard(summary: BatteryHealthSummary) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
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
                
                Spacer()
                
                // Circular Capacity Gauge
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
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .padding(.horizontal)
    }
    
    // MARK: - Metrics Grid
    private func metricsGrid(summary: BatteryHealthSummary) -> some View {
        LazyVGrid(
            columns: isWide ? [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)] : [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            StatCard(
                title: "Degradation Rate",
                value: summary.degradationPer10kKm != nil ? String(format: "-%.2f%% / 10k km", summary.degradationPer10kKm!) : "Calibrating",
                icon: "gauge.with.needle.fill",
                color: .mint
            )
            
            StatCard(
                title: "Annual Rate",
                value: summary.degradationPerYear != nil ? String(format: "-%.2f%% / yr", summary.degradationPerYear!) : "Calibrating",
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
                value: summary.currentProjectedRangeKm != nil ? String(format: "%.0f km", summary.currentProjectedRangeKm!) : String(format: "%.0f km", summary.nominalRangeKm),
                icon: "car.fill",
                color: .green
            )
        }
        .padding(.horizontal)
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
                    Text(mode.rawValue).tag(mode)
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
            .frame(height: 260)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Chart 1: SoH Over Time
    private var sohOverTimeChart: some View {
        Chart {
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
        }
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
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
            }
        }
    }
    
    // MARK: - Chart 2: SoH Vs Mileage
    private var sohVsMileageChart: some View {
        let mileagePoints = filteredPoints.filter { $0.mileage != nil }
        
        return Chart {
            RuleMark(y: .value("100% Nominal", 100.0))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            
            ForEach(mileagePoints) { point in
                PointMark(
                    x: .value("Mileage", point.mileage!),
                    y: .value("SoH", point.stateOfHealth)
                )
                .foregroundStyle(pointColor(for: point.confidence))
                .symbolSize(point.confidence == .high ? 55 : 35)
            }
            
            let sortedMileageTrend = trendPoints.filter { $0.mileage != nil }.sorted { ($0.mileage ?? 0) < ($1.mileage ?? 0) }
            ForEach(sortedMileageTrend) { trend in
                LineMark(
                    x: .value("Mileage", trend.mileage!),
                    y: .value("SoH", trend.smoothedSoH)
                )
                .foregroundStyle(.mint)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }
        }
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
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.0fk", d / 1000.0))
                    }
                }
            }
        }
    }
    
    // MARK: - Chart 3: Projected Range Over Time
    private func rangeOverTimeChart(summary: BatteryHealthSummary) -> some View {
        let rangePoints = filteredPoints.filter { $0.projectedFullRangeKm != nil }
        let nominal = summary.nominalRangeKm
        let minBound = max(50.0, nominal * 0.75)
        let maxBound = nominal * 1.15
        let standardTag = VehicleProfile.rangeStandard.rawValue
        
        return Chart {
            RuleMark(y: .value("Rated Range", summary.nominalRangeKm))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Factory \(Int(summary.nominalRangeKm)) km (\(standardTag))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            
            ForEach(rangePoints) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Range", point.projectedFullRangeKm!)
                )
                .foregroundStyle(.green.opacity(0.7))
                .symbolSize(35)
            }
            
            let validTrend = trendPoints.filter { $0.projectedFullRangeKm != nil }
            ForEach(validTrend) { trend in
                LineMark(
                    x: .value("Date", trend.date),
                    y: .value("Range", trend.projectedFullRangeKm!)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: minBound...maxBound)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal) km")
                    } else if let dVal = value.as(Double.self) {
                        Text("\(Int(dVal)) km")
                    }
                }
            }
        }
    }
    
    // MARK: - Chart 4: Cycle Wear vs Theoretical Life
    private func cycleWearChart(summary: BatteryHealthSummary) -> some View {
        let maxCycles = max(300.0, summary.equivalentFullCycles * 2.5)
        let sampleSteps = stride(from: 0.0, through: maxCycles, by: maxCycles / 20.0)
        let benchmarkCycleLife = BatteryConstants.cycleLifeTo80Percent
        let chemistryName = VehicleProfile.chemistry.rawValue
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
            }
            
            // Actual Measured Position
            PointMark(
                x: .value("Cycles", summary.equivalentFullCycles),
                y: .value("Actual SoH", summary.currentSoH)
            )
            .foregroundStyle(by: .value("Type", "Your Vehicle"))
            .symbolSize(120)
        }
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
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.0f cyc", d))
                    }
                }
            }
        }
    }
    
    // MARK: - Charging Habits Section
    private func chargingHabitsSection(summary: BatteryHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Charging Habits & Cell Longevity")
                .font(.title2).bold()
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // AC / DC Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("AC Charging (Home/Slow)", systemImage: "powerplug.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text(String(format: "%.0f%%", summary.acEnergyRatio * 100))
                            .font(.caption).bold()
                            .foregroundColor(.blue)
                    }
                    
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * CGFloat(summary.acEnergyRatio))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * CGFloat(summary.dcEnergyRatio))
                        }
                    }
                    .frame(height: 10)
                    
                    HStack {
                        Label("DC Fast Charging", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Text(String(format: "%.0f%%", summary.dcEnergyRatio * 100))
                            .font(.caption).bold()
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)
                
                // Dynamic Battery Chemistry Tip
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(VehicleProfile.vehicleName) (\(VehicleProfile.chemistry.rawValue)) Battery Care")
                            .font(.subheadline).bold()
                        Text(VehicleProfile.batteryCareTip)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
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
