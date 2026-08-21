import SwiftUI

/// Management view listing all vehicles in the user's garage with stats and configuration actions.
struct GarageManagementView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    
    @State private var vehicleToEdit: Vehicle?
    @State private var vehicleToDelete: Vehicle?
    @State private var showingAddVehicle = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.vehicles) { vehicle in
                        VehicleCardRow(
                            vehicle: vehicle,
                            isActive: store.selectedVehicleId == vehicle.id || (store.selectedVehicleId == nil && vehicle.isDefault),
                            sessionCount: store.sessions.filter { $0.vehicleId == vehicle.id || ($0.vehicleId == nil && vehicle.isDefault) }.count,
                            totalEnergy: store.sessions.filter { $0.vehicleId == vehicle.id || ($0.vehicleId == nil && vehicle.isDefault) }.reduce(0) { $0 + $1.energyAdded },
                            onSelect: {
                                store.selectVehicle(id: vehicle.id)
                            },
                            onSetDefault: {
                                store.setDefaultVehicle(vehicle)
                            },
                            onEdit: {
                                vehicleToEdit = vehicle
                            },
                            onDelete: {
                                vehicleToDelete = vehicle
                            },
                            canDelete: store.vehicles.count > 1
                        )
                    }
                } header: {
                    Text(String(format: String(localized: "Your Vehicles (%lld)"), Int64(store.vehicles.count)))
                } footer: {
                    Text("Select a vehicle to set it as active across your dashboard, charging forms, and battery analytics.")
                }
            }
            .navigationTitle("Garage Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                VehicleEditorView(mode: .create)
            }
            .sheet(item: $vehicleToEdit) { vehicle in
                VehicleEditorView(mode: .edit(vehicle))
            }
            .confirmationDialog(
                "Delete Vehicle Profile?",
                isPresented: Binding(
                    get: { vehicleToDelete != nil },
                    set: { if !$0 { vehicleToDelete = nil } }
                ),
                presenting: vehicleToDelete
            ) { vehicle in
                Button(String(format: String(localized: "Delete \"%@\""), vehicle.name), role: .destructive) {
                    store.deleteVehicle(vehicle)
                    vehicleToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    vehicleToDelete = nil
                }
            } message: { vehicle in
                Text(String(format: String(localized: "Are you sure you want to delete %@? Any charging sessions previously linked to this car will remain in your history and reassign to your primary vehicle."), vehicle.name))
            }
        }
    }
}

/// A rich vehicle summary card row in Garage Management.
struct VehicleCardRow: View {
    let vehicle: Vehicle
    let isActive: Bool
    let sessionCount: Int
    let totalEnergy: Double
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool
    
    @AppStorage("app_unit_system") private var unitSystem: UnitSystem = VehicleProfile.defaultUnitSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "car.side.fill")
                    .font(.title2)
                    .foregroundColor(isActive ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(vehicle.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if vehicle.isDefault {
                            Text("Default")
                                .font(.caption2).bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                        
                        if isActive {
                            Text("Active")
                                .font(.caption2).bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let plate = vehicle.licensePlate, !plate.isEmpty {
                        Text(String(format: String(localized: "Plate: %@"), plate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Specs pill
                HStack(spacing: 4) {
                    Text(vehicle.chemistry.badgeTitle)
                        .font(.caption2).bold()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(vehicle.chemistry == .lfp ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .foregroundColor(vehicle.chemistry == .lfp ? .blue : .purple)
                        .clipShape(Capsule())
                    
                    Text(String(format: "%.1f kWh", vehicle.nominalCapacityKWh))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(unitSystem.formatDistance(km: vehicle.nominalRangeKm))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: String(localized: "%1$lld sessions (%2$.0f kWh)"), Int64(sessionCount), totalEnergy))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if !isActive {
                    Button("Make Active") {
                        onSelect()
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                if !vehicle.isDefault {
                    Button("Set as Default") {
                        onSetDefault()
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}
