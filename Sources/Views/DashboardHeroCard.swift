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
    let gasSavings: GasSavingsSummary
    let batteryHealth: BatteryHealthSummary?
    let energyEfficiency: Double
    let averagePricePerKWh: Double
    let hasDrivingData: Bool
    let currency: AppCurrency
    let unitSystem: UnitSystem
    let isWide: Bool
    let onAddSession: () -> Void
    let onOpenBatteryHealth: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var latestSession: ChargingSession? {
        sessions.sorted { $0.date > $1.date }.first
    }

    private var currentMonthName: String {
        Date().formatted(.dateTime.month(.wide))
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
                    Text(isAllVehicles ? "Garage Fleet" : vehicle.name)
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
                    Text("\(vehicleCount) vehicles combined")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let plate = vehicle.licensePlate, !plate.isEmpty {
                    Text(plate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(format: "%.0f kWh nominal • ~%.0f %@", vehicle.nominalCapacityKWh, vehicle.nominalRangeKm, unitSystem.distanceUnit))
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
            // Left: Monthly Cost & Gas Savings Highlight
            VStack(alignment: .leading, spacing: 6) {
                Text("Spent in \(currentMonthName)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(currency.format(currentMonthCost))
                    .font(.system(size: isWide ? 32 : 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                if gasSavings.netSavings > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text(String(format: "Saved %@", currency.format(gasSavings.netSavings)))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.12))
                    .clipShape(Capsule())
                } else if currentMonthEnergy > 0 {
                    Text(String(format: "%.1f kWh charged", currentMonthEnergy))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

                Text(health.assessment.title)
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
            // Energy
            metricTile(
                title: "Energy",
                value: String(format: "%.1f kWh", currentMonthEnergy),
                icon: "bolt.batteryblock.fill",
                color: .blue
            )

            // Driving Efficiency
            metricTile(
                title: "Efficiency",
                value: hasDrivingData ? unitSystem.formatEfficiency(kmPerKWh: energyEfficiency) : "—",
                icon: "leaf.fill",
                color: .mint
            )

            // Cost Rate
            metricTile(
                title: "Avg Rate",
                value: averagePricePerKWh > 0 ? currency.formatRate(averagePricePerKWh) : "—",
                icon: "tag.fill",
                color: .orange
            )
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
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
