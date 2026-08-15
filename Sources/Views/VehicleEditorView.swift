import SwiftUI

enum VehicleEditorMode {
    case create
    case edit(Vehicle)
}

/// Sheet to create a new vehicle profile or edit an existing one.
struct VehicleEditorView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    let mode: VehicleEditorMode
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency
    
    @State private var vehicleId: String = UUID().uuidString
    @State private var name: String = VehicleProfile.defaultVehicleName
    @State private var presetId: String = EVPresetCatalog.defaultPresetId
    @State private var licensePlate: String = ""
    @State private var chemistry: BatteryChemistry = VehicleProfile.defaultChemistry
    @State private var rangeStandard: RangeStandard = VehicleProfile.defaultRangeStandard
    @State private var nominalCapacityKWh: Double = VehicleProfile.defaultNominalCapacityKWh
    @State private var nominalRangeKm: Double = VehicleProfile.defaultNominalRangeKm
    @State private var cycleLifeTo80: Double = VehicleProfile.defaultCycleLife
    @State private var acEfficiency: Double = VehicleProfile.defaultACEfficiency
    @State private var dcEfficiency: Double = VehicleProfile.defaultDCEfficiency
    @State private var wallChargerKW: Double = VehicleProfile.defaultWallChargerKW
    @State private var tariffType: HomeTariffType = .peaStandardNonTOU
    @State private var customTariffRate: Double = VehicleProfile.defaultTariffPerKWh
    @State private var gasPreset: GasBaselinePreset = GasComparisonSettings.defaultPreset
    @State private var gasEfficiencyKmPerL: Double = GasComparisonSettings.defaultEfficiencyKmPerL
    @State private var gasCustomFuelPrice: Double = GasComparisonSettings.defaultFuelPriceTHB
    @State private var isDefault: Bool = false
    @State private var createdAt: Date = Date()
    
    @State private var showingPresetSheet = false
    
    init(mode: VehicleEditorMode = .create) {
        self.mode = mode
    }
    
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
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Identity & Preset
                Section {
                    Button {
                        showingPresetSheet = true
                    } label: {
                        HStack {
                            Label("Car Model Preset", systemImage: "car.side.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Text(selectedPreset?.displayName ?? "Custom Model")
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
                        TextField("Vehicle Name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Label("License Plate", systemImage: "tag.fill")
                            .foregroundColor(.purple)
                        Spacer()
                        TextField("Optional (e.g. 1AB-2345)", text: $licensePlate)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Vehicle Identity")
                } footer: {
                    Text("Select a factory preset or enter a custom name and registration details.")
                }
                
                // Section 2: Battery Specifications
                Section {
                    Picker("Battery Chemistry", selection: $chemistry) {
                        ForEach(BatteryChemistry.allCases) { chem in
                            Text(chem.rawValue).tag(chem)
                        }
                    }
                    .onChange(of: chemistry) { _, newChem in
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
                        Label("Factory Rated Range", systemImage: "speedometer")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("Range", value: nominalRangeBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text(unitSystem.distanceUnit).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Cycle Life to 80% SoH", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundColor(.cyan)
                        Spacer()
                        TextField("Cycles", value: $cycleLifeTo80, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("cycles").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Battery Specifications")
                }
                
                // Section 3: Charging Efficiency & Wall Charger
                Section {
                    HStack {
                        Label("AC Charging Efficiency", systemImage: "powerplug.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(String(format: "%.0f%%", acEfficiency * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $acEfficiency, in: 0.75...0.98, step: 0.01) {
                        Text("AC Efficiency")
                    }
                    
                    HStack {
                        Label("DC Fast Charge Efficiency", systemImage: "bolt.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text(String(format: "%.0f%%", dcEfficiency * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $dcEfficiency, in: 0.85...0.99, step: 0.01) {
                        Text("DC Efficiency")
                    }
                    
                    HStack {
                        Label("Home Wall Charger Power", systemImage: "ev.charger.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("kW", value: $wallChargerKW, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("kW").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Charging Parameters")
                }
                
                // Section 4: Home Electricity Tariff
                Section {
                    Picker("Home Tariff Plan", selection: $tariffType) {
                        ForEach(TariffRegion.allCases) { region in
                            Section(region.rawValue) {
                                ForEach(region.tariffs) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                        }
                    }
                    
                    if tariffType == .custom {
                        HStack {
                            Label("Custom Electricity Rate", systemImage: "banknote")
                                .foregroundColor(.teal)
                            Spacer()
                            TextField("Rate", value: $customTariffRate, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("\(appCurrency.symbol)/kWh").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Electricity Tariff")
                }
                
                // Section 5: Gas Comparison Baseline
                Section {
                    Picker("ICE Vehicle Category", selection: $gasPreset) {
                        ForEach(GasBaselinePreset.allCases) { p in
                            Text(p.title(for: unitSystem)).tag(p)
                        }
                    }
                    .onChange(of: gasPreset) { _, newPreset in
                        if newPreset != .custom {
                            gasEfficiencyKmPerL = newPreset.defaultEfficiencyKmPerL
                        }
                    }
                    
                    HStack {
                        Label("Gas Fuel Efficiency", systemImage: "fuelpump.fill")
                            .foregroundColor(.indigo)
                        Spacer()
                        TextField("Efficiency", value: gasEfficiencyBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(GasComparisonSettings.efficiencyUnit(unitSystem: unitSystem)).foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Baseline Fuel Price", systemImage: "dollarsign.circle.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("Price", value: $gasCustomFuelPrice, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("\(appCurrency.symbol)/\(GasComparisonSettings.fuelVolumeUnit(unitSystem: unitSystem))").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Gas Savings Comparison")
                }
                
                // Section 6: Default Vehicle Status
                Section {
                    Toggle("Primary / Default Vehicle", isOn: $isDefault)
                } header: {
                    Text("Garage Options")
                } footer: {
                    Text("The default vehicle will be pre-selected when launching Joule and creating new charging sessions.")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPresetSheet) {
                PresetPickerView(selectedPresetId: $presetId) { preset in
                    applyPreset(preset)
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    private var navigationTitle: String {
        switch mode {
        case .create: return "Add Vehicle"
        case .edit: return "Edit Vehicle"
        }
    }
    
    private func loadInitialData() {
        switch mode {
        case .create:
            if let defaultPreset = EVPresetCatalog.preset(forId: EVPresetCatalog.defaultPresetId) {
                applyPreset(defaultPreset)
            }
            if store.vehicles.isEmpty {
                isDefault = true
            }
        case .edit(let v):
            vehicleId = v.id
            name = v.name
            presetId = v.presetId
            licensePlate = v.licensePlate ?? ""
            chemistry = v.chemistry
            rangeStandard = v.rangeStandard
            nominalCapacityKWh = v.nominalCapacityKWh
            nominalRangeKm = v.nominalRangeKm
            cycleLifeTo80 = v.cycleLifeTo80
            acEfficiency = v.acEfficiency
            dcEfficiency = v.dcEfficiency
            wallChargerKW = v.wallChargerKW
            tariffType = v.tariffType
            customTariffRate = v.customTariffRate
            gasPreset = v.gasPreset
            gasEfficiencyKmPerL = v.gasEfficiencyKmPerL
            gasCustomFuelPrice = v.gasCustomFuelPrice
            isDefault = v.isDefault
            createdAt = v.createdAt
        }
    }
    
    private func applyPreset(_ preset: EVPreset) {
        presetId = preset.id
        name = preset.displayName
        chemistry = preset.chemistry
        rangeStandard = preset.rangeStandard
        nominalCapacityKWh = preset.nominalCapacityKWh
        nominalRangeKm = preset.nominalRangeKm
        cycleLifeTo80 = preset.expectedCycleLife
        wallChargerKW = preset.defaultWallChargerKW
    }
    
    private func saveVehicle() {
        let trimmedPlate = licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPlate = trimmedPlate.isEmpty ? nil : trimmedPlate
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "My EV" : trimmedName
        
        let vehicle = Vehicle(
            id: vehicleId,
            name: finalName,
            presetId: presetId,
            licensePlate: finalPlate,
            chemistry: chemistry,
            rangeStandard: rangeStandard,
            nominalCapacityKWh: nominalCapacityKWh,
            nominalRangeKm: nominalRangeKm,
            cycleLifeTo80: cycleLifeTo80,
            acEfficiency: acEfficiency,
            dcEfficiency: dcEfficiency,
            wallChargerKW: wallChargerKW,
            tariffType: tariffType,
            customTariffRate: customTariffRate,
            gasPreset: gasPreset,
            gasEfficiencyKmPerL: gasEfficiencyKmPerL,
            gasCustomFuelPrice: gasCustomFuelPrice,
            isDefault: isDefault,
            createdAt: createdAt
        )
        
        switch mode {
        case .create:
            store.addVehicle(vehicle, setAsActive: true)
        case .edit:
            store.updateVehicle(vehicle)
        }
        
        dismiss()
    }
}
