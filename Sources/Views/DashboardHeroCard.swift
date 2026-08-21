import SwiftUI

/// A centerpiece Hero card for the Dashboard that highlights vehicle status,
/// current monthly charging cost, savings vs. gas, battery health, and quick actions.
struct DashboardHeroCard: View {
    let vehicle: Vehicle
    let isAllVehicles: Bool
    let vehicleCount: Int
    let sessions: [ChargingSession]
    let currentMonthCost: Double
    let currentMonthEnergy: Double
    let totalCost: Double
    let totalEnergy: Double
    let gasSavings: GasSavingsSummary
    let lifetimeGasSavings: GasSavingsSummary
    let batteryHealth: BatteryHealthSummary?
    let energyEfficiency: Double
    let averagePricePerKWh: Double
    let costPerDistance: Double
    let hasDrivingData: Bool
    let currency: AppCurrency
    let unitSystem: UnitSystem
    let isWide: Bool
    let onAddSession: () -> Void
    let onOpenBatteryHealth: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Toggles the main spend metric between the current month and lifetime totals.
    @AppStorage("heroShowsTotalSpend") private var showsTotalSpend: Bool = false

    /// Toggles the rate tile between average charging price and driving cost per distance.
    @AppStorage("heroShowsDrivingCost") private var showsDrivingCost: Bool = false

    /// Toggles the efficiency tile between km/kWh (distance per energy) and kWh/100km (consumption).
    @AppStorage("heroShowsConsumption") private var showsConsumption: Bool = false

    private var latestSession: ChargingSession? {
        sessions.sorted { $0.date > $1.date }.first
    }

    private var currentMonthName: String {
        Date().formatted(.dateTime.month(.wide))
    }

    // MARK: - Spend Toggle State

    private var spendTitle: String {
        showsTotalSpend ? String(localized: "Total Spent") : String(format: String(localized: "Spent in %@"), currentMonthName)
    }

    private var spendCost: Double {
        showsTotalSpend ? totalCost : currentMonthCost
    }

    private var spendEnergy: Double {
        showsTotalSpend ? totalEnergy : currentMonthEnergy
    }

    private var spendSavings: GasSavingsSummary {
        showsTotalSpend ? lifetimeGasSavings : gasSavings
    }

    // MARK: - Efficiency Toggle State

    private var efficiencyTitle: String {
        showsConsumption ? String(localized: "Consumption") : String(localized: "Efficiency")
    }

    private var hasEfficiencyData: Bool {
        hasDrivingData && energyEfficiency > 0
    }

    private var efficiencyValue: String {
        guard hasEfficiencyData else { return "—" }
        let value = showsConsumption
            ? unitSystem.consumptionValue(kmPerKWh: energyEfficiency)
            : unitSystem.convertFromKm(energyEfficiency)
        return String(format: "%.1f", value)
    }

    private var efficiencyUnitLabel: String {
        guard hasEfficiencyData else { return "" }
        return showsConsumption ? unitSystem.consumptionUnit : unitSystem.efficiencyUnit
    }

    /// Value and unit combined, for VoiceOver and non-visual contexts.
    private var efficiencySpokenValue: String {
        hasEfficiencyData ? "\(efficiencyValue) \(efficiencyUnitLabel)" : efficiencyValue
    }

    // MARK: - Rate Toggle State

    private var rateTitle: String {
        showsDrivingCost ? String(localized: "Driving Cost") : String(localized: "Avg Rate")
    }

    private var hasRateData: Bool {
        showsDrivingCost ? (hasDrivingData && costPerDistance > 0) : averagePricePerKWh > 0
    }

    private var rateValue: String {
        guard hasRateData else { return "—" }
        let amount = showsDrivingCost ? costPerDistance : averagePricePerKWh
        return String(format: "%@%.2f", currency.symbol, amount)
    }

