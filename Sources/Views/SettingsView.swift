import SwiftUI

struct SettingsView: View {
    /// A sheet (Mac, and the Baseline shortcut on the dashboard) or the iPhone/iPad Garage tab.
    enum Presentation {
        case sheet, tab
    }

    var presentation: Presentation = .sheet

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.jouleTabBarHeight) private var tabBarHeight
    
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
                    ForEach(store.vehicles) { vehicle in
                        vehicleCard(vehicle)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    HStack(spacing: 10) {
                        Button {
                            showingAddVehicle = true
                        } label: {
                            Label("Add Vehicle…", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(JouleDashedButtonStyle())

                        Button {
                            showingGarageManagement = true
                        } label: {
                            Label(String(format: String(localized: "Manage Garage (%lld)…"), Int64(store.vehicles.count)), systemImage: "car.2")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(JouleDashedButtonStyle())
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                    JoulePillPicker(
                        options: AppTheme.allCases.map { ($0, LocalizedStringKey($0.displayName)) },
                        selection: $theme,
                        accessibilityTitle: "Appearance"
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
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
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            Text(selectedPreset?.displayName ?? "Custom Vehicle")
                                .foregroundColor(.jouleInk)
                            Image(systemName: "chevron.right")
                                .font(.joule(.caption))
                                .foregroundColor(.jouleMuted)
                        }
                    }
                    
                    HStack {
                        Label("Display Name", systemImage: "character.cursor.ibeam")
                            .foregroundStyle(Color.jouleInk)
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
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("kWh", value: $nominalCapacityKWh, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("kWh").foregroundColor(.jouleMuted)
                    }
                    
                    Picker("Range Standard", selection: $rangeStandard) {
                        ForEach(RangeStandard.allCases) { std in
                            Text(std.rawValue).tag(std)
                        }
                    }
                    
                    HStack {
                        Label("Rated Range (\(rangeStandard.rawValue))", systemImage: "road.lanes")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField(unitSystem.distanceUnit, value: nominalRangeBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(unitSystem.distanceUnit).foregroundColor(.jouleMuted)
                    }
                    
                    HStack {
                        Label("Expected Cycle Life (80%)", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("Cycles", value: $cycleLifeTo80, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("cycles").foregroundColor(.jouleMuted)
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
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            TextField(appCurrency.rateUnitSuffix, value: $customTariffRate, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text(appCurrency.rateUnitSuffix).foregroundColor(.jouleMuted)
                        }
                    } else {
                        HStack {
                            Label("Active Rate", systemImage: "tag.fill")
                                .foregroundColor(.jouleMuted)
                            Spacer()
                            Text(appCurrency.formatRateSpaced(tariffType.defaultRate))
                                .foregroundColor(.jouleMuted)
                        }
                    }
                    
                    HStack {
                        Label("Wall Box Power", systemImage: "powerplug.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("kW", value: $wallChargerKW, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("kW").foregroundColor(.jouleMuted)
                    }
                } footer: {
                    Text(LocalizedStringKey(tariffType.description))
                }
                
                // Section 4: Hardware Efficiencies
                Section {
                    HStack {
                        Label("AC Efficiency (OBC)", systemImage: "bolt.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        Text(String(format: "%.0f%%", acEfficiency * 100))
                            .foregroundColor(.jouleMuted)
                    }
                    
                    HStack {
                        Label("DC Fast Efficiency", systemImage: "bolt.badge.clock.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        Text(String(format: "%.0f%%", dcEfficiency * 100))
                            .foregroundColor(.jouleMuted)
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
                            .foregroundStyle(Color.jouleInk)
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
                        Text(GasComparisonSettings.efficiencyUnit(unitSystem: unitSystem)).foregroundColor(.jouleMuted)
                    }
                    
                    HStack {
                        Label("Fuel Price", systemImage: "tag.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("\(appCurrency.symbol)/\(GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))", value: $gasFuelPrice, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("\(appCurrency.symbol)/\(GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))").foregroundColor(.jouleMuted)
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
                                        .font(.joule(.body))
                                    Text(store.syncStatus.statusDescription)
                                        .font(.joule(.caption))
                                        .foregroundColor(.jouleMuted)
                                }
                            } icon: {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundStyle(Color.joulePositive)
                            }
                            Spacer()
                        }
                        
                        if let email = auth.userEmail {
                            HStack {
                                Label("Google Account", systemImage: "person.crop.circle.fill")
                                    .foregroundColor(.jouleInk)
                                Spacer()
                                Text(email)
                                    .font(.joule(.subheadline))
                                    .foregroundColor(.jouleMuted)
                                    .lineLimit(1)
                            }
                        } else if let uid = auth.state.userID {
                            HStack {
                                Label("Account ID", systemImage: "person.crop.circle")
                                    .foregroundColor(.jouleInk)
                                Spacer()
                                Text(uid)
                                    .font(.joule(.caption2))
                                    .foregroundColor(.jouleMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        HStack {
                            Label("Synced Sessions", systemImage: "tray.full.fill")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            Text("\(store.sessions.count)")
                                .foregroundColor(.jouleMuted)
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
                                        .font(.joule(.caption))
                                        .foregroundColor(.jouleDeferred)
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
                                Label("Local Mode (Offline-First)", systemImage: "internaldrive")
                                    .font(.joule(.headline))
                                    .foregroundStyle(Color.jouleInk)
                                Spacer()
                                JouleTag("Offline", foreground: .jouleDeferredOnSoft, background: .jouleDeferredSoft)
                            }
                            Text("All charging sessions and battery analytics are stored locally on this device. Sign in with Google to enable automatic cloud backup and cross-device sync.")
                                .font(.joule(.caption))
                                .foregroundColor(.jouleMuted)
                        }
                        .padding(.vertical, 4)
                        
                        HStack {
                            Label("Local Sessions", systemImage: "tray.full.fill")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            Text("\(store.sessions.count)")
                                .foregroundColor(.jouleMuted)
                        }

                        Button {
                            store.cleanDuplicates()
                        } label: {
                            HStack {
                                Label("Clean Up Duplicate Sessions", systemImage: "sparkles.rectangle.stack")
                                Spacer()
                                if store.duplicateSessionsCount > 0 {
                                    Text("\(store.duplicateSessionsCount) found")
                                        .font(.joule(.caption))
                                        .foregroundColor(.jouleDeferred)
                                }
                            }
                        }
                        
                        Button {
                            auth.signIn()
                        } label: {
                            Label("Sign in with Google to Sync", systemImage: "icloud.and.arrow.up")
                        }
                        .buttonStyle(JoulePrimaryButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
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
            .jouleTabBarClearance()
            // A sheet inherits the tab bar height from whatever presented it, but has no bar.
            .environment(\.jouleTabBarHeight, presentation == .tab ? tabBarHeight : 0)
            .joulePage()
            .navigationTitle(presentation == .tab ? "Garage" : "Settings")
            .navigationBarTitleDisplayMode(presentation == .tab ? .large : .inline)
            .toolbar {
                if presentation == .sheet {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            syncCurrentVehicleToStore()
                            dismiss()
                        }
                        .bold()
                    }
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

    private func isActive(_ vehicle: Vehicle) -> Bool {
        store.selectedVehicleId == vehicle.id || (store.selectedVehicleId == nil && vehicle.isDefault)
    }

    /// A vehicle as a selectable card: brand line, model in the display face, three specs.
    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        let active = isActive(vehicle)
        let preset = EVPresetCatalog.preset(forId: vehicle.presetId)
        return Button {
            store.selectVehicle(id: vehicle.id)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    JouleLabel(verbatim: preset?.brand ?? vehicle.chemistry.badgeTitle)
                    Spacer()
                    if vehicle.isDefault {
                        JouleTag("Default")
                    }
                    if active {
                        JouleTag("Active", foreground: .jouleOnVolt, background: .jouleVolt)
                    }
                }
                Text(vehicle.name)
                    .font(.jouleDisplay(26, relativeTo: .title))
                    .foregroundStyle(Color.jouleInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .top, spacing: 12) {
                    vehicleSpec(String(format: "%.1f kWh", vehicle.nominalCapacityKWh), vehicle.chemistry.badgeTitle)
                    vehicleSpec(unitSystem.formatDistance(km: vehicle.nominalRangeKm), vehicle.rangeStandard.rawValue)
                    vehicleSpec(String(format: "%.1f kW", vehicle.wallChargerKW), "AC")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.jouleSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(active ? Color.jouleInk : Color.jouleLine, lineWidth: active ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func vehicleSpec(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.jouleText(15, relativeTo: .subheadline).weight(.semibold))
                .foregroundStyle(Color.jouleInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(.jouleText(12, relativeTo: .caption))
                .foregroundStyle(Color.jouleMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                                                    .font(.joule(.headline))
                                                    .foregroundColor(.jouleInk)
                                                
                                                Text(preset.chemistry.badgeTitle)
                                                    .font(.joule(.caption2)).bold()
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.jouleSunken)
                                                    .foregroundColor(.jouleInk2)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Text(String(format: "%.1f kWh • %@ (%@) • %.1f kW AC", preset.nominalCapacityKWh, unitSystem.formatDistance(km: preset.nominalRangeKm), preset.rangeStandard.rawValue, preset.defaultWallChargerKW))
                                                .font(.joule(.caption))
                                                .foregroundColor(.jouleMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedPresetId == preset.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.jouleInk)
                                                .font(.joule(.title3))
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .joulePage()
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
