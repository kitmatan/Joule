import SwiftUI

/// Reusable navigation & toolbar dropdown menu for switching active vehicle profile or managing the garage.
struct GarageSwitcherMenu: View {
    @EnvironmentObject private var store: SessionStore
    var allowAllOption: Bool = true

    @State private var showingGarageManagement = false
    @State private var showingAddVehicle = false
    
    private var labelTitle: String {
        if let selectedId = store.selectedVehicleId, let vehicle = store.vehicle(for: selectedId) {
            return vehicle.name
        }
        if store.selectedVehicleId == nil && allowAllOption && store.vehicles.count > 1 {
            return String(localized: "All Vehicles")
        }
        return store.activeVehicle.name
    }

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
                                Text(LocalizedStringKey(" (Default)"))
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
                            Text(LocalizedStringKey("All Garage Vehicles"))
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
                    Label(String(format: String(localized: "Manage Garage (%lld)…"), Int64(store.vehicles.count)), systemImage: "car.2.fill")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "car.side.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text(LocalizedStringKey(labelTitle))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)

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
