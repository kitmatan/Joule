import XCTest
@testable import Joule

/// Covers externally measured SoH readings: how they are stored, how they are compared against the
/// app's own estimate, and — most importantly — the cases where no honest comparison exists.
final class BatteryReferenceTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func trend(_ offsets: [(days: Double, soh: Double)]) -> [BatteryHealthTrendPoint] {
        offsets.map { entry in
            BatteryHealthTrendPoint(
                date: baseDate.addingTimeInterval(entry.days * 86400.0),
                mileage: nil,
                smoothedSoH: entry.soh,
                smoothedCapacityKWh: 75.3 * entry.soh / 100.0,
                projectedFullRangeKm: nil
            )
        }
    }

    // MARK: - Interpolation

    func testSmoothedSoHInterpolatesBetweenTrendPoints() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let points = trend([(0, 100.0), (100, 90.0)])

        // Halfway through the span should land halfway between the two values.
        let midpoint = baseDate.addingTimeInterval(50 * 86400.0)
        XCTAssertEqual(service.smoothedSoH(at: midpoint, trend: points) ?? 0, 95.0, accuracy: 0.001)

        // A quarter in.
        let quarter = baseDate.addingTimeInterval(25 * 86400.0)
        XCTAssertEqual(service.smoothedSoH(at: quarter, trend: points) ?? 0, 97.5, accuracy: 0.001)
    }

    func testSmoothedSoHReturnsEndpointsExactly() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let points = trend([(0, 100.0), (100, 90.0)])

        XCTAssertEqual(service.smoothedSoH(at: baseDate, trend: points) ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(
            service.smoothedSoH(at: baseDate.addingTimeInterval(100 * 86400.0), trend: points) ?? 0,
            90.0,
            accuracy: 0.001
        )
    }

    func testSmoothedSoHClampsWithinToleranceButNotBeyond() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let points = trend([(0, 100.0), (100, 90.0)])

        // 30 days past the last session: clamped to the final trend value.
        let justAfter = baseDate.addingTimeInterval(130 * 86400.0)
        XCTAssertEqual(service.smoothedSoH(at: justAfter, trend: points) ?? 0, 90.0, accuracy: 0.001)

        // 60 days past: too stale to compare, so no number rather than a misleading one.
        let longAfter = baseDate.addingTimeInterval(160 * 86400.0)
        XCTAssertNil(service.smoothedSoH(at: longAfter, trend: points))

        // Same rule applies before the history begins.
        let longBefore = baseDate.addingTimeInterval(-60 * 86400.0)
        XCTAssertNil(service.smoothedSoH(at: longBefore, trend: points))

        let justBefore = baseDate.addingTimeInterval(-30 * 86400.0)
        XCTAssertEqual(service.smoothedSoH(at: justBefore, trend: points) ?? 0, 100.0, accuracy: 0.001)
    }

    func testSmoothedSoHWithEmptyTrend() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        XCTAssertNil(service.smoothedSoH(at: baseDate, trend: []))
    }

    // MARK: - Comparison

    func testComparisonUsesLatestReadingAndSameDateEstimate() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let points = trend([(0, 100.0), (100, 90.0)])

        let older = BatteryHealthReference(date: baseDate, sohPercent: 99.0)
        let newer = BatteryHealthReference(
            date: baseDate.addingTimeInterval(50 * 86400.0),
            sohPercent: 97.0
        )

        let comparison = service.compareLatestReference([older, newer], trend: points)
        XCTAssertEqual(comparison?.reference.id, newer.id)

        // Compared against the estimate for the reading's own date (95.0), never today's.
        XCTAssertEqual(comparison?.estimatedSoHAtReadingDate ?? 0, 95.0, accuracy: 0.001)
        XCTAssertEqual(comparison?.delta ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(comparison?.agreement, .withinExpectedOffset)
    }

    func testComparisonWithNoReadingsIsNil() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        XCTAssertNil(service.compareLatestReference([], trend: trend([(0, 100.0)])))
    }

    func testComparisonOutsideHistoryIsNotComparable() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let points = trend([(0, 100.0), (10, 99.0)])

        let stranded = BatteryHealthReference(
            date: baseDate.addingTimeInterval(400 * 86400.0),
            sohPercent: 97.0
        )

        let comparison = service.compareLatestReference([stranded], trend: points)
        XCTAssertNotNil(comparison)
        XCTAssertNil(comparison?.estimatedSoHAtReadingDate)
        XCTAssertNil(comparison?.delta)
        XCTAssertEqual(comparison?.agreement, .notComparable)
    }

    func testAgreementThreshold() {
        let points = trend([(0, 94.0)])
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)

        func agreement(forReading soh: Double) -> BatteryReferenceComparison.Agreement? {
            service.compareLatestReference(
                [BatteryHealthReference(date: baseDate, sohPercent: soh)],
                trend: points
            )?.agreement
        }

        // Exactly at the tolerance still counts as agreement.
        XCTAssertEqual(agreement(forReading: 97.0), .withinExpectedOffset)
        XCTAssertEqual(agreement(forReading: 91.0), .withinExpectedOffset)
        // Beyond it, the settings are worth questioning.
        XCTAssertEqual(agreement(forReading: 97.5), .exceedsExpectedOffset)
        XCTAssertEqual(agreement(forReading: 90.5), .exceedsExpectedOffset)
    }

    // MARK: - Summary plumbing

    func testSummaryCarriesReferenceWithoutAlteringEstimate() {
        let service = BatteryHealthService(nominalCapacityKWh: 60.0, acEfficiency: 0.90)

        // 64 kWh at 90% efficiency over a full 0→100% charge = 57.6 kWh usable = 96.0% SoH.
        let session = ChargingSession(
            date: baseDate,
            energyAdded: 64.0,
            startPercentage: 0.0,
            endPercentage: 100.0,
            chargingType: .ac
        )

        let withoutReading = service.calculateSummary(from: [session])
        let reading = BatteryHealthReference(date: baseDate, sohPercent: 97.0, source: .dealer)
        let withReading = service.calculateSummary(from: [session], references: [reading])

        XCTAssertNil(withoutReading?.referenceComparison)
        XCTAssertEqual(withReading?.referenceComparison?.reference.sohPercent, 97.0)

        // The headline number is untouched by the service reading — the whole point of keeping the
        // two apart rather than reconciling them.
        XCTAssertEqual(withReading?.currentSoH ?? 0, withoutReading?.currentSoH ?? -1, accuracy: 0.0001)
        XCTAssertEqual(withReading?.currentSoH ?? 0, 96.0, accuracy: 0.001)
        XCTAssertEqual(withReading?.currentCapacityKWh ?? 0, withoutReading?.currentCapacityKWh ?? -1, accuracy: 0.0001)
        XCTAssertEqual(withReading?.referenceComparison?.delta ?? 0, 1.0, accuracy: 0.001)
    }

    // MARK: - Vehicle storage

    func testVehicleDecodesRecordsWrittenBeforeReadingsExisted() throws {
        // A vehicle document as persisted by earlier builds: no readings key at all.
        let legacy = """
        {
          "id": "v1", "name": "AION V 602 Luxury", "presetId": "gac_aion_v_602",
          "chemistry": "NMC", "rangeStandard": "CLTC",
          "nominalCapacityKWh": 75.3, "nominalRangeKm": 602, "cycleLifeTo80": 2000,
          "acEfficiency": 0.9, "dcEfficiency": 0.95, "wallChargerKW": 7,
          "tariffType": "Standard (Non-TOU)", "customTariffRate": 4.2,
          "gasPreset": "Mid-Size SUV / Crossover", "gasEfficiencyKmPerL": 12,
          "gasCustomFuelPrice": 35, "isDefault": true, "createdAt": 750000000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Vehicle.self, from: legacy)
        XCTAssertEqual(decoded.id, "v1")
        XCTAssertTrue(decoded.referenceReadings.isEmpty)
        XCTAssertNil(decoded.latestReferenceReading)
    }

    func testUpsertAndRemoveReadings() {
        var vehicle = Vehicle(name: "Test EV")
        XCTAssertTrue(vehicle.referenceReadings.isEmpty)

        let first = BatteryHealthReference(date: baseDate, sohPercent: 99.0, source: .dealer)
        let second = BatteryHealthReference(
            date: baseDate.addingTimeInterval(200 * 86400.0),
            sohPercent: 97.0,
            source: .obdScan
        )

        vehicle.upsertReferenceReading(second)
        vehicle.upsertReferenceReading(first)

        // Stored oldest first, so the latest is genuinely the most recent measurement.
        XCTAssertEqual(vehicle.referenceReadings.map(\.id), [first.id, second.id])
        XCTAssertEqual(vehicle.latestReferenceReading?.id, second.id)

        // Upserting the same id edits rather than duplicates.
        var edited = second
        edited.sohPercent = 96.0
        vehicle.upsertReferenceReading(edited)
        XCTAssertEqual(vehicle.referenceReadings.count, 2)
        XCTAssertEqual(vehicle.latestReferenceReading?.sohPercent, 96.0)

        vehicle.removeReferenceReading(id: first.id)
        XCTAssertEqual(vehicle.referenceReadings.map(\.id), [second.id])
    }

    func testReadingsSurviveARoundTrip() throws {
        var vehicle = Vehicle(name: "Test EV")
        vehicle.upsertReferenceReading(
            BatteryHealthReference(
                date: baseDate,
                sohPercent: 97.0,
                odometerKm: 24_500,
                source: .dealer,
                toolName: "GAC Diagnostic",
                notes: "Annual service"
            )
        )

        let data = try JSONEncoder().encode(vehicle)
        let decoded = try JSONDecoder().decode(Vehicle.self, from: data)

        XCTAssertEqual(decoded.referenceReadings.count, 1)
        let reading = try XCTUnwrap(decoded.latestReferenceReading)
        XCTAssertEqual(reading.sohPercent, 97.0)
        XCTAssertEqual(reading.odometerKm, 24_500)
        XCTAssertEqual(reading.source, .dealer)
        XCTAssertEqual(reading.toolName, "GAC Diagnostic")
    }
}

/// Covers SoC-reading uncertainty propagating into the SoH figure, and the shallow mid-curve
/// charges that produce numbers the app should not present as measurements.
final class BatteryHealthUncertaintyTests: XCTestCase {

    private func lfpService() -> BatteryHealthService {
        BatteryHealthService(
            nominalCapacityKWh: 75.3,
            nominalRangeKm: 602.0,
            acEfficiency: 0.90,
            dcEfficiency: 0.95,
            chemistry: .lfp
        )
    }

    func testFullChargeAnchorsTheTopOfTheCurve() {
        let service = lfpService()
        // A full charge makes the BMS balance and reset its counter.
        XCTAssertEqual(service.socReadingUncertainty(at: 100.0), 0.5)
        XCTAssertEqual(service.socReadingUncertainty(at: 97.0), 0.5)
        // The bottom knee is steep enough to pin SoC nearly as well.
        XCTAssertEqual(service.socReadingUncertainty(at: 2.0), 0.8)
        // Mid-curve is an estimate, and LFP's is the loosest.
        XCTAssertEqual(service.socReadingUncertainty(at: 50.0), 2.0)

        var nmc = lfpService()
        nmc.chemistry = .nmc
        XCTAssertEqual(nmc.socReadingUncertainty(at: 50.0), 1.0)
    }

    func testShallowChargeAmplifiesSoCErrorFarMoreThanADeepOne() {
        let service = lfpService()

        // Same chemistry, same reading error — only the depth of the charge differs.
        let deep = service.sohUncertainty(stateOfHealth: 100.0, startSoC: 18, endSoC: 100, socDelta: 82)
        let shallow = service.sohUncertainty(stateOfHealth: 90.6, startSoC: 8, endSoC: 27.22, socDelta: 19.22)

        XCTAssertEqual(deep, 2.51, accuracy: 0.05)
        XCTAssertEqual(shallow, 13.33, accuracy: 0.05)
        XCTAssertGreaterThan(shallow, deep * 5)
    }

    func testShallowMidCurveDCSessionIsRatedUnreliable() throws {
        let service = lfpService()

        // The real session: 8% -> 27.2% on DC, 13.8 kWh at the dispenser. Reconciling its result
        // with the pack's AC-derived capacity would need >100% charging efficiency, so it measures
        // SoC-estimator drift rather than capacity.
        let session = ChargingSession(
            id: "dc-shallow",
            date: Date(),
            energyAdded: 13.8,
            startPercentage: 8.0,
            endPercentage: 27.22,
            chargingType: .dc
        )

        let point = try XCTUnwrap(service.evaluateSession(session))
        XCTAssertEqual(point.stateOfHealth, 90.6, accuracy: 0.2)
        XCTAssertGreaterThan(point.sohUncertainty, 12.0)
        XCTAssertEqual(point.confidence, .unreliable)
        XCTAssertEqual(BatteryHealthConfidence.unreliable.weight, 0.0)
    }

    func testUnreliableShallowSampleIsKeptOutOfTheTrend() throws {
        let service = lfpService()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Four solid full charges, all landing on 75.3 kWh.
        var sessions = (0..<4).map { i in
            ChargingSession(
                id: "ac\(i)",
                date: base.addingTimeInterval(Double(i) * 7 * 86400),
                energyAdded: 68.7,
                startPercentage: 18.0,
                endPercentage: 100.0,
                chargingType: .ac
            )
        }

        let cleanTrend = service.calculateSummary(from: sessions)?.currentSoH ?? 0
        XCTAssertEqual(cleanTrend, 100.0, accuracy: 0.5)

        // Adding the shallow DC session must not drag the headline number down.
        sessions.append(
            ChargingSession(
                id: "dc-shallow",
                date: base.addingTimeInterval(28 * 86400),
                energyAdded: 13.8,
                startPercentage: 8.0,
                endPercentage: 27.22,
                chargingType: .dc
            )
        )

        let summary = try XCTUnwrap(service.calculateSummary(from: sessions))
        XCTAssertEqual(summary.currentSoH, cleanTrend, accuracy: 0.5)

        // It is still counted and shown, just not trusted.
        XCTAssertEqual(summary.totalSamplesCount, 5)
        XCTAssertEqual(summary.reliableSamplesCount, 4)
    }

    func testDeepChargesKeepTheirHighConfidence() {
        let service = lfpService()

        // A deep mid-curve charge is still good enough to rate high.
        let ac = ChargingSession(
            id: "ac-deep", date: Date(), energyAdded: 50.2,
            startPercentage: 20.0, endPercentage: 80.0, chargingType: .ac
        )
        XCTAssertEqual(service.evaluateSession(ac)?.confidence, .high)

        let dc = ChargingSession(
            id: "dc-deep", date: Date(), energyAdded: 52.0,
            startPercentage: 10.0, endPercentage: 80.0, chargingType: .dc
        )
        XCTAssertEqual(service.evaluateSession(dc)?.confidence, .high)
    }
}
