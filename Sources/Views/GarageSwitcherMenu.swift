import SwiftUI

/// Reusable navigation & toolbar dropdown menu for switching active vehicle profile or managing the garage.
struct GarageSwitcherMenu: View {
    @EnvironmentObject private var store: SessionStore
    var allowAllOption: Bool = true
    
    @State private var showingGarageManagement = false
    @State private var showingAddVehicle = false
    
    var body: some View {
        Menu {
            Section("Garage") {
                ForEach(store.vehicles) { vehicle in
                    Button {
                        store.selectVehicle(id: vehicle.id)
                    } label: {
                        HStack {
                            Text(vehicle.name)
                            if vehicle.isDefault {
                                Text(" (Default)")
                            }
                            if store.selectedVehicleId == vehicle.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            if allowAllOption && store.vehicles.count > 1 {
                Section {
                    Button {
                        store.selectVehicle(id: nil)
                    } label: {
                        HStack {
                            Text("All Garage Vehicles")
                            if store.selectedVehicleId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section {
                Button {
                    showingAddVehicle = true
                } label: {
                    Label("Add Vehicle…", systemImage: "plus.circle")
                }
                
                Button {
                    showingGarageManagement = true
                } label: {
                    Label("Manage Garage (\(store.vehicles.count))…", systemImage: "car.2.fill")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "car.side.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                if let selectedId = store.selectedVehicleId, let vehicle = store.vehicle(for: selectedId) {
                    Text(vehicle.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                } else if store.selectedVehicleId == nil && allowAllOption && store.vehicles.count > 1 {
                    Text("All Vehicles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text(store.activeVehicle.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showingGarageManagement) {
            GarageManagementView()
        }
        .sheet(isPresented: $showingAddVehicle) {
            VehicleEditorView(mode: .create)
        }
    }
}
