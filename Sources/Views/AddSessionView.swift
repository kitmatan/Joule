import SwiftUI

struct AddSessionView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    let sessionToEdit: ChargingSession?
    
    init(sessionToEdit: ChargingSession? = nil) {
        self.sessionToEdit = sessionToEdit
        
        if let session = sessionToEdit {
            _selectedVehicleId = State(initialValue: session.vehicleId ?? "")
            _locationName = State(initialValue: session.locationName ?? "")
            _vendorName = State(initialValue: session.vendorName ?? "")
            _date = State(initialValue: session.date)
            _durationMinutes = State(initialValue: session.duration / 60)
            _energyAdded = State(initialValue: session.energyAdded)
            _speed = State(initialValue: session.speed)
            _isSpeedManual = State(initialValue: session.speed > 0)
            _chargingFee = State(initialValue: session.chargingFee)
            _bookingFee = State(initialValue: session.bookingFee)
            _overtimeFee = State(initialValue: session.overtimeFee)
            _mileage = State(initialValue: session.mileage)
            _startPercentage = State(initialValue: session.startPercentage)
            _endPercentage = State(initialValue: session.endPercentage)
            _startRange = State(initialValue: session.startRange)
            _endRange = State(initialValue: session.endRange)
            _chargingType = State(initialValue: session.chargingType ?? .dc)
            _locationType = State(initialValue: session.locationType ?? .publicStation)
            _paymentStatus = State(initialValue: session.paymentStatus ?? .paidUpfront)
            _notes = State(initialValue: session.notes ?? "")
        }
    }
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    @AppStorage("app_currency") private var appCurrency: AppCurrency = VehicleProfile.defaultCurrency

    @State private var selectedVehicleId: String = ""
    @State private var locationName = ""
    @State private var vendorName = ""
    @State private var date = Date()
    @State private var durationMinutes: Double = 30
    @State private var energyAdded: Double = 0.0
    @State private var speed: Double = 0.0
    @State private var isSpeedManual: Bool = false
    @State private var chargingFee: Double = 0.0
    @State private var bookingFee: Double = 0.0
    @State private var overtimeFee: Double = 0.0
    @State private var mileage: Double?
    @State private var startPercentage: Double?
    @State private var endPercentage: Double?
    @State private var startRange: Double?
    @State private var endRange: Double?
    @State private var chargingType: ChargingType = .dc
    @State private var locationType: LocationType = .publicStation
    @State private var paymentStatus: PaymentStatus = .paidUpfront
    @State private var homeTariff: HomeTariffType = VehicleProfile.tariffType
    @State private var notes = ""
    @State private var showingScanner = false

    private var currentVehicle: Vehicle {
        if !selectedVehicleId.isEmpty, let v = store.vehicle(for: selectedVehicleId) {
            return v
        }
        return store.activeVehicle
    }

    private var isHomeCharging: Bool { locationType == .home }

    private var isFree: Bool { paymentStatus == .free }

    /// Marking a session free zeroes every fee; clearing it restores the payment status
    /// implied by the location and re-derives the home tariff estimate.
    private var freeChargingBinding: Binding<Bool> {
        Binding(
            get: { isFree },
            set: { newValue in
                if newValue {
                    paymentStatus = .free
                    chargingFee = 0
                    bookingFee = 0
                    overtimeFee = 0
                } else {
                    paymentStatus = isHomeCharging ? .deferred : .paidUpfront
                    if isHomeCharging, energyAdded > 0 {
                        chargingFee = homeFee(forEnergy: energyAdded)
                    }
                }
            }
        )
    }

    private var mileageBinding: Binding<Double?> {
        Binding(
            get: {
                guard let m = mileage else { return nil }
                return Double(String(format: "%.1f", unitSystem.convertFromKm(m))) ?? unitSystem.convertFromKm(m)
            },
            set: {
                if let val = $0 {
                    mileage = unitSystem.convertToKm(val)
                } else {
                    mileage = nil
                }
            }
        )
    }

    private var startRangeBinding: Binding<Double?> {
        Binding(
            get: {
                guard let r = startRange else { return nil }
                return Double(String(format: "%.0f", unitSystem.convertFromKm(r))) ?? unitSystem.convertFromKm(r)
            },
            set: {
                if let val = $0 {
                    startRange = unitSystem.convertToKm(val)
                } else {
                    startRange = nil
                }
            }
        )
    }

    private var endRangeBinding: Binding<Double?> {
        Binding(
            get: {
                guard let r = endRange else { return nil }
                return Double(String(format: "%.0f", unitSystem.convertFromKm(r))) ?? unitSystem.convertFromKm(r)
            },
            set: {
                if let val = $0 {
                    endRange = unitSystem.convertToKm(val)
                } else {
                    endRange = nil
                }
            }
        )
    }

    // Validation
    private var isSoCInvalid: Bool {
        if let s = startPercentage, let e = endPercentage {
            return e < s || s < 0 || s > 100 || e < 0 || e > 100
        }
        if let s = startPercentage { return s < 0 || s > 100 }
        if let e = endPercentage { return e < 0 || e > 100 }
        return false
    }

    private var canSave: Bool {
        if isSoCInvalid { return false }
        if isHomeCharging {
            return true
        }
        return !locationName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The values that will actually be persisted.
    private var resolved: (energy: Double, minutes: Double, fee: Double, speed: Double, total: Double) {
        var energy = energyAdded
        var minutes = durationMinutes
        if energy == 0, let estimate = homeEstimate {
            energy = estimate.energy
            minutes = estimate.minutes
        }

        var fee = chargingFee
        if isFree {
            fee = 0
        } else if isHomeCharging, fee == 0, energy > 0 {
            fee = homeFee(forEnergy: energy)
        }

        let derivedSpeed = minutes > 0 ? ((energy / (minutes / 60.0)) * 100).rounded() / 100 : 0
        let finalSpeed = (isSpeedManual && speed > 0) ? speed : derivedSpeed

        return (
            energy: energy,
            minutes: minutes,
            fee: fee,
            speed: finalSpeed,
            total: isFree ? 0 : fee + bookingFee + overtimeFee
        )
    }

    var computedTotalPrice: Double { resolved.total }

    var body: some View {
        NavigationStack {
            Form {
                if store.vehicles.count > 1 {
                    Section {
                        Picker("Vehicle", selection: $selectedVehicleId) {
                            ForEach(store.vehicles) { v in
                                Text(v.name).tag(v.id)
                            }
                        }
                        .onChange(of: selectedVehicleId) { _, newId in
                            if let v = store.vehicle(for: newId) {
                                homeTariff = v.tariffType
                                applyHomeEstimate()
                            }
                        }
                    } header: {
                        Label("Vehicle", systemImage: "car.side.fill")
                    }
                }
                
                Section {
                    JoulePillPicker(
                        options: [(LocationType.home, "Home"), (.publicStation, "Public"), (.work, "Work")],
                        selection: $locationType,
                        accessibilityTitle: "Location Type"
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .onChange(of: locationType) { oldValue, newValue in
                        switch newValue {
                        case .home:
                            if !isFree { paymentStatus = .deferred }
                            chargingType = .ac
                            if locationName.isEmpty { locationName = "Home" }
                            applyHomeEstimate()
                        case .publicStation, .work:
                            guard oldValue == .home else { break }
                            if !isFree { paymentStatus = .paidUpfront }
                            if locationName == "Home" { locationName = "" }
                            chargingType = .dc
                            chargingFee = 0
                        }
                    }
                } header: {
                    Label("Location Type", systemImage: "mappin.and.ellipse")
                } footer: {
                    if isHomeCharging {
                        Text("Home sessions default to AC charging with the cost deferred to your electric bill.")
                    }
                }
                
                Section {
                    HStack {
                        Label("Location", systemImage: "mappin.and.ellipse")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("Required", text: $locationName)
                            .multilineTextAlignment(.trailing)
                            .disabled(isHomeCharging)
                            .foregroundColor(isHomeCharging ? .jouleMuted : .jouleInk)
                    }
                    if !isHomeCharging {
                        HStack {
                            Label("Vendor", systemImage: "building.2")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            TextField("Optional", text: $vendorName)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    HStack {
                        Label("Date & Time", systemImage: "calendar.badge.clock")
                            .foregroundStyle(Color.jouleInk)
                            .lineLimit(1)
                            .fixedSize()
                        Spacer()
                        ZStack(alignment: .trailing) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.jouleSunken)
                                .cornerRadius(8)
                                .allowsHitTesting(false)
                                
                            DatePicker("", selection: $date)
                                .labelsHidden()
                                .environment(\.calendar, Calendar(identifier: .gregorian))
                                .environment(\.locale, .current)
                                .opacity(0.011)
                        }
                    }
                    HStack {
                        Label("Mileage", systemImage: "speedometer")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField(unitSystem.distanceUnit, value: mileageBinding, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(unitSystem.distanceUnit).foregroundColor(.jouleMuted)
                    }
                } header: {
                    Text("Basic Info")
                }
                
                // Section: Battery & Range
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SoCRangeBar(start: startPercentage, end: endPercentage)
                            .padding(.top, 4)
                        HStack {
                            Text("Battery SoC (%)").font(.joule(.subheadline)).foregroundColor(.jouleMuted)
                            if isSoCInvalid {
                                Spacer()
                                Text("Invalid SoC range")
                                    .font(.joule(.caption2)).bold()
                                    .foregroundColor(.jouleDanger)
                            }
                        }
                        HStack {
                            Label("Start", systemImage: "battery.25")
                                .foregroundStyle(Color.jouleInk)
                                .labelStyle(.titleOnly)
                                .fixedSize()
                            TextField("0", value: $startPercentage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: startPercentage) { applyHomeEstimate() }

                            Label("End", systemImage: "battery.100")
                                .foregroundStyle(Color.jouleInk)
                                .labelStyle(.titleOnly)
                                .fixedSize()
                            TextField("100", value: $endPercentage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: endPercentage) { applyHomeEstimate() }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(format: String(localized: "Estimated Range (%@)"), unitSystem.distanceUnit)).font(.joule(.subheadline)).foregroundColor(.jouleMuted)
                        HStack {
                            Label("Start", systemImage: "car")
                                .foregroundStyle(Color.jouleInk)
                                .labelStyle(.titleOnly)
                                .fixedSize()
                            TextField("0", value: startRangeBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            
                            Label("End", systemImage: "car.fill")
                                .foregroundStyle(Color.jouleInk)
                                .labelStyle(.titleOnly)
                                .fixedSize()
                            TextField("0", value: endRangeBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Label("Duration", systemImage: "clock.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("min", value: $durationMinutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: durationMinutes) {
                                if !isSpeedManual { calculateSpeed() }
                            }
                        Text("min").foregroundColor(.jouleMuted)
                    }
                    
                    HStack {
                        Label("Energy", systemImage: "bolt.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("kWh", value: $energyAdded, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: energyAdded) {
                                if !isSpeedManual { calculateSpeed() }
                                if isHomeCharging, energyAdded > 0 {
                                    chargingFee = homeFee(forEnergy: energyAdded)
                                }
                            }
                        Text("kWh").foregroundColor(.jouleMuted)
                    }
                    
                    HStack {
                        Label("Speed", systemImage: "bolt.badge.clock.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        TextField("kW", value: $speed, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: speed) {
                                isSpeedManual = true
                            }
                        Text("kW").foregroundColor(.jouleMuted)
                        
                        if isSpeedManual {
                            Button("Auto") {
                                isSpeedManual = false
                                calculateSpeed()
                            }
                            .font(.joule(.caption2))
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    HStack {
                        Label("Type", systemImage: "powerplug.fill")
                            .foregroundStyle(Color.jouleInk)
                        Spacer()
                        Picker("Type", selection: $chargingType) {
                            Text("AC").tag(ChargingType.ac)
                            Text("DC").tag(ChargingType.dc)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 120)
                        .disabled(isHomeCharging)
                    }
                } header: {
                    Text("Charging Details")
                } footer: {
                    if isHomeCharging {
                        Text("Estimated from SoC delta based on \(currentVehicle.name) (\(currentVehicle.nominalCapacityKWh, specifier: "%.1f") kWh @ \(currentVehicle.acEfficiency * 100, specifier: "%.0f")% efficiency, \(currentVehicle.wallChargerKW, specifier: "%.1f") kW wall charger).")
                    }
                }
                
                // Section: Home Tariff (if home)
                if isHomeCharging {
                    Section {
                        Picker("Tariff Rate", selection: $homeTariff) {
                            ForEach(TariffRegion.allCases) { region in
                                Section(LocalizedStringKey(region.rawValue)) {
                                    ForEach(region.tariffs) { tariff in
                                        Text(LocalizedStringKey(tariff.rawValue)).tag(tariff)
                                    }
                                }
                            }
                        }
                        .onChange(of: homeTariff) { _, newTariff in
                            if energyAdded > 0 {
                                chargingFee = homeFee(forEnergy: energyAdded)
                            }
                        }
                    } header: {
                        Text("Electricity Tariff")
                    } footer: {
                        Text(LocalizedStringKey(homeTariff.description))
                    }
                }
                
                // Section: Fees
                Section {
                    Toggle(isOn: freeChargingBinding) {
                        Label("Free Charging", systemImage: "gift.fill")
                            .foregroundStyle(Color.jouleInk)
                    }

                    if !isFree {
                        HStack {
                            Label("Charging Fee", systemImage: "bolt.car")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            TextField("0.00", value: $chargingFee, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        HStack {
                            Label("Booking Fee", systemImage: "calendar.badge.clock")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            TextField("0.00", value: $bookingFee, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        HStack {
                            Label("Overtime Fee", systemImage: "clock.badge.exclamationmark")
                                .foregroundStyle(Color.jouleInk)
                            Spacer()
                            TextField("0.00", value: $overtimeFee, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                } header: {
                    HStack {
                        Text(String(format: String(localized: "Fees (%@)"), appCurrency.code))
                        Spacer()
                        Text(String(format: String(localized: "Total: %@"), appCurrency.format(computedTotalPrice)))
                            .font(.joule(.headline))
                            .foregroundColor(computedTotalPrice > 0 ? .joulePositive : .jouleMuted)
                    }
                    .padding(.bottom, 4)
                } footer: {
                    if isFree {
                        Text("Logged at no cost. The energy still counts toward your stats and gas savings.")
                    } else if isHomeCharging {
                        Text("Deferred to your electric bill.")
                    }
                }
                
                Section {
                    estimateCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Label("Notes", systemImage: "note.text")
                }
            }
            .joulePage()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Save", action: save)
                .buttonStyle(JoulePrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.joulePaper.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle(sessionToEdit == nil ? "New Session" : "Edit Session")
            .onAppear {
                applyHomeEstimate(overwriting: false)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                    .accessibilityLabel("Scan Receipt or Meter")
                }
            }
            .sheet(isPresented: $showingScanner) {
                ReceiptScannerView { scanned in
                    applyScannedData(scanned)
                }
            }
            .onAppear {
                if selectedVehicleId.isEmpty {
                    selectedVehicleId = store.selectedVehicleId ?? store.activeVehicle.id
                }
                if let v = store.vehicle(for: selectedVehicleId) {
                    homeTariff = v.tariffType
                }
            }
        }
    }
    
    /// The live result of the form: what will be saved, in the display face on the dark card.
    private var estimateCard: some View {
        let values = resolved
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    JouleLabel("Energy", color: .jouleOnInverseMuted)
                    Text(String(format: "%.1f kWh", values.energy))
                        .font(.jouleDisplay(30, relativeTo: .title))
                        .foregroundStyle(Color.jouleOnInverse)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    JouleLabel(verbatim: String(format: String(localized: "Total: %@"), appCurrency.code), color: .jouleOnInverseMuted)
                    Text(appCurrency.format(values.total))
                        .font(.jouleDisplay(30, relativeTo: .title))
                        .foregroundStyle(Color.jouleVolt)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            if isHomeCharging, homeEstimate != nil {
                Text("Estimated from SoC delta based on \(currentVehicle.name) (\(currentVehicle.nominalCapacityKWh, specifier: "%.1f") kWh @ \(currentVehicle.acEfficiency * 100, specifier: "%.0f")% efficiency, \(currentVehicle.wallChargerKW, specifier: "%.1f") kW wall charger).")
                    .font(.jouleText(13, relativeTo: .footnote))
                    .foregroundStyle(Color.jouleOnInverseMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.jouleInverse, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func applyScannedData(_ data: ScannedChargingData) {
        if let energy = data.energyAdded {
            self.energyAdded = energy
        }
        if let cost = data.totalPrice {
            self.chargingFee = cost
        }
        if let duration = data.durationMinutes {
            self.durationMinutes = duration
        }
        if let start = data.startPercentage {
            self.startPercentage = start
        }
        if let end = data.endPercentage {
            self.endPercentage = end
        }
        if let spd = data.speedKW {
            self.speed = spd
            self.isSpeedManual = true
        } else {
            calculateSpeed()
        }
        if let vendor = data.locationOrVendor {
            if self.vendorName.isEmpty {
                self.vendorName = vendor
            }
            if self.locationName.isEmpty {
                self.locationName = vendor
            }
        }
    }
    
    private func calculateSpeed() {
        if durationMinutes > 0 && energyAdded > 0 {
            speed = ((energyAdded / (durationMinutes / 60.0)) * 100).rounded() / 100
        } else {
            speed = 0.0
        }
    }

    private var homeEstimate: (energy: Double, minutes: Double)? {
        guard isHomeCharging,
              let start = startPercentage,
              let end = endPercentage,
              end > start else { return nil }

        let energy = (currentVehicle.wallEnergyKWh(socDelta: end - start) * 10).rounded() / 10
        let endsFull = end >= 98.0
        let minutes = currentVehicle.durationMinutes(wallEnergyKWh: energy, endsFull: endsFull).rounded()

        return (energy, minutes)
    }

    private func homeFee(forEnergy kWh: Double) -> Double {
        let rate = homeTariff == .custom ? currentVehicle.customTariffRate : homeTariff.defaultRate
        return (currentVehicle.homeCost(wallEnergyKWh: kWh, rateOverride: rate) * 100).rounded() / 100
    }

    private func applyHomeEstimate(overwriting: Bool = true) {
        guard isHomeCharging else { return }

        if let estimate = homeEstimate, overwriting || energyAdded == 0 {
            energyAdded = estimate.energy
            durationMinutes = estimate.minutes
        }

        if !isFree, energyAdded > 0, overwriting || chargingFee == 0 {
            chargingFee = homeFee(forEnergy: energyAdded)
        }

        if !isSpeedManual {
            calculateSpeed()
        }
    }
    
    private func save() {
        var newSession = sessionToEdit ?? ChargingSession()
        let values = resolved

        newSession.vehicleId = selectedVehicleId.isEmpty ? store.activeVehicle.id : selectedVehicleId
        newSession.locationName = locationName.isEmpty ? "Unknown Location" : locationName
        newSession.vendorName = vendorName.isEmpty ? nil : vendorName
        newSession.date = date
        newSession.duration = values.minutes * 60
        newSession.energyAdded = values.energy
        newSession.speed = values.speed
        newSession.chargingFee = values.fee
        newSession.bookingFee = isFree ? 0 : bookingFee
        newSession.overtimeFee = isFree ? 0 : overtimeFee
        newSession.pricePerUnit = values.energy > 0 ? values.total / values.energy : 0.0
        newSession.totalPrice = values.total
        newSession.mileage = mileage
        newSession.startPercentage = startPercentage
        newSession.endPercentage = endPercentage
        newSession.startRange = startRange
        newSession.endRange = endRange
        newSession.chargingType = chargingType
        newSession.locationType = locationType
        newSession.paymentStatus = paymentStatus
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newSession.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        store.saveSession(newSession)
        dismiss()
    }
}


/// Start and end state of charge drawn on one track: the charged span in volt between two knobs.
/// Display only; the numbers are typed in the fields beneath it.
struct SoCRangeBar: View {
    let start: Double?
    let end: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let s = min(max((start ?? 0) / 100, 0), 1)
            let e = min(max((end ?? start ?? 0) / 100, s), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.jouleSunken).frame(height: 12)
                if end != nil || start != nil {
                    Rectangle()
                        .fill(Color.jouleVolt)
                        .frame(width: max(0, (e - s) * width), height: 12)
                        .offset(x: s * width)
                    knob(filled: false).offset(x: s * width - 14)
                    knob(filled: true).offset(x: e * width - 14)
                }
            }
            .frame(height: 28)
        }
        .frame(height: 28)
        .padding(.horizontal, 14)
        .accessibilityElement()
        .accessibilityLabel("Battery SoC (%)")
        .accessibilityValue(Text(String(format: "%.0f → %.0f", start ?? 0, end ?? 0)))
    }

    private func knob(filled: Bool) -> some View {
        Circle()
            .fill(filled ? Color.jouleInk : Color.jouleSurface)
            .overlay(Circle().strokeBorder(Color.jouleInk, lineWidth: 2))
            .frame(width: 28, height: 28)
    }
}
