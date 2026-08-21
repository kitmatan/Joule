import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = AppTheme.defaultTheme
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
    @AppStorage("home_tariff_type") private var tariffType: HomeTariffType = .peaStandardNonTOU
    @AppStorage("home_custom_tariff_rate") private var customTariffRate: Double = VehicleProfile.defaultTariffPerKWh
    @AppStorage("gas_baseline_preset") private var gasPreset: GasBaselinePreset = GasComparisonSettings.defaultPreset
    @AppStorage("gas_fuel_efficiency_km_per_l") private var gasEfficiencyKmPerL: Double = GasComparisonSettings.defaultEfficiencyKmPerL
    @AppStorage("gas_custom_fuel_price") private var gasFuelPrice: Double = GasComparisonSettings.defaultFuelPriceTHB
    
    @State private var showingPresetSheet = ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "presets"
    @State private var showingGarageManagement = false
    @State private var showingAddVehicle = false
    @State private var showingSignOutAlert = false
    @State private var showingResetAlert = false
    
    private var selectedPreset: EVPreset? {
        EVPresetCatalog.preset(forId: presetId)
    }
    
    private var nominalRangeBinding: Binding<Double> {
        Binding(
            get: {
                Double(String(format: "%.0f", unitSystem.convertFromKm(nominalRangeKm))) ?? unitSystem.convertFromKm(nominalRangeKm)
            },
            set: {
                nominalRangeKm = unitSystem.convertToKm($0)
            }
        )
    }
    
    private var gasEfficiencyBinding: Binding<Double> {
        Binding(
            get: {
                switch unitSystem {
                case .metric:
                    return gasEfficiencyKmPerL
                case .imperial:
                    let mpg = GasComparisonSettings.convertKmPerLToMPG(gasEfficiencyKmPerL)
                    return (mpg * 10).rounded() / 10
                }
            },
            set: { newValue in
                switch unitSystem {
                case .metric:
                    gasEfficiencyKmPerL = max(0.1, newValue)
                case .imperial:
                    gasEfficiencyKmPerL = max(0.1, GasComparisonSettings.convertMPGToKmPerL(newValue))
                }
            }
        )
    }
    
    private var effectiveGasCostPerDistance: Double {
        let eff = GasComparisonSettings.activeEfficiency(unitSystem: unitSystem)
        guard eff > 0 else { return 0 }
        let price = gasFuelPrice > 0 ? gasFuelPrice : GasComparisonSettings.defaultFuelPrice(for: appCurrency, unitSystem: unitSystem)
        return price / eff
    }
    
    private func loadActiveVehicleFromStore() {
        let current = store.activeVehicle
        vehicleName = current.name
        presetId = current.presetId
        chemistry = current.chemistry
        rangeStandard = current.rangeStandard
        nominalCapacityKWh = current.nominalCapacityKWh
        nominalRangeKm = current.nominalRangeKm
        cycleLifeTo80 = current.cycleLifeTo80
        acEfficiency = current.acEfficiency
        dcEfficiency = current.dcEfficiency
        wallChargerKW = current.wallChargerKW
        tariffType = current.tariffType
        customTariffRate = current.customTariffRate
        gasPreset = current.gasPreset
        gasEfficiencyKmPerL = current.gasEfficiencyKmPerL
        gasFuelPrice = current.gasCustomFuelPrice
    }
    
    private func syncCurrentVehicleToStore() {
        var vehicle = store.activeVehicle
        vehicle.name = vehicleName
        vehicle.presetId = presetId
        vehicle.chemistry = chemistry
        vehicle.rangeStandard = rangeStandard
        vehicle.nominalCapacityKWh = nominalCapacityKWh
        vehicle.nominalRangeKm = nominalRangeKm
        vehicle.cycleLifeTo80 = cycleLifeTo80
        vehicle.acEfficiency = acEfficiency
        vehicle.dcEfficiency = dcEfficiency
        vehicle.wallChargerKW = wallChargerKW
        vehicle.tariffType = tariffType
        vehicle.customTariffRate = customTariffRate
        vehicle.gasPreset = gasPreset
        vehicle.gasEfficiencyKmPerL = gasEfficiencyKmPerL
        vehicle.gasCustomFuelPrice = gasFuelPrice
        store.updateVehicle(vehicle)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 0: Multi-Vehicle Garage
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "car.side.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(store.activeVehicle.name)
                                    .font(.headline)
                                Text("Active")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                            Text(String(format: "%@ • %.1f kWh • %@", store.activeVehicle.chemistry.badgeTitle, store.activeVehicle.nominalCapacityKWh, unitSystem.formatDistance(km: store.activeVehicle.nominalRangeKm)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        showingGarageManagement = true
                    } label: {
                        HStack {
                            Label(String(format: String(localized: "Manage Garage (%lld)…"), Int64(store.vehicles.count)), systemImage: "car.2.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Label("Add New Vehicle…", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Multi-Vehicle Garage")
                } footer: {
                    Text("Manage multiple EV profiles with custom battery chemistries, tariffs, and gas baselines.")
                }

                // Section 1: General Preferences (Units & Currency)
                Section {
                    Picker("Units", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases) { sys in
                            Text(sys.displayName).tag(sys)
                        }
                    }
                    
                    Picker("Currency", selection: $appCurrency) {
                        ForEach(AppCurrency.allCases) { curr in
                            Text(curr.displayName).tag(curr)
                        }
                    }
                } header: {
                    Text("Units & Currency")
                } footer: {
                    Text("Select your preferred distance/efficiency units and local currency formatting.")
                }

                // Section 1b: Appearance
                Section {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { option in
                            Label(option.displayName, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.vertical, 2)
                } header: {
                    // The segmented style strips label icons, so the current theme's glyph rides
                    // in the header instead.
                    Label("Appearance", systemImage: theme.iconName)
                } footer: {
                    Text(theme.footerDescription)
                }

                // Section 2: Vehicle Model & Presets
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
                
                // Section 3: Battery Specifications
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
                        TextField(unitSystem.distanceUnit, value: nominalRangeBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(unitSystem.distanceUnit).foregroundColor(.secondary)
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
                
                // Section 4: Home Charging & Tariffs
                Section {
                    Picker("Tariff Model", selection: $tariffType) {
                        ForEach(TariffRegion.allCases) { region in
                            Section(LocalizedStringKey(region.rawValue)) {
                                ForEach(region.tariffs) { tariff in
                                    Text(LocalizedStringKey(tariff.rawValue)).tag(tariff)
                                }
                            }
                        }
                    }
                    .onChange(of: tariffType) { _, newType in
                        if newType != .custom {
                            customTariffRate = newType.defaultRate
                            if newType.region != .custom {
                                appCurrency = newType.associatedCurrency
                            }
                        }
                    }
                    
                    if tariffType == .custom {
                        HStack {
                            Label("Custom Tariff Rate", systemImage: "tag.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            TextField(appCurrency.rateUnitSuffix, value: $customTariffRate, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text(appCurrency.rateUnitSuffix).foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Label("Active Rate", systemImage: "tag.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(appCurrency.formatRateSpaced(tariffType.defaultRate))
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
                } footer: {
                    Text(LocalizedStringKey(tariffType.description))
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
                
                // Section 5: Gas Comparison Baseline
                Section {
                    Picker("Gas Baseline Archetype", selection: $gasPreset) {
                        ForEach(GasBaselinePreset.allCases) { preset in
                            Text(preset.title(for: unitSystem)).tag(preset)
                        }
                    }
                    .onChange(of: gasPreset) { _, newPreset in
                        if newPreset != .custom {
                            gasEfficiencyKmPerL = newPreset.defaultEfficiencyKmPerL
                        }
                    }
                    
                    HStack {
                        Label("Fuel Economy", systemImage: "fuelpump.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField(GasComparisonSettings.efficiencyUnit(unitSystem: unitSystem), value: gasEfficiencyBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: gasEfficiencyKmPerL) { _, _ in
                                if gasPreset != .custom && gasEfficiencyKmPerL != gasPreset.defaultEfficiencyKmPerL {
                                    gasPreset = .custom
                                }
                            }
                        Text(GasComparisonSettings.efficiencyUnit(unitSystem: unitSystem)).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Fuel Price", systemImage: "tag.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("\(appCurrency.symbol)/\(GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))", value: $gasFuelPrice, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("\(appCurrency.symbol)/\(GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Gas Engine Baseline (Savings Calculator)")
                } footer: {
                    Text("\(gasPreset.subtitle) Equivalent gas running cost: \(appCurrency.formatCostPerDistance(cost: effectiveGasCostPerDistance, distanceUnit: unitSystem.distanceUnit)).")
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

                        Button {
                            store.cleanDuplicates()
                        } label: {
                            HStack {
                                Label("Clean Up Duplicate Sessions", systemImage: "sparkles.rectangle.stack")
                                Spacer()
                                if store.duplicateSessionsCount > 0 {
                                    Text("\(store.duplicateSessionsCount) found")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
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
                            store.cleanDuplicates()
                        } label: {
                            HStack {
                                Label("Clean Up Duplicate Sessions", systemImage: "sparkles.rectangle.stack")
                                Spacer()
                                if store.duplicateSessionsCount > 0 {
                                    Text("\(store.duplicateSessionsCount) found")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
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
                        syncCurrentVehicleToStore()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                loadActiveVehicleFromStore()
            }
            .onDisappear {
                syncCurrentVehicleToStore()
            }
            .onChange(of: store.selectedVehicleId) { _, _ in
                loadActiveVehicleFromStore()
            }
            .sheet(isPresented: $showingPresetSheet) {
                PresetPickerView(selectedPresetId: $presetId) { preset in
                    handleApplyPreset(preset)
                }
                .frame(minWidth: Platform.isMac ? 500 : nil, minHeight: Platform.isMac ? 600 : nil)
            }
            .sheet(isPresented: $showingGarageManagement) {
                GarageManagementView()
            }
            .sheet(isPresented: $showingAddVehicle) {
                VehicleEditorView(mode: .create)
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
                    handleResetToDefaults()
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

    private func handleApplyPreset(_ preset: EVPreset) {
        vehicleName = preset.displayName
        chemistry = preset.chemistry
        rangeStandard = preset.rangeStandard
        nominalCapacityKWh = preset.nominalCapacityKWh
        nominalRangeKm = preset.nominalRangeKm
        cycleLifeTo80 = preset.expectedCycleLife
        wallChargerKW = preset.defaultWallChargerKW
        syncCurrentVehicleToStore()
    }

    private func handleResetToDefaults() {
        if let preset = selectedPreset {
            vehicleName = preset.displayName
            chemistry = preset.chemistry
            rangeStandard = preset.rangeStandard
            nominalCapacityKWh = preset.nominalCapacityKWh
            nominalRangeKm = preset.nominalRangeKm
            cycleLifeTo80 = preset.expectedCycleLife
            wallChargerKW = preset.defaultWallChargerKW
        } else {
            presetId = EVPresetCatalog.defaultPresetId
            vehicleName = VehicleProfile.defaultVehicleName
            chemistry = VehicleProfile.defaultChemistry
            rangeStandard = VehicleProfile.defaultRangeStandard
            nominalCapacityKWh = VehicleProfile.defaultNominalCapacityKWh
            nominalRangeKm = VehicleProfile.defaultNominalRangeKm
            cycleLifeTo80 = VehicleProfile.defaultCycleLife
            wallChargerKW = VehicleProfile.defaultWallChargerKW
        }
        acEfficiency = VehicleProfile.defaultACEfficiency
        dcEfficiency = VehicleProfile.defaultDCEfficiency
        tariffType = .peaStandardNonTOU
        customTariffRate = VehicleProfile.defaultTariffPerKWh
        gasPreset = GasComparisonSettings.defaultPreset
        gasEfficiencyKmPerL = GasComparisonSettings.defaultEfficiencyKmPerL
        gasFuelPrice = GasComparisonSettings.defaultFuelPriceTHB
        syncCurrentVehicleToStore()
    }
}

/// Modal view to search and select from popular EV models.
struct PresetPickerView: View {
    @Binding var selectedPresetId: String
    let onSelect: (EVPreset) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    
    private var filteredBrands: [String] {
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
                                            
                                            Text(String(format: "%.1f kWh • %@ (%@) • %.1f kW AC", preset.nominalCapacityKWh, unitSystem.formatDistance(km: preset.nominalRangeKm), preset.rangeStandard.rawValue, preset.defaultWallChargerKW))
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
