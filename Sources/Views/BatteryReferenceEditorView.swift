import SwiftUI

/// Records a State of Health figure measured outside the app — a dealer BMS readout, an OBD scan,
/// or an inspection report — and lists the readings already on file.
///
/// These are stored alongside, never in place of, the app's own charger-side estimate.
struct BatteryReferenceEditorView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem

    let vehicle: Vehicle

    private enum Field: Hashable { case soh, odometer, tool, notes }
    @FocusState private var focusedField: Field?

    @State private var editingID: String?
    @State private var date = Date()
    @State private var sohPercent: Double = 100.0
    @State private var odometer: Double?
    @State private var source: BatteryReferenceSource = .dealer
    @State private var toolName: String = ""
    @State private var notes: String = ""

    private var existingReadings: [BatteryHealthReference] {
        (store.vehicle(for: vehicle.id) ?? vehicle).referenceReadings.reversed()
    }

    private var isValid: Bool {
        sohPercent > 0 && sohPercent <= 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date Measured", selection: $date, in: ...Date(), displayedComponents: .date)

                    HStack {
                        Text("Measured SoH")
                        Spacer()
                        TextField("Percent", value: $sohPercent, format: .number)
                            .focused($focusedField, equals: .soh)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        // verbatim: a bare "%" would be extracted into the string catalog as a
                        // translatable key with no sensible translation in any language.
                        Text(verbatim: "%").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField("Optional", value: $odometer, format: .number)
                            .focused($focusedField, equals: .odometer)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(unitSystem.distanceUnit).foregroundColor(.secondary)
                    }
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Enter the figure exactly as the service tool reported it. Joule stores it as a separate record and never merges it into its own estimate.")
                }

                Section {
                    Picker("Source", selection: $source) {
                        ForEach(BatteryReferenceSource.allCases) { option in
                            Label(option.displayName, systemImage: option.icon).tag(option)
                        }
                    }

                    TextField("Tool or Workshop", text: $toolName)
                        .focused($focusedField, equals: .tool)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .lineLimit(2...4)
                } header: {
                    Text("Provenance")
                } footer: {
                    Text("Recorded on the battery certificate so a buyer or insurer can see who measured the figure.")
                }

                if !existingReadings.isEmpty {
                    Section("Readings on File") {
                        ForEach(existingReadings) { reading in
                            Button {
                                load(reading)
                            } label: {
                                readingRow(reading)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(editingID == nil ? "Add Service Reading" : "Edit Service Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commitEditsThenSave() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func readingRow(_ reading: BatteryHealthReference) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.date.formatted(.dateTime.year().month(.abbreviated).day()))
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                Label(reading.source.displayName, systemImage: reading.source.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "%.1f%%", reading.sohPercent))
                .font(.headline)
                .foregroundColor(.primary)
        }
        .contentShape(Rectangle())
    }

    private func load(_ reading: BatteryHealthReference) {
        editingID = reading.id
        date = reading.date
        sohPercent = reading.sohPercent
        odometer = reading.odometerKm.map { unitSystem.convertFromKm($0) }
        source = reading.source
        toolName = reading.toolName ?? ""
        notes = reading.notes ?? ""
    }

    /// The vehicle as the store currently holds it.
    ///
    /// `activeVehicle` falls back to a synthetic profile when the garage is empty, and that profile
    /// is not in `store.vehicles`. Looking it up and bailing out would make Save do nothing at all,
    /// so fall back to the vehicle handed to this view — `updateVehicle` adds it if it is new.
    private func currentVehicle() -> Vehicle {
        store.vehicle(for: vehicle.id) ?? vehicle
    }

    private func delete(at offsets: IndexSet) {
        var target = currentVehicle()
        let doomed = offsets.map { existingReadings[$0].id }
        for id in doomed {
            target.removeReferenceReading(id: id)
            if editingID == id { editingID = nil }
        }
        store.updateVehicle(target)
    }

    /// Tapping a toolbar button does not always resign the focused text field first, so a value
    /// still being typed would be read as its previous one. Drop focus, let SwiftUI push the
    /// committed value through the binding, then save.
    private func commitEditsThenSave() {
        guard focusedField != nil else {
            save()
            return
        }
        focusedField = nil
        DispatchQueue.main.async { save() }
    }

    private func save() {
        var target = currentVehicle()
        let trimmedTool = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        target.upsertReferenceReading(
            BatteryHealthReference(
                id: editingID ?? UUID().uuidString,
                date: date,
                sohPercent: min(100.0, max(0.0, sohPercent)),
                odometerKm: odometer.map { unitSystem.convertToKm($0) },
                source: source,
                toolName: trimmedTool.isEmpty ? nil : trimmedTool,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        )
        store.updateVehicle(target)
        dismiss()
    }
}
