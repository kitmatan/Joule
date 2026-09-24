import SwiftUI

/// iOS wrapper: pushes the shared detail content with navigation chrome and an edit button.
struct SessionDetailView: View {
    var session: ChargingSession
    @State private var showingEditSession = false

    var body: some View {
        ScrollView {
            SessionDetailContent(session: session)
                .padding(.bottom, 24)
        }
        .jouleTabBarClearance()
        .joulePage()
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button("Edit") { showingEditSession = true }
                    .font(.jouleText(15, relativeTo: .body).weight(.semibold))
            }
        }
        .sheet(isPresented: $showingEditSession) {
            AddSessionView(sessionToEdit: session)
        }
    }
}

/// Platform-neutral detail content, shared by the iOS push view and the macOS detail pane.
struct SessionDetailContent: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    var session: ChargingSession

    private var sessionVehicle: Vehicle? {
        if let vId = session.vehicleId {
            return store.vehicle(for: vId)
        }
        return store.activeVehicle
    }

    private var efficiency: Double {
        session.energyAdded > 0 ? session.totalPrice / session.energyAdded : 0
    }

    private var sessionSavings: GasSavingsSummary {
        let vehicle = sessionVehicle ?? store.activeVehicle
        return GasComparisonSettings.calculateSavings(
            energyKWh: session.energyAdded,
            evCost: session.totalPrice,
            ratedEfficiencyKmPerKWh: vehicle.ratedEfficiencyKmPerKWh,
            currency: appCurrency,
            unitSystem: unitSystem
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Header
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ChargeTypeBadge(type: session.chargingType, size: 28)
                    if let locType = session.locationType {
                        Text(LocalizedStringKey(locType == .publicStation ? "Public" : locType.rawValue))
                            .font(.jouleText(14, relativeTo: .subheadline))
                            .foregroundStyle(Color.jouleMuted)
                    }
                }
                Text(session.locationName ?? String(localized: "Unknown Location"))
                    .font(.jouleDisplay(34, relativeTo: .largeTitle))
                    .foregroundStyle(Color.jouleInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text([session.vendorName, session.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.jouleText(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.jouleInk2)
            }
            .padding(.top, 12)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)

            // Cost & energy
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    JouleAmount(formatted: appCurrency.format(session.totalPrice), size: 56)
                    Spacer(minLength: 8)
                    if let status = session.paymentStatus {
                        switch status {
                        case .deferred:
                            JouleTag("On bill", foreground: .jouleDeferredOnSoft, background: .jouleDeferredSoft)
                        case .free:
                            JouleTag("Free", foreground: .joulePositive, background: .joulePositiveSoft)
                        case .paidUpfront:
                            EmptyView()
                        }
                    }
                }
                if efficiency > 0 {
                    Text(String(format: "%.1f kWh", session.energyAdded) + " · " + appCurrency.formatRateSpaced(efficiency))
                        .font(.jouleText(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.jouleInk2)
                }
                if let vehicle = sessionVehicle, vehicle.nominalCapacityKWh > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        ShareBar(
                            fraction: session.energyAdded / vehicle.nominalCapacityKWh,
                            color: session.chargingType?.jouleColor ?? .jouleMuted,
                            height: 12
                        )
                        HStack {
                            Text(String(format: "+%.1f kWh", session.energyAdded))
                            Spacer()
                            Text(String(format: "%.0f%% of %.1f kWh", min(100, session.energyAdded / vehicle.nominalCapacityKWh * 100), vehicle.nominalCapacityKWh))
                        }
                        .font(.jouleMono(12))
                        .foregroundStyle(Color.jouleMuted)
                    }
                }
            }
            .jouleCard(padding: 20, radius: 20)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)

            // Quick figures
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                GridRow {
                    detailFigure("Duration", String(format: "%.0f min", session.duration / 60))
                    detailFigure("Speed", session.speed > 0 ? String(format: "%.1f kW", session.speed) : "—")
                }
                GridRow {
                    detailFigure("Energy", String(format: "%.1f kWh", session.energyAdded))
                    detailFigure("Battery SoC (%)", socSummary)
                }
            }
            .background(Color.jouleLine)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.jouleLine, lineWidth: 1))
            .padding(.horizontal)

            // Technical Details
            VStack(alignment: .leading, spacing: 16) {
                Text("Technical Details")
                    .font(.jouleDisplay(20, relativeTo: .title3))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    if let vehicle = sessionVehicle {
                        DetailRow(title: "Vehicle", value: vehicle.name, icon: "car.side.fill")
                        Divider().padding(.leading, 44)
                    }
                    
                    if let mileage = session.mileage {
                        DetailRow(title: "Mileage", value: unitSystem.formatDistance(km: mileage), icon: "speedometer")
                        Divider().padding(.leading, 44)
                    }
                    
                    if let start = session.startPercentage, let end = session.endPercentage {
                        DetailRow(title: "Battery SoC", value: String(format: "%.0f%% → %.0f%%", start, end), icon: "battery.100")
                        Divider().padding(.leading, 44)
                    } else if let start = session.startPercentage {
                        DetailRow(title: "Start SoC", value: String(format: "%.0f%%", start), icon: "battery.25")
                        Divider().padding(.leading, 44)
                    } else if let end = session.endPercentage {
                        DetailRow(title: "End SoC", value: String(format: "%.0f%%", end), icon: "battery.100")
                        Divider().padding(.leading, 44)
                    }
                    
                    if let startR = session.startRange, let endR = session.endRange {
                        DetailRow(title: "Est. Range", value: "\(unitSystem.formatDistance(km: startR)) → \(unitSystem.formatDistance(km: endR))", icon: "car")
                        Divider().padding(.leading, 44)
                    }
                    
                    DetailRow(title: "Average Speed", value: String(format: "%.1f kW", session.speed), icon: "bolt.badge.clock")
                    
                    if let type = session.chargingType {
                        Divider().padding(.leading, 44)
                        DetailRow(title: "Charging Type", value: type.rawValue, icon: "powerplug")
                    }
                    
                    if let locType = session.locationType {
                        Divider().padding(.leading, 44)
                        DetailRow(title: "Location Type", value: locType.rawValue, icon: locType == .home ? "house.fill" : "mappin.and.ellipse")
                    }
                    
                    if efficiency > 0 {
                        Divider().padding(.leading, 44)
                        DetailRow(title: "Efficiency", value: appCurrency.formatRateSpaced(efficiency), icon: "leaf")
                    }

                    if let point = BatteryHealthService().evaluateSession(session) {
                        Divider().padding(.leading, 44)
                        HStack {
                            Image(systemName: "bolt.batteryblock.fill")
                                .foregroundColor(point.confidence == .high ? .green : (point.confidence == .medium ? .jouleInk : .jouleDeferred))
                                .frame(width: 24)
                            Text("Est. Pack Capacity")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f kWh (%.1f%% SoH)", point.estimatedCapacityKWh, point.stateOfHealth))
                                    .foregroundColor(.jouleInk)
                                    .font(.joule(.subheadline))
                                Text(LocalizedStringKey(point.confidence.description))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Estimated Pack Capacity")
                        .accessibilityValue("\(String(format: "%.1f kWh", point.estimatedCapacityKWh)), \(String(format: "%.1f%%", point.stateOfHealth)) State of Health, \(point.confidence.description) confidence")
                    }

                    if sessionSavings.gasCost > 0 {
                        Divider().padding(.leading, 44)
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(.jouleDeferred)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gas Equivalent")
                                    .font(.joule(.body))
                                Text(appCurrency.format(sessionSavings.gasCost))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(appCurrency.format(sessionSavings.netSavings))
                                    .foregroundColor(.joulePositive)
                                    .font(.joule(.subheadline)).bold()
                                Text(String(format: "Saved (%.0f%%)", sessionSavings.savingsPercentage))
                                    .font(.joule(.caption2))
                                    .foregroundColor(.joulePositive)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Cost Savings vs Gas: Saved \(appCurrency.format(sessionSavings.netSavings)), gas equivalent \(appCurrency.format(sessionSavings.gasCost))")
                    }
                }
                .jouleCard(padding: 0, radius: 18)
                .padding(.horizontal)
            }

            // Battery Longevity Impact
            batteryLongevityImpactSection
            
            // Fees Breakdown
            if session.chargingFee > 0 || session.bookingFee > 0 || session.overtimeFee > 0 || session.paymentStatus != nil {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Fees Breakdown")
                        .font(.joule(.headline))
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        if session.chargingFee > 0 {
                            DetailRow(title: "Charging Fee", value: appCurrency.format(session.chargingFee), icon: "bolt")
                        }
                        if session.bookingFee > 0 {
                            Divider().padding(.leading, 44)
                            DetailRow(title: "Booking Fee", value: appCurrency.format(session.bookingFee), icon: "calendar.badge.clock")
                        }
                        if session.overtimeFee > 0 {
                            Divider().padding(.leading, 44)
                            DetailRow(title: "Overtime Fee", value: appCurrency.format(session.overtimeFee), icon: "clock.badge.exclamationmark")
                        }
                        
                        if let payStat = session.paymentStatus {
                            Divider().padding(.leading, 44)
                            DetailRow(title: "Payment Status", value: payStat.rawValue, icon: paymentStatusIcon(payStat))
                        }
                    }
                    .jouleCard(padding: 0, radius: 18)
                    .padding(.horizontal)
                }
            }
            
            // Notes
            if let notes = session.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notes")
                        .font(.joule(.headline))
                        .padding(.horizontal)
                    
                    Text(notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .jouleCard(padding: 16, radius: 16)
                        .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 40)
        }
    }

    private var socSummary: String {
        switch (session.startPercentage, session.endPercentage) {
        case let (start?, end?): return String(format: "%.0f → %.0f", start, end)
        case let (start?, nil): return String(format: "%.0f →", start)
        case let (nil, end?): return String(format: "→ %.0f", end)
        default: return "—"
        }
    }

    private func detailFigure(_ label: LocalizedStringKey, _ value: String) -> some View {
        JouleStat(label: label, value: value, valueSize: 22)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.jouleSurface)
    }

    // MARK: - Battery Longevity Impact
    private var batteryLongevityImpactSection: some View {
        let vehicle = sessionVehicle ?? store.activeVehicle
        let isAC = session.chargingType == .ac || (session.chargingType == nil && (session.locationType == .home || (session.speed > 0 && session.speed <= 11.5)))
        let start = session.startPercentage
        let end = session.endPercentage

        return VStack(alignment: .leading, spacing: 12) {
            Text("Battery Longevity Impact")
                .font(.jouleDisplay(20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal)

            VStack(spacing: 8) {
                // Speed Impact
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isAC ? "checkmark.circle.fill" : "bolt.fill")
                        .foregroundColor(isAC ? .joulePositive : .jouleDeferred)
                        .font(.joule(.body))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isAC ? "Gentle AC Charging" : "High C-Rate DC Fast Charge")
                            .font(.joule(.subheadline)).bold()
                        Text(isAC ? "Minimal cell heat generation and low mechanical stress on the Solid Electrolyte Interphase (SEI) layer." : "High charging current generates elevated internal cell temperatures. Reserve for long-distance travel.")
                            .font(.joule(.caption))
                            .foregroundColor(.jouleMuted)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((isAC ? Color.joulePositiveSoft : Color.jouleDeferredSoft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                // SoC Range Impact
                if let start, let end {
                    let chemistry = vehicle.chemistry
                    let isLFP = chemistry == .lfp
                    let endsFull = end >= 98.0
                    let startsLow = start < 15.0

                    if endsFull {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isLFP ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(isLFP ? .joulePositive : .jouleDeferred)
                                .font(.joule(.body))
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isLFP ? "100% LFP Calibration Charge" : "100% Top-Off on \(chemistry.rawValue)")
                                    .font(.joule(.subheadline)).bold()
                                Text(isLFP ? "Excellent for LFP BMS cell balancing and capacity calibration." : "Regular daily 100% charges on \(chemistry.rawValue) increase cathode voltage stress. Limit daily charges to 80%–90%.")
                                    .font(.joule(.caption))
                                    .foregroundColor(.jouleMuted)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((isLFP ? Color.joulePositiveSoft : Color.jouleDeferredSoft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if startsLow {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.jouleDeferred)
                                .font(.joule(.body))
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deep Discharge Zone (Start < 15%)")
                                    .font(.joule(.subheadline)).bold()
                                Text("Starting below 15% increases anode internal resistance. Aim to plug in around 15%–20% buffer.")
                                    .font(.joule(.caption))
                                    .foregroundColor(.jouleMuted)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.jouleDeferredSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func paymentStatusIcon(_ status: PaymentStatus) -> String {
        switch status {
        case .deferred: return "list.bullet.rectangle.portrait"
        case .free: return "gift.fill"
        case .paidUpfront: return "checkmark.circle.fill"
        }
    }
}

struct DetailRow: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.jouleInk2)
                .frame(width: 24)
            Text(title)
                .font(.jouleText(15, relativeTo: .body))
                .foregroundStyle(Color.jouleInk)
            Spacer(minLength: 8)
            Text(value)
                .font(.jouleText(15, relativeTo: .body).weight(.medium))
                .foregroundStyle(Color.jouleInk)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}
