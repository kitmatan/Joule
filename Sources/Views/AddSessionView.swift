import SwiftUI

struct AddSessionView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    let sessionToEdit: ChargingSession?
    
    init(sessionToEdit: ChargingSession? = nil) {
        self.sessionToEdit = sessionToEdit
        
        if let session = sessionToEdit {
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

    private var isHomeCharging: Bool { locationType == .home }

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
        if isHomeCharging, fee == 0, energy > 0 {
            fee = homeFee(forEnergy: energy)
        }

        let derivedSpeed = minutes > 0 ? ((energy / (minutes / 60.0)) * 100).rounded() / 100 : 0
        let finalSpeed = (isSpeedManual && speed > 0) ? speed : derivedSpeed

        return (
            energy: energy,
            minutes: minutes,
            fee: fee,
            speed: finalSpeed,
            total: fee + bookingFee + overtimeFee
        )
    }

    var computedTotalPrice: Double { resolved.total }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Location Type", selection: $locationType) {
                        Text("Public").tag(LocationType.publicStation)
                        Text("Home").tag(LocationType.home)
                        Text("Work").tag(LocationType.work)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: locationType) { oldValue, newValue in
                        switch newValue {
                        case .home:
                            paymentStatus = .deferred
                            chargingType = .ac
                            if locationName.isEmpty { locationName = "Home" }
                            applyHomeEstimate()
                        case .publicStation, .work:
                            guard oldValue == .home else { break }
                            paymentStatus = .paidUpfront
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
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("Required", text: $locationName)
                            .multilineTextAlignment(.trailing)
                            .disabled(isHomeCharging)
                            .foregroundColor(isHomeCharging ? .secondary : .primary)
                    }
                    if !isHomeCharging {
                        HStack {
                            Label("Vendor", systemImage: "building.2")
                                .foregroundColor(.purple)
                            Spacer()
                            TextField("Optional", text: $vendorName)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    HStack {
                        Label("Date & Time", systemImage: "calendar.badge.clock")
                            .foregroundColor(.red)
                        Spacer()
                        ZStack(alignment: .trailing) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute().locale(Locale(identifier: "en_US_POSIX"))))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(8)
                                .allowsHitTesting(false)
                                
                            DatePicker("", selection: $date)
                                .labelsHidden()
                                .environment(\.calendar, Calendar(identifier: .gregorian))
                                .environment(\.locale, Locale(identifier: "en_US"))
                                .opacity(0.011)
                        }
                    }
                    HStack {
                        Label("Mileage", systemImage: "speedometer")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("km", value: $mileage, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                } header: {
                    Text("Basic Info")
                }
                
                // Section: Battery & Range
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Battery SoC (%)").font(.subheadline).foregroundColor(.secondary)
                            if isSoCInvalid {
                                Spacer()
                                Text("Invalid SoC range")
                                    .font(.caption2).bold()
                                    .foregroundColor(.red)
                            }
                        }
                        HStack {
                            Label("Start", systemImage: "battery.25")
                                .foregroundColor(.gray)
                            TextField("0", value: $startPercentage, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: startPercentage) { applyHomeEstimate() }

                            Label("End", systemImage: "battery.100")
                                .foregroundColor(.green)
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
                        Text("Estimated Range (km)").font(.subheadline).foregroundColor(.secondary)
                        HStack {
                            Label("Start", systemImage: "car")
                                .foregroundColor(.gray)
                            TextField("0", value: $startRange, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            
                            Label("End", systemImage: "car.fill")
                                .foregroundColor(.green)
                            TextField("0", value: $endRange, format: .number)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Label("Duration", systemImage: "clock.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("min", value: $durationMinutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: durationMinutes) {
                                if !isSpeedManual { calculateSpeed() }
                            }
                        Text("min").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Energy", systemImage: "bolt.fill")
                            .foregroundColor(.yellow)
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
                        Text("kWh").foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Speed", systemImage: "bolt.badge.clock.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("kW", value: $speed, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: speed) {
                                isSpeedManual = true
                            }
                        Text("kW").foregroundColor(.secondary)
                        
                        if isSpeedManual {
                            Button("Auto") {
                                isSpeedManual = false
                                calculateSpeed()
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    HStack {
                        Label("Type", systemImage: "powerplug.fill")
                            .foregroundColor(.purple)
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
                        Text("Estimated from SoC delta based on \(VehicleProfile.vehicleName) (\(VehicleProfile.nominalCapacityKWh, specifier: "%.1f") kWh @ \(VehicleProfile.acEfficiency * 100, specifier: "%.0f")% efficiency, \(VehicleProfile.wallChargerKW, specifier: "%.1f") kW wall charger).")
                    }
                }
                
                // Section: Home Tariff (if home)
                if isHomeCharging {
                    Section {
                        Picker("Tariff Rate", selection: $homeTariff) {
                            ForEach(HomeTariffType.allCases) { tariff in
                                Text(tariff.rawValue).tag(tariff)
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
                        Text(homeTariff.description)
                    }
                }
                
                // Section: Fees
                Section {
                    HStack {
                        Label("Charging Fee", systemImage: "bolt.car")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("0.00", value: $chargingFee, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    HStack {
                        Label("Booking Fee", systemImage: "calendar.badge.clock")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("0.00", value: $bookingFee, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    HStack {
                        Label("Overtime Fee", systemImage: "clock.badge.exclamationmark")
                            .foregroundColor(.red)
                        Spacer()
                        TextField("0.00", value: $overtimeFee, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                } header: {
                    HStack {
                        Text("Fees")
                        Spacer()
                        Text("Total: \(computedTotalPrice.formatted(.currency(code: "THB").presentation(.narrow)))")
                            .font(.headline)
                            .foregroundColor(computedTotalPrice > 0 ? .green : .secondary)
                    }
                    .padding(.bottom, 4)
                } footer: {
                    if isHomeCharging {
                        Text("Deferred to your electric bill.")
                    }
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Label("Notes", systemImage: "note.text")
                }
            }
            .navigationTitle(sessionToEdit == nil ? "Joule." : "Edit Session")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(!canSave)
                }
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

        let energy = (VehicleProfile.wallEnergyKWh(socDelta: end - start) * 10).rounded() / 10
        let endsFull = end >= VehicleProfile.fullChargeSoC
        let minutes = VehicleProfile.durationMinutes(wallEnergyKWh: energy, endsFull: endsFull).rounded()

        return (energy, minutes)
    }

    private func homeFee(forEnergy kWh: Double) -> Double {
        let rate = homeTariff == .custom ? VehicleProfile.customTariffRate : homeTariff.defaultRate
        return (VehicleProfile.homeCost(wallEnergyKWh: kWh, rateOverride: rate) * 100).rounded() / 100
    }

    private func applyHomeEstimate(overwriting: Bool = true) {
        guard isHomeCharging else { return }

        if let estimate = homeEstimate, overwriting || energyAdded == 0 {
            energyAdded = estimate.energy
            durationMinutes = estimate.minutes
        }

        if energyAdded > 0, overwriting || chargingFee == 0 {
            chargingFee = homeFee(forEnergy: energyAdded)
        }

        if !isSpeedManual {
            calculateSpeed()
        }
    }
    
    private func save() {
        var newSession = sessionToEdit ?? ChargingSession()
        let values = resolved

        newSession.locationName = locationName.isEmpty ? "Unknown Location" : locationName
        newSession.vendorName = vendorName.isEmpty ? nil : vendorName
        newSession.date = date
        newSession.duration = values.minutes * 60
        newSession.energyAdded = values.energy
        newSession.speed = values.speed
        newSession.chargingFee = values.fee
        newSession.bookingFee = bookingFee
        newSession.overtimeFee = overtimeFee
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
