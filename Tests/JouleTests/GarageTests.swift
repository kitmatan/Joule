import XCTest
@testable import Joule

final class GarageTests: XCTestCase {
    
    // MARK: - Vehicle Model & Calculations
    func testVehicleInitializationAndDefaults() {
        let v = Vehicle(
            name: "Tesla Model Y",
            presetId: "tesla_model_y_rwd",
            licensePlate: "EV-1234",
            chemistry: .lfp,
            rangeStandard: .wltp,
            nominalCapacityKWh: 60.0,
            nominalRangeKm: 455.0,
            cycleLifeTo80: 3000,
            acEfficiency: 0.88,
            dcEfficiency: 0.93,
            wallChargerKW: 7.4,
            tariffType: .peaTouOffPeak,
            customTariffRate: 2.60,
            gasPreset: .compact,
            gasEfficiencyKmPerL: 16.0,
            gasCustomFuelPrice: 38.5,
            isDefault: true
        )
        
        XCTAssertEqual(v.name, "Tesla Model Y")
        XCTAssertEqual(v.licensePlate, "EV-1234")
        XCTAssertEqual(v.chemistry, BatteryChemistry.lfp)
        XCTAssertEqual(v.nominalCapacityKWh, 60.0)
        XCTAssertTrue(v.isDefault)
        
        // Efficiency: 455 km / 60 kWh = 7.5833 km/kWh
        XCTAssertEqual(v.ratedEfficiencyKmPerKWh, 455.0 / 60.0, accuracy: 0.001)
        
        // Wall Energy for 50% SoC delta: 60 * 0.50 / 0.88 = 34.0909 kWh
        let wallEnergy = v.wallEnergyKWh(socDelta: 50.0)
        XCTAssertEqual(wallEnergy, 30.0 / 0.88, accuracy: 0.01)
        
        // Duration: wallEnergy / 7.4 * 60
        let duration = v.durationMinutes(wallEnergyKWh: wallEnergy, endsFull: false)
        XCTAssertEqual(duration, (wallEnergy / 7.4) * 60, accuracy: 0.1)
        
        // Home Cost with TOU off peak (2.63)
        let cost = v.homeCost(wallEnergyKWh: 10.0)
        XCTAssertEqual(cost, 10.0 * 2.63, accuracy: 0.01)
    }
    
    func testVehicleDefaultFromLegacy() {
        let v = Vehicle.createDefaultFromLegacy()
        XCTAssertFalse(v.id.isEmpty)
        XCTAssertTrue(v.isDefault)
        XCTAssertGreaterThan(v.nominalCapacityKWh, 0)
        XCTAssertGreaterThan(v.nominalRangeKm, 0)
    }
    
    // MARK: - Multi-Vehicle Session Filtering & Store CRUD
    func testMultiVehicleSessionFiltering() {
        let alerts = AlertCenter()
        let store = SessionStore(alerts: alerts)
        
        let v1 = Vehicle(id: "v1", name: "Aion V", nominalCapacityKWh: 75.3, nominalRangeKm: 500, isDefault: true)
        let v2 = Vehicle(id: "v2", name: "BYD Dolphin", nominalCapacityKWh: 44.9, nominalRangeKm: 410, isDefault: false)
        
        store.vehicles = [v1, v2]
        
        let s1 = ChargingSession(id: "s1", vehicleId: "v1", locationName: "Home", energyAdded: 30.0, totalPrice: 78.0)
        let s2 = ChargingSession(id: "s2", vehicleId: "v2", locationName: "Central", energyAdded: 20.0, totalPrice: 150.0)
        let s3 = ChargingSession(id: "s3", vehicleId: nil, locationName: "PEA", energyAdded: 25.0, totalPrice: 180.0) // legacy unassigned
        
        store.sessions = [s1, s2, s3]
        
        // Filter by v1 -> includes s1 and s3 (since v1 is default)
        let v1Sessions = store.sessions(for: "v1")
        XCTAssertEqual(v1Sessions.count, 2)
        XCTAssertTrue(v1Sessions.contains(where: { $0.id == "s1" }))
        XCTAssertTrue(v1Sessions.contains(where: { $0.id == "s3" }))
        
        // Filter by v2 -> includes only s2
        let v2Sessions = store.sessions(for: "v2")
        XCTAssertEqual(v2Sessions.count, 1)
        XCTAssertEqual(v2Sessions.first?.id, "s2")
        
        // Filter nil (All) -> includes all 3 sessions
        let allSessions = store.sessions(for: String?.none)
        XCTAssertEqual(allSessions.count, 3)
    }
    
