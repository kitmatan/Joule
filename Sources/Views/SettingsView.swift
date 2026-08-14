import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("vehicle_preset_id") private var presetId: String = EVPresetCatalog.defaultPresetId
    @AppStorage("vehicle_name") private var vehicleName: String = VehicleProfile.defaultVehicleName
    @AppStorage("battery_chemistry") private var chemistry: BatteryChemistry = VehicleProfile.defaultChemistry
    @AppStorage("range_rating_standard") private var rangeStandard: RangeStandard = VehicleProfile.defaultRangeStandard
    @AppStorage("battery_nominal_capacity_kwh") private var nominalCapacityKWh: Double = VehicleProfile.defaultNominalCapacityKWh
    @AppStorage("battery_nominal_range_km") private var nominalRangeKm: Double = VehicleProfile.defaultNominalRangeKm
    @AppStorage("battery_cycle_life_to_80") private var cycleLifeTo80: Double = VehicleProfile.defaultCycleLife
    @AppStorage("ac_charging_efficiency") private var acEfficiency: Double = VehicleProfile.defaultACEfficiency
    @AppStorage("dc_charging_efficiency") private var dcEfficiency: Double = VehicleProfile.defaultDCEfficiency
    @AppStorage("home_wall_charger_kw") private var wallChargerKW: Double = VehicleProfile.defaultWallChargerKW
    @AppStorage("home_tariff_type") private var tariffType: HomeTariffType = .standardNonTOU
    @AppStorage("home_custom_tariff_rate") private var customTariffRate: Double = VehicleProfile.defaultTariffPerKWh
    
    @State private var showingPresetSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingResetAlert = false
    
    private var selectedPreset: EVPreset? {
        EVPresetCatalog.preset(forId: presetId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Vehicle Model & Presets
                Section {
                    Button {
                        showingPresetSheet = true
                    } label: {
                        HStack {
                            Label("Car Model Preset", systemImage: "car.side.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Text(selectedPreset?.displayName ?? "Custom Vehicle")
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("Display Name", systemImage: "character.cursor.ibeam")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("Vehicle Name", text: $vehicleName)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Vehicle Model")
                } footer: {
                    Text("Choose an EV preset or customize your vehicle's specific configuration below.")
                }
                
                // Section 2: Battery Specifications
                Section {
                    Picker("Battery Chemistry", selection: $chemistry) {
                        ForEach(BatteryChemistry.allCases) { chem in
                            Text(chem.rawValue).tag(chem)
                        }
                    }
                    .onChange(of: chemistry) { _, newChem in
                        // Update default cycle life if switching chemistry and not customized heavily
                        cycleLifeTo80 = newChem.defaultCycleLife
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
                    
                    Picker("Range Standard", selection: $rangeStandard) {
                        ForEach(RangeStandard.allCases) { std in
                            Text(std.rawValue).tag(std)
                        }
                    }
                    
                    HStack {
                        Label("Rated Range (\(rangeStandard.rawValue))", systemImage: "road.lanes")
                            .foregroundColor(.purple)
                        Spacer()
                        TextField("km", value: $nominalRangeKm, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("km").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Expected Cycle Life (80%)", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.indigo)
                        Spacer()
                        TextField("Cycles", value: $cycleLifeTo80, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("cycles").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Battery & Range Specifications")
                } footer: {
                    Text("\(chemistry.fullName): \(chemistry.recommendedDailyTarget). Used as baseline for State of Health (SoH) and degradation analytics.")
                }
                
                // Section 3: Home Charging & Tariffs
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
                
                // Section 4: Hardware Efficiencies
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
                
                // Section 5: Cloud Sync & Storage
                Section {
                    if auth.isSignedIn {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cloud Sync Active")
                                        .font(.body)
                                    Text(store.syncStatus.statusDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }
                        
                        if let email = auth.userEmail {
                            HStack {
                                Label("Google Account", systemImage: "person.crop.circle.fill")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else if let uid = auth.state.userID {
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
                            Label("Synced Sessions", systemImage: "tray.full.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(store.sessions.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            store.forceSync()
                        } label: {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Button(role: .destructive) {
                            showingSignOutAlert = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Local Mode (Offline-First)", systemImage: "internaldrive.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("Offline")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundColor(.secondary)
                                    .clipShape(Capsule())
                            }
                            Text("All charging sessions and battery analytics are stored locally on this device. Sign in with Google to enable automatic cloud backup and cross-device sync.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        HStack {
                            Label("Local Sessions", systemImage: "tray.full.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(store.sessions.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            auth.signIn()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "icloud.and.arrow.up.fill")
                                    .font(.subheadline)
                                Text("Sign in with Google to Sync")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                } header: {
                    Text("Cloud Sync & Storage")
                } footer: {
                    if auth.isSignedIn {
                        Text("Your charging history is automatically synced across all your devices connected to this Google account.")
                    } else {
                        Text("You can continue using Joule completely offline. Signing in later will safely merge your local sessions into the cloud.")
                    }
                }
                
                // Section 6: Reset
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
            .sheet(isPresented: $showingPresetSheet) {
                PresetPickerView(selectedPresetId: $presetId) { preset in
                    VehicleProfile.applyPreset(preset)
                }
                .frame(minWidth: Platform.isMac ? 500 : nil, minHeight: Platform.isMac ? 600 : nil)
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
                if let preset = selectedPreset {
                    Text("This resets battery capacity, range, and cycle benchmarks back to \(preset.displayName) factory defaults.")
                } else {
                    Text("This resets vehicle specifications and tariffs back to default factory specifications.")
                }
            }
        }
    }
}

/// Modal view to search and select from popular EV models.
struct PresetPickerView: View {
    @Binding var selectedPresetId: String
    let onSelect: (EVPreset) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredBrands: [String] {
        if searchText.isEmpty {
            return EVPresetCatalog.brands
        }
        return EVPresetCatalog.brands.filter { brand in
            let brandMatches = brand.localizedCaseInsensitiveContains(searchText)
            let presetMatches = EVPresetCatalog.presets(forBrand: brand).contains {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
            return brandMatches || presetMatches
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredBrands, id: \.self) { brand in
                    let presets = EVPresetCatalog.presets(forBrand: brand).filter {
                        searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || brand.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    if !presets.isEmpty {
                        Section(brand) {
                            ForEach(presets) { preset in
                                Button {
                                    selectedPresetId = preset.id
                                    onSelect(preset)
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(preset.displayName)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text(preset.chemistry.badgeTitle)
                                                    .font(.caption2).bold()
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(preset.chemistry == .lfp ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                                                    .foregroundColor(preset.chemistry == .lfp ? .blue : .purple)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Text(String(format: "%.1f kWh • %.0f km (%@) • %.1f kW AC", preset.nominalCapacityKWh, preset.nominalRangeKm, preset.rangeStandard.rawValue, preset.defaultWallChargerKW))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedPresetId == preset.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select EV Model")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search make or model (e.g. Tesla, BYD, Aion)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
