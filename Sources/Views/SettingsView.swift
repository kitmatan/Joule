import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("vehicle_name") private var vehicleName: String = VehicleProfile.defaultVehicleName
    @AppStorage("battery_nominal_capacity_kwh") private var nominalCapacityKWh: Double = VehicleProfile.defaultNominalCapacityKWh
    @AppStorage("battery_nominal_range_km") private var nominalRangeKm: Double = VehicleProfile.defaultNominalRangeKm
    @AppStorage("ac_charging_efficiency") private var acEfficiency: Double = VehicleProfile.defaultACEfficiency
    @AppStorage("dc_charging_efficiency") private var dcEfficiency: Double = VehicleProfile.defaultDCEfficiency
    @AppStorage("home_wall_charger_kw") private var wallChargerKW: Double = VehicleProfile.defaultWallChargerKW
    @AppStorage("home_tariff_type") private var tariffType: HomeTariffType = .standardNonTOU
    @AppStorage("home_custom_tariff_rate") private var customTariffRate: Double = VehicleProfile.defaultTariffPerKWh
    
    @State private var showingSignOutAlert = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Vehicle Profile
                Section {
                    HStack {
                        Label("Model", systemImage: "car.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("Vehicle Name", text: $vehicleName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Label("Nominal Pack Capacity", systemImage: "bolt.batteryblock.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("kWh", value: $nominalCapacityKWh, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("kWh").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Rated Range (CLTC)", systemImage: "road.lanes")
                            .foregroundColor(.purple)
                        Spacer()
                        TextField("km", value: $nominalRangeKm, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("km").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Vehicle Profile")
                } footer: {
                    Text("Used as baseline for State of Health (SoH) and battery deterioration analytics.")
                }
                
                // Section 2: Home Charging & Tariffs
                Section {
                    Picker("Tariff Model", selection: $tariffType) {
                        ForEach(HomeTariffType.allCases) { tariff in
                            Text(tariff.rawValue).tag(tariff)
                        }
                    }
                    .onChange(of: tariffType) { _, newType in
                        if newType != .custom {
                            customTariffRate = newType.defaultRate
                        }
                    }
                    
                    if tariffType == .custom {
                        HStack {
                            Label("Custom Tariff Rate", systemImage: "tag.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            TextField("฿/kWh", value: $customTariffRate, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("฿/kWh").foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Label("Active Rate", systemImage: "tag.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "฿%.2f / kWh", tariffType.defaultRate))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("Wall Box Power", systemImage: "powerplug.fill")
                            .foregroundColor(.cyan)
                        Spacer()
                        TextField("kW", value: $wallChargerKW, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("kW").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Home Charging & Tariff")
                } footer: {
                    Text(tariffType.description)
                }
                
                // Section 3: Hardware Efficiencies
                Section {
                    HStack {
                        Label("AC Efficiency (OBC)", systemImage: "bolt.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(String(format: "%.0f%%", acEfficiency * 100))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("DC Fast Efficiency", systemImage: "bolt.badge.clock.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text(String(format: "%.0f%%", dcEfficiency * 100))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Charging Efficiencies")
                } footer: {
                    Text("Standard AC conversion efficiency (90%) and DC dispenser efficiency (95%).")
                }
                
                // Section 4: Account & Data
                Section {
                    if let uid = auth.state.userID {
                        HStack {
                            Label("Account ID", systemImage: "person.crop.circle")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(uid)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    HStack {
                        Label("Stored Sessions", systemImage: "tray.full.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(store.sessions.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account & Sync")
                }
                
                // Section 5: Reset
                Section {
                    Button("Reset Vehicle Specs to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .confirmationDialog("Sign Out?", isPresented: $showingSignOutAlert, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your history will remain safely stored in the cloud.")
            }
            .confirmationDialog("Reset Vehicle Settings?", isPresented: $showingResetAlert, titleVisibility: .visible) {
                Button("Reset to Defaults", role: .destructive) {
                    VehicleProfile.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets battery capacity, range, and tariffs back to AION V 602 Luxury factory defaults.")
            }
        }
    }
}