    func testVehicleCRUDOperations() {
        let alerts = AlertCenter()
        let store = SessionStore(alerts: alerts)
        store.vehicles = []
        
        // 1. Add Vehicle
        var car1 = Vehicle(id: "car-1", name: "Car 1", nominalCapacityKWh: 50.0, nominalRangeKm: 300, isDefault: true)
        store.addVehicle(car1, setAsActive: true)
        XCTAssertEqual(store.vehicles.count, 1)
        XCTAssertEqual(store.activeVehicle.id, "car-1")
        
        // 2. Add Second Vehicle
        let car2 = Vehicle(id: "car-2", name: "Car 2", nominalCapacityKWh: 80.0, nominalRangeKm: 550, isDefault: false)
        store.addVehicle(car2, setAsActive: false)
        XCTAssertEqual(store.vehicles.count, 2)
        
        // 3. Select Vehicle
        store.selectVehicle(id: "car-2")
        XCTAssertEqual(store.selectedVehicleId, "car-2")
        XCTAssertEqual(store.activeVehicle.id, "car-2")
        
        // 4. Update Vehicle
        car1.name = "Car 1 Updated"
        store.updateVehicle(car1)
        XCTAssertEqual(store.vehicle(for: "car-1")?.name, "Car 1 Updated")
        
        // 5. Set Default
        store.setDefaultVehicle(car2)
        XCTAssertTrue(store.vehicle(for: "car-2")?.isDefault == true)
        XCTAssertFalse(store.vehicle(for: "car-1")?.isDefault == true)
        
        // 6. Delete Vehicle with session reassignment
        let session = ChargingSession(id: "s-test", vehicleId: "car-1", locationName: "Home")
        store.sessions = [session]
        
        store.deleteVehicle(car1)
        XCTAssertEqual(store.vehicles.count, 1)
        XCTAssertEqual(store.sessions.first?.vehicleId, "car-2")
    }
    
    // MARK: - Multi-Vehicle Battery Health Evaluation
    func testBatteryHealthVehicleScoping() {
        let vSmall = Vehicle(id: "v-small", name: "Small EV", chemistry: .lfp, nominalCapacityKWh: 40.0, nominalRangeKm: 300.0, cycleLifeTo80: 3000, acEfficiency: 1.0, dcEfficiency: 1.0)
        let vBig = Vehicle(id: "v-big", name: "Big EV", chemistry: .nmc, nominalCapacityKWh: 100.0, nominalRangeKm: 600.0, cycleLifeTo80: 1500, acEfficiency: 1.0, dcEfficiency: 1.0)
        
        let serviceSmall = BatteryHealthService(vehicle: vSmall)
        let serviceBig = BatteryHealthService(vehicle: vBig)
        
        // Session adding 20 kWh on 50% SoC delta (20% to 70%)
        let session = ChargingSession(
            date: Date(),
            duration: 1800,
            energyAdded: 20.0,
            speed: 40.0,
            startPercentage: 20.0,
            endPercentage: 70.0,
            chargingType: .dc
        )
        
        let pointSmall = serviceSmall.evaluateSession(session)
        XCTAssertNotNil(pointSmall)
        // 20 kWh / 50% delta = 40 kWh estimated capacity -> 40 / 40 = 100% SoH
        XCTAssertEqual(pointSmall?.estimatedCapacityKWh ?? 0, 40.0, accuracy: 0.1)
        XCTAssertEqual(pointSmall?.stateOfHealth ?? 0, 100.0, accuracy: 0.1)
        
        let pointBig = serviceBig.evaluateSession(session)
        XCTAssertNotNil(pointBig)
        // 20 kWh / 50% delta = 40 kWh estimated capacity on a 100 kWh nominal pack -> 40% SoH
        XCTAssertEqual(pointBig?.estimatedCapacityKWh ?? 0, 40.0, accuracy: 0.1)
        XCTAssertEqual(pointBig?.stateOfHealth ?? 0, 40.0, accuracy: 0.1)
    }
    
    // MARK: - Multi-Vehicle CSV Import & Export
    func testCSVMultiVehicleExportAndImport() {
        let v1 = Vehicle(id: "v-1", name: "Taycan", nominalCapacityKWh: 93.4, nominalRangeKm: 450)
        let session = ChargingSession(
            id: "csv-sess-1",
            vehicleId: "v-1",
            locationName: "Porsche Center",
            vendorName: "Porsche",
            date: Date(timeIntervalSince1970: 1700000000),
            duration: 1200,
            energyAdded: 65.0,
            speed: 195.0,
            chargingFee: 500.0,
            totalPrice: 500.0,
            mileage: 15000,
            startPercentage: 10,
            endPercentage: 80,
            chargingType: .dc,
            locationType: .publicStation,
            paymentStatus: .paidUpfront
        )
        
        let csv = CSVExporter.generateCSV(from: [session], vehicles: [v1])
        XCTAssertTrue(csv.contains("Vehicle"))
        XCTAssertTrue(csv.contains("Taycan"))
        
        let parsed = CSVParser.parseSessions(from: csv)
        XCTAssertEqual(parsed.sessions.count, 1)
        let imported = parsed.sessions[0]
        XCTAssertEqual(imported.locationName, "Porsche Center")
        XCTAssertEqual(imported.vehicleId, "Taycan")
    }
}
