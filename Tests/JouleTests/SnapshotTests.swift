import XCTest
@testable import Joule

/// Covers the data path that feeds the widgets and the watch app: the statistics extracted out of
/// `DashboardView`, and the snapshot built on top of them.
final class SnapshotTests: XCTestCase {

    // MARK: - Fixtures

    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000) // 15 Jun 2025, UTC

    private func vehicle(capacity: Double = 60, range: Double = 400) -> Vehicle {
        Vehicle(
            id: "vehicle-1",
            name: "Test EV",
            chemistry: .lfp,
            nominalCapacityKWh: capacity,
            nominalRangeKm: range,
            acEfficiency: 0.9,
            dcEfficiency: 0.95
        )
    }

    private func session(
        id: String,
        daysAgo: Double,
        energy: Double,
        price: Double,
        locationName: String? = nil,
        mileage: Double? = nil,
        startSoC: Double? = nil,
        endSoC: Double? = nil,
        type: ChargingType? = nil,
        location: LocationType? = nil,
        speed: Double = 0,
        payment: PaymentStatus? = nil
    ) -> ChargingSession {
        ChargingSession(
            id: id,
            vehicleId: "vehicle-1",
            locationName: locationName,
            date: referenceDate.addingTimeInterval(-daysAgo * 86_400),
            energyAdded: energy,
            speed: speed,
            totalPrice: price,
            mileage: mileage,
            startPercentage: startSoC,
            endPercentage: endSoC,
            chargingType: type,
            locationType: location,
            paymentStatus: payment
        )
    }

    private func statistics(_ sessions: [ChargingSession]) -> ChargingStatistics {
        ChargingStatistics(
            sessions: sessions,
            vehicle: vehicle(),
            currency: .thb,
            unitSystem: .metric,
            referenceDate: referenceDate
        )
    }

    // MARK: - ChargingStatistics

    func testTotalsSumEveryScopedSession() {
        let stats = statistics([
            session(id: "a", daysAgo: 1, energy: 10, price: 50),
            session(id: "b", daysAgo: 40, energy: 20, price: 100)
        ])

        XCTAssertEqual(stats.totalSessions, 2)
        XCTAssertEqual(stats.totalEnergy, 30, accuracy: 0.001)
        XCTAssertEqual(stats.totalCost, 150, accuracy: 0.001)
        // Lifetime average, not month-scoped: ฿150 over 30 kWh.
        XCTAssertEqual(stats.averagePricePerKWh, 5.0, accuracy: 0.001)
    }

    func testCurrentMonthExcludesOlderSessions() {
        let stats = statistics([
            session(id: "this-month", daysAgo: 2, energy: 10, price: 50),
            session(id: "last-month", daysAgo: 45, energy: 20, price: 100)
        ])

        XCTAssertEqual(stats.currentMonthSessions.count, 1)
        XCTAssertEqual(stats.currentMonthEnergy, 10, accuracy: 0.001)
        XCTAssertEqual(stats.currentMonthCost, 50, accuracy: 0.001)
    }

    func testDeferredCostCountsOnlyDeferredSessions() {
        let stats = statistics([
            session(id: "paid", daysAgo: 1, energy: 10, price: 50, payment: .paidUpfront),
            session(id: "deferred", daysAgo: 2, energy: 10, price: 80, payment: .deferred)
        ])

        XCTAssertEqual(stats.currentMonthDeferredCost, 80, accuracy: 0.001)
    }

    /// The window spans the first and last odometer readings, and counts only the energy that was
    /// actually driven off — the charge taken *at* the closing reading has not been used yet.
    func testDrivingWindowExcludesTheClosingCharge() throws {
        let stats = statistics([
            session(id: "start", daysAgo: 30, energy: 40, price: 200, mileage: 10_000),
            session(id: "middle", daysAgo: 20, energy: 50, price: 250),
            session(id: "end", daysAgo: 10, energy: 999, price: 9_999, mileage: 10_900)
        ])

        let window = try XCTUnwrap(stats.drivingWindow)
        XCTAssertEqual(window.distance, 900, accuracy: 0.001)
        // 40 + 50, with the closing session's 999 kWh excluded.
        XCTAssertEqual(window.energy, 90, accuracy: 0.001)
        XCTAssertEqual(window.cost, 450, accuracy: 0.001)

        XCTAssertTrue(stats.hasDrivingData)
        XCTAssertEqual(stats.totalDistance, 900, accuracy: 0.001)
        XCTAssertEqual(stats.energyEfficiency, 10.0, accuracy: 0.001)   // 900 km / 90 kWh
        XCTAssertEqual(stats.costPerDistance, 0.5, accuracy: 0.001)     // ฿450 / 900 km
    }

    func testDrivingWindowNeedsTwoDistinctOdometerReadings() {
        let stats = statistics([
            session(id: "only", daysAgo: 5, energy: 10, price: 50, mileage: 10_000)
        ])

        XCTAssertNil(stats.drivingWindow)
        XCTAssertFalse(stats.hasDrivingData)
        XCTAssertEqual(stats.energyEfficiency, 0)
        XCTAssertEqual(stats.costPerDistance, 0)
    }

    func testCostPerDistanceConvertsToImperial() {
        let sessions = [
            session(id: "start", daysAgo: 30, energy: 40, price: 200, mileage: 10_000),
            session(id: "end", daysAgo: 10, energy: 10, price: 50, mileage: 10_900)
        ]
        let imperial = ChargingStatistics(
            sessions: sessions,
            vehicle: vehicle(),
            currency: .usd,
            unitSystem: .imperial,
            referenceDate: referenceDate
        )

        // 900 km is ~559.2 miles; ฿200 over that distance.
        XCTAssertEqual(imperial.costPerDistance, 200.0 / (900.0 * 0.621371192), accuracy: 0.0001)
        // Efficiency stays in metric base — conversion happens at render time.
        XCTAssertEqual(imperial.energyEfficiency, 22.5, accuracy: 0.001)
    }

    func testEmptySessionsProduceZeroesRatherThanCrashing() {
        let stats = statistics([])

        XCTAssertEqual(stats.totalSessions, 0)
        XCTAssertEqual(stats.averagePricePerKWh, 0)
        XCTAssertEqual(stats.uniqueMonthsCount, 1)
        XCTAssertNil(stats.drivingWindow)
    }

    // MARK: - SnapshotBuilder

    private func buildSnapshot(_ sessions: [ChargingSession]) -> JouleSnapshot {
        SnapshotBuilder.build(
            sessions: sessions,
            vehicle: vehicle(),
            vehicleCount: 2,
            currency: .thb,
            unitSystem: .metric,
            referenceDate: referenceDate
        )
    }

    func testSnapshotCarriesVehicleAndFormattingContext() {
        let snapshot = buildSnapshot([session(id: "a", daysAgo: 1, energy: 10, price: 50)])

        XCTAssertEqual(snapshot.version, JouleSnapshot.currentVersion)
        XCTAssertEqual(snapshot.vehicleName, "Test EV")
        XCTAssertEqual(snapshot.vehicleCount, 2)
        XCTAssertEqual(snapshot.nominalCapacityKWh, 60)
        XCTAssertEqual(snapshot.currency, .thb)
        XCTAssertEqual(snapshot.unitSystem, .metric)
        XCTAssertFalse(snapshot.isEmpty)
    }

    func testSnapshotIsEmptyWithNoSessions() {
        XCTAssertTrue(buildSnapshot([]).isEmpty)
        XCTAssertNil(buildSnapshot([]).lastSession)
    }

    func testRecentSessionsAreNewestFirstAndCapped() {
        let many = (0..<20).map { index in
            session(id: "s\(index)", daysAgo: Double(index), energy: 10, price: 50)
        }
        let snapshot = buildSnapshot(many)

        XCTAssertEqual(snapshot.recentSessions.count, SnapshotBuilder.recentSessionLimit)
        XCTAssertEqual(snapshot.lastSession?.id, "s0")
        XCTAssertEqual(snapshot.recentSessions.first?.id, "s0")

        let dates = snapshot.recentSessions.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >), "Recent sessions must stay newest-first")
    }

    /// An untyped session is classified the same way `BatteryHealthService` classifies it, so the
    /// widget's AC/DC icon cannot contradict the battery-health maths.
    func testUntypedSessionsInferChargingTypeLikeBatteryHealthService() {
        let snapshot = buildSnapshot([
            session(id: "explicit-dc", daysAgo: 1, energy: 30, price: 300, type: .dc),
            session(id: "explicit-ac", daysAgo: 2, energy: 10, price: 50, type: .ac),
            session(id: "home-untyped", daysAgo: 3, energy: 10, price: 50, location: .home),
            session(id: "slow-untyped", daysAgo: 4, energy: 10, price: 50, speed: 7),
            session(id: "fast-untyped", daysAgo: 5, energy: 30, price: 300, speed: 60)
        ])

        let byID = Dictionary(uniqueKeysWithValues: snapshot.recentSessions.map { ($0.id, $0) })
        XCTAssertEqual(byID["explicit-dc"]?.isDC, true)
        XCTAssertEqual(byID["explicit-ac"]?.isDC, false)
        XCTAssertEqual(byID["home-untyped"]?.isDC, false)
        XCTAssertEqual(byID["slow-untyped"]?.isDC, false)
        XCTAssertEqual(byID["fast-untyped"]?.isDC, true)
    }

    func testMonthlyCostsSeedEveryMonthInRangeOldestFirst() throws {
        let snapshot = buildSnapshot([
            session(id: "a", daysAgo: 1, energy: 10, price: 50),
            session(id: "b", daysAgo: 40, energy: 10, price: 90)
        ])

        XCTAssertEqual(snapshot.monthlyCosts.count, SnapshotBuilder.monthlyHistoryLimit)

        let months = snapshot.monthlyCosts.map(\.month)
        XCTAssertEqual(months, months.sorted(), "Sparkline months must run oldest to newest")

        // The trailing entry is the current month and holds this month's spend.
        let currentMonth = try XCTUnwrap(snapshot.monthlyCosts.last)
        XCTAssertEqual(currentMonth.cost, 50, accuracy: 0.001)
        // Months with no charging are present as zeroes rather than missing.
        XCTAssertTrue(snapshot.monthlyCosts.contains { $0.cost == 0 })
    }

    func testBatteryHealthIsAbsentUntilSoCDataExists() throws {
        let withoutSoC = buildSnapshot([session(id: "a", daysAgo: 1, energy: 10, price: 50)])
        XCTAssertNil(withoutSoC.batteryHealth)

        // 27 kWh at the wall × 0.9 AC efficiency = 24.3 kWh into a 45% swing ⇒ 54 kWh usable.
        let withSoC = buildSnapshot([
            session(id: "a", daysAgo: 1, energy: 27, price: 130, startSoC: 20, endSoC: 65, type: .ac)
        ])
        let health = try XCTUnwrap(withSoC.batteryHealth)
        XCTAssertEqual(health.capacityKWh, 54.0, accuracy: 0.5)
        XCTAssertEqual(health.stateOfHealth, 90.0, accuracy: 1.0)
        XCTAssertFalse(health.isCalibrated, "A single sample cannot support a degradation rate")
    }

    func testSessionSnapshotFallsBackToChargeTypeWhenUnnamed() {
        let snapshot = buildSnapshot([
            session(id: "named", daysAgo: 1, energy: 10, price: 50, locationName: "PEA Volta Rama 9"),
            session(id: "blank", daysAgo: 2, energy: 10, price: 50, locationName: "   ", type: .ac),
            session(id: "unnamed-ac", daysAgo: 3, energy: 10, price: 50, type: .ac),
            session(id: "unnamed-dc", daysAgo: 4, energy: 30, price: 300, type: .dc)
        ])

        let byID = Dictionary(uniqueKeysWithValues: snapshot.recentSessions.map { ($0.id, $0) })
        XCTAssertEqual(byID["named"]?.displayLocation, "PEA Volta Rama 9")
        // Whitespace is treated as absent, not printed as a blank row.
        XCTAssertEqual(byID["blank"]?.displayLocation, "AC Charge")
        XCTAssertEqual(byID["unnamed-ac"]?.displayLocation, "AC Charge")
        XCTAssertEqual(byID["unnamed-dc"]?.displayLocation, "DC Charge")
    }

    // MARK: - Transport

    func testSnapshotSurvivesTransferEncoding() throws {
        let original = buildSnapshot([
            session(id: "a", daysAgo: 1, energy: 27, price: 130, startSoC: 20, endSoC: 65, type: .ac)
        ])

        let payload = try XCTUnwrap(SharedStorage.encodeForTransfer(original))
        let decoded = try XCTUnwrap(SharedStorage.decodeFromTransfer(payload))

        XCTAssertEqual(decoded, original)
    }

    func testTransferDecodingRejectsUnrelatedPayloads() {
        XCTAssertNil(SharedStorage.decodeFromTransfer([:]))
        XCTAssertNil(SharedStorage.decodeFromTransfer(["snapshot": Data([0x00, 0x01])]))
    }

    // MARK: - Formatting

    func testCompactCurrencyTradesPrecisionForWidthAsAmountsGrow() {
        XCTAssertEqual(SnapshotFormat.compactCurrency(4.69, currency: .thb), "฿4.69")
        XCTAssertEqual(SnapshotFormat.compactCurrency(1_284.5, currency: .thb), "฿1,285")
        XCTAssertEqual(SnapshotFormat.compactCurrency(14_920, currency: .thb), "฿14.9k")
        XCTAssertEqual(SnapshotFormat.compactCurrency(-250, currency: .thb), "-฿250")
    }

    func testEnergyFormattingDropsDecimalsOnlyWhenLarge() {
        XCTAssertEqual(SnapshotFormat.energy(32.4), "32.4 kWh")
        XCTAssertEqual(SnapshotFormat.energy(262.4), "262 kWh")
        XCTAssertEqual(SnapshotFormat.energy(32.4, includeUnit: false), "32.4")
    }

    func testRelativeDateShortensWithAge() {
        let now = referenceDate
        XCTAssertEqual(SnapshotFormat.relativeDate(now.addingTimeInterval(-30), reference: now), "Just now")
        XCTAssertEqual(SnapshotFormat.relativeDate(now.addingTimeInterval(-600), reference: now), "10m ago")
        XCTAssertEqual(SnapshotFormat.relativeDate(now.addingTimeInterval(-7_200), reference: now), "2h ago")
        XCTAssertEqual(SnapshotFormat.relativeDate(now.addingTimeInterval(-86_400), reference: now), "Yesterday")
    }

    func testEfficiencyFormattingHandlesMissingData() {
        XCTAssertEqual(SnapshotFormat.efficiency(kmPerKWh: 0, unitSystem: .metric), "—")
        XCTAssertEqual(SnapshotFormat.efficiency(kmPerKWh: 6.2, unitSystem: .metric), "6.2 km/kWh")
        XCTAssertEqual(SnapshotFormat.efficiency(kmPerKWh: 6.2, unitSystem: .imperial), "3.9 mi/kWh")
    }
}