    private var rateUnitLabel: String {
        guard hasRateData else { return "" }
        return showsDrivingCost ? String(format: String(localized: "per %@"), unitSystem.distanceUnit) : String(localized: "per kWh")
    }

    /// Value and unit combined, for VoiceOver and non-visual contexts.
    private var rateSpokenValue: String {
        hasRateData ? "\(rateValue) \(rateUnitLabel)" : rateValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow
            
            if sessions.isEmpty {
                emptyStateContent
            } else {
                mainMetricsRow
                Divider()
                    .overlay(dividerColor)
                quickMetricsStrip
            }
            
            actionButtonsRow
        }
        .padding(isWide ? 22 : 18)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderGradient, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dashboard Overview Hero Card")
    }

    // MARK: - Header Row (Vehicle & Status)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Vehicle Icon Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.teal.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 2)

                Image(systemName: isAllVehicles ? "car.2.fill" : "bolt.car.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Vehicle Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isAllVehicles ? String(localized: "Garage Fleet") : vehicle.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !isAllVehicles && vehicle.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .accessibilityLabel("Default Vehicle")
                    }
                }

                if isAllVehicles {
                    Text(String(format: String(localized: "%lld vehicles combined"), Int64(vehicleCount)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let plate = vehicle.licensePlate, !plate.isEmpty {
                    Text(plate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(format: String(localized: "%.0f kWh nominal • ~%.0f %@"), vehicle.nominalCapacityKWh, vehicle.nominalRangeKm, unitSystem.distanceUnit))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chemistry / Battery Specs Capsule
            if !isAllVehicles {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(vehicle.chemistry.rawValue)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Main Metrics Row

    private var mainMetricsRow: some View {
        HStack(alignment: .center, spacing: 14) {
            // Left: Spend (tap to switch month / lifetime) & Gas Savings Highlight
            Button(action: toggleSpendScope) {
                spendColumn
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(spendTitle): \(currency.format(spendCost))")
            .accessibilityHint(showsTotalSpend ? "Double tap to show this month's spend" : "Double tap to show total spend")

            // Right: Clean, Uncluttered Battery Health Chip
            if let health = batteryHealth {
                Button(action: onOpenBatteryHealth) {
                    batteryHealthChip(health: health)
                }
                .buttonStyle(.plain)
            } else if let latest = latestSession {
                latestChargeChip(latest: latest)
            }
        }
    }

    // MARK: - Spend Column (Tappable Month / Total Toggle)

    private var spendColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(spendTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Text(currency.format(spendCost))
                .font(.system(size: isWide ? 32 : 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .contentTransition(.numericText())

            if spendSavings.netSavings > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                        .foregroundColor(.green)

                    Text(String(format: String(localized: "Saved %@"), currency.format(spendSavings.netSavings)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .clipShape(Capsule())
            } else if spendEnergy > 0 {
                Text(String(format: "%.1f kWh charged", spendEnergy))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func toggleSpendScope() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showsTotalSpend.toggle()
        }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    // MARK: - Battery Health Chip (Clean & Uncluttered)

    private func batteryHealthChip(health: BatteryHealthSummary) -> some View {
        let isHealthy = health.currentSoH >= 90
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((isHealthy ? Color.green : Color.orange).opacity(0.18))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isHealthy ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(format: "%.0f%%", health.currentSoH))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("SoH")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Text(LocalizedStringKey(health.assessment.title))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isHealthy ? .green : .orange)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.07))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery Health: \(String(format: "%.1f percent State of Health", health.currentSoH)), \(health.assessment.title)")
    }

    // MARK: - Latest Charge Chip

    private func latestChargeChip(latest: ChargingSession) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((latest.chargingType == .dc ? Color.orange : Color.blue).opacity(0.18))
                    .frame(width: 30, height: 30)
                
                Image(systemName: latest.chargingType == .dc ? "bolt.fill" : "powerplug.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(latest.chargingType == .dc ? .orange : .blue)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "+%.1f kWh", latest.energyAdded))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if let endSoC = latest.endPercentage {
                    Text(String(format: "%.0f%% SoC", endSoC))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.07))
        )
    }

    // MARK: - Quick Metrics Strip

    private var quickMetricsStrip: some View {
        HStack(spacing: 8) {
            // Energy — follows the spend toggle (month vs. lifetime)
            Button(action: toggleSpendScope) {
                metricTile(
                    title: showsTotalSpend ? "Total Energy" : "Energy",
                    value: String(format: "%.1f", spendEnergy),
                    unit: "kWh",
                    icon: "bolt.batteryblock.fill",
                    color: .blue,
                    isToggleable: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(showsTotalSpend ? String(localized: "Total Energy") : String(localized: "Energy")): \(String(format: "%.1f kWh", spendEnergy))")
            .accessibilityHint(showsTotalSpend ? "Double tap to show this month's energy" : "Double tap to show total energy")

            // Driving Efficiency (tap to switch between km/kWh and kWh/100km)
            Button(action: toggleEfficiencyUnit) {
                metricTile(
                    title: LocalizedStringKey(efficiencyTitle),
                    value: efficiencyValue,
                    unit: efficiencyUnitLabel,
                    icon: showsConsumption ? "gauge.with.needle.fill" : "leaf.fill",
                    color: showsConsumption ? .teal : .mint,
                    isToggleable: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(efficiencyTitle): \(efficiencySpokenValue)")
            .accessibilityHint(showsConsumption ? "Double tap to show \(unitSystem.efficiencyUnit)" : "Double tap to show \(unitSystem.consumptionUnit)")

            // Cost Rate (tap to switch between charging rate and driving cost)
            Button(action: toggleRateScope) {
                metricTile(
                    title: LocalizedStringKey(rateTitle),
                    value: rateValue,
                    unit: rateUnitLabel,
                    icon: showsDrivingCost ? "road.lanes" : "tag.fill",
                    color: showsDrivingCost ? .purple : .orange,
                    isToggleable: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(rateTitle): \(rateSpokenValue)")
            .accessibilityHint(showsDrivingCost ? "Double tap to show average charging rate" : "Double tap to show driving cost per \(unitSystem.distanceUnit)")
        }
    }

    private func toggleEfficiencyUnit() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showsConsumption.toggle()
        }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    private func toggleRateScope() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showsDrivingCost.toggle()
        }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    /// A compact metric tile. The unit is rendered on its own line so long units
    /// (e.g. "kWh/100km") stay legible in the three-across iPhone layout.
    private func metricTile(title: LocalizedStringKey, value: String, unit: String, icon: String, color: Color, isToggleable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                    .layoutPriority(1)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if isToggleable {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .layoutPriority(1)
                }
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Primary: Log Charge Button
            Button(action: onAddSession) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Log Charge")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log a new charging session")

            // Secondary: Battery Health or Details
            Button(action: onOpenBatteryHealth) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.caption)
                    Text("Battery Health")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View detailed battery health analytics")
        }
    }

    // MARK: - Empty State Content

    private var emptyStateContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Joule ⚡️")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Start tracking your charging sessions to unlock real-time monthly costs, gas savings comparison, and battery State of Health (SoH) analytics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Visual Background & Borders

    private var heroBackground: some View {
        ZStack {
            if colorScheme == .dark {
                // Dark mode: Deep midnight base with subtle electric accents
                Color(uiColor: .secondarySystemBackground)
                
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.18),
                        Color.teal.opacity(0.12),
                        Color.indigo.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: Clean card with soft vibrant gradient tint
                Color(uiColor: .systemBackground)
                
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.09),
                        Color.teal.opacity(0.06),
                        Color.mint.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.22), Color.teal.opacity(0.3), Color.blue.opacity(0.15)]
                : [Color.blue.opacity(0.2), Color.teal.opacity(0.2), Color.black.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.06)
    }
}
