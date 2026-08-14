import SwiftUI

/// iOS wrapper: pushes the shared detail content with navigation chrome and an edit button.
struct SessionDetailView: View {
    var session: ChargingSession
    @State private var showingEditSession = false

    var body: some View {
        ScrollView {
            SessionDetailContent(session: session)
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button(action: { showingEditSession = true }) {
                    Image(systemName: "pencil")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingEditSession) {
            AddSessionView(sessionToEdit: session)
        }
    }
}

/// Platform-neutral detail content, shared by the iOS push view and the macOS detail pane.
struct SessionDetailContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    var session: ChargingSession

    private var efficiency: Double {
        session.energyAdded > 0 ? session.totalPrice / session.energyAdded : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            
            // Header
            VStack(spacing: 8) {
                Text(session.locationName ?? "Unknown Location")
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                
                if let vendor = session.vendorName, !vendor.isEmpty {
                    Text(vendor)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text(session.date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute().locale(Locale(identifier: "en_US_POSIX"))))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
            
            // Hero Metrics
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        DetailHeroCard(title: "Total Paid", value: appCurrency.format(session.totalPrice), color: .green)
                        DetailHeroCard(title: "Energy", value: String(format: "%.1f kWh", session.energyAdded), color: .blue)
                        DetailHeroCard(title: "Duration", value: String(format: "%.0f min", session.duration / 60), color: .orange)
                    }
                } else {
                    HStack(spacing: 16) {
                        DetailHeroCard(title: "Total Paid", value: appCurrency.format(session.totalPrice), color: .green)
                        DetailHeroCard(title: "Energy", value: String(format: "%.1f kWh", session.energyAdded), color: .blue)
                        DetailHeroCard(title: "Duration", value: String(format: "%.0f min", session.duration / 60), color: .orange)
                    }
                }
            }
            .padding(.horizontal)
            
            // Technical Details
            VStack(alignment: .leading, spacing: 16) {
                Text("Technical Details")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
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
                                .foregroundColor(point.confidence == .high ? .green : (point.confidence == .medium ? .blue : .orange))
                                .frame(width: 24)
                            Text("Est. Pack Capacity")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f kWh (%.1f%% SoH)", point.estimatedCapacityKWh, point.stateOfHealth))
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                Text(point.confidence.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Estimated Pack Capacity")
                        .accessibilityValue("\(String(format: "%.1f kWh", point.estimatedCapacityKWh)), \(String(format: "%.1f%%", point.stateOfHealth)) State of Health, \(point.confidence.description) confidence")
                    }
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Fees Breakdown
            if session.chargingFee > 0 || session.bookingFee > 0 || session.overtimeFee > 0 || session.paymentStatus != nil {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Fees Breakdown")
                        .font(.headline)
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
                            DetailRow(title: "Payment Status", value: payStat.rawValue, icon: payStat == .deferred ? "list.bullet.rectangle.portrait" : "checkmark.circle.fill")
                        }
                    }
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            // Notes
            if let notes = session.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(notes)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 40)
        }
    }
}

struct DetailHeroCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
