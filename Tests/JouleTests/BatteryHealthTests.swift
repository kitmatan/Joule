import XCTest
@testable import Joule

final class BatteryHealthTests: XCTestCase {

    func testBatteryHealthConfidenceEvaluation() {
        // Delta SoC >= 50% -> High (weight 1.0)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 50.0), .high)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 75.0), .high)
        XCTAssertEqual(BatteryHealthConfidence.high.weight, 1.0)

        // Delta SoC 30% - 49.9% -> Medium (weight 0.5)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 30.0), .medium)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 49.9), .medium)
        XCTAssertEqual(BatteryHealthConfidence.medium.weight, 0.5)

        // Delta SoC 15% - 29.9% -> Low (weight 0.15)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 15.0), .low)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 29.9), .low)
        XCTAssertEqual(BatteryHealthConfidence.low.weight, 0.15)

        // Delta SoC < 15% -> Unreliable (weight 0.0)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 14.9), .unreliable)
        XCTAssertEqual(BatteryHealthConfidence.evaluate(socDelta: 5.0), .unreliable)
        XCTAssertEqual(BatteryHealthConfidence.unreliable.weight, 0.0)

        // Ordering check
        XCTAssertTrue(BatteryHealthConfidence.unreliable < BatteryHealthConfidence.low)
        XCTAssertTrue(BatteryHealthConfidence.low < BatteryHealthConfidence.medium)
        XCTAssertTrue(BatteryHealthConfidence.medium < BatteryHealthConfidence.high)
    }

    func testEvaluateSessionWithACEfficiency() {
        let service = BatteryHealthService(
            nominalCapacityKWh: 75.3,
            nominalRangeKm: 602.0,
            acEfficiency: 0.90,
            dcEfficiency: 0.95
        )

        // AC session: 20% to 80% (60% delta), 50.2 kWh at meter
        // Battery energy = 50.2 * 0.90 = 45.18 kWh
        // Estimated capacity = 45.18 / 0.60 = 75.3 kWh
        // SoH = (75.3 / 75.3) * 100 = 100.0%
        let session = ChargingSession(
            id: "s1",
            date: Date(),
            energyAdded: 50.2,
            startPercentage: 20.0,
            endPercentage: 80.0,
            startRange: 120.0,
            endRange: 480.0,
            chargingType: .ac
        )

        let point = service.evaluateSession(session)
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.socDelta, 60.0)
        XCTAssertEqual(point?.confidence, .high)
        XCTAssertEqual(point?.stateOfHealth ?? 0, 100.0, accuracy: 0.1)
        XCTAssertEqual(point?.estimatedCapacityKWh ?? 0, 75.3, accuracy: 0.1)
        XCTAssertEqual(point?.projectedFullRangeKm ?? 0, 600.0, accuracy: 1.0)
    }

    func testEvaluateSessionWithDCEfficiency() {
        let service = BatteryHealthService(
            nominalCapacityKWh: 80.0,
            nominalRangeKm: 500.0,
            acEfficiency: 0.90,
            dcEfficiency: 0.95
        )

        // DC fast charge: 10% to 80% (70% delta), 56.0 kWh added
        // Battery energy = 56.0 * 0.95 = 53.2 kWh
        // Estimated capacity = 53.2 / 0.70 = 76.0 kWh
        // SoH = (76.0 / 80.0) * 100 = 95.0%
        let session = ChargingSession(
            id: "s2",
            date: Date(),
            energyAdded: 56.0,
            startPercentage: 10.0,
            endPercentage: 80.0,
            startRange: 50.0,
            endRange: 400.0,
            chargingType: .dc
        )

        let point = service.evaluateSession(session)
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.confidence, .high)
        XCTAssertEqual(point?.stateOfHealth ?? 0, 95.0, accuracy: 0.1)
        XCTAssertEqual(point?.estimatedCapacityKWh ?? 0, 76.0, accuracy: 0.1)
    }

    func testEvaluateSessionEdgeCasesAndRejections() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.0)

        // Delta < 5% -> rejected
        let smallDeltaSession = ChargingSession(
            energyAdded: 3.0,
            startPercentage: 50.0,
            endPercentage: 54.0,
            chargingType: .ac
        )
        XCTAssertNil(service.evaluateSession(smallDeltaSession))

        // End <= Start -> rejected
        let reverseSession = ChargingSession(
            energyAdded: 10.0,
            startPercentage: 60.0,
            endPercentage: 50.0,
            chargingType: .ac
        )
        XCTAssertNil(service.evaluateSession(reverseSession))

        // Zero energy -> rejected
        let zeroEnergySession = ChargingSession(
            energyAdded: 0.0,
            startPercentage: 20.0,
            endPercentage: 80.0,
            chargingType: .ac
        )
        XCTAssertNil(service.evaluateSession(zeroEnergySession))

        // Extreme anomaly (> 160% or < 40% of nominal) -> rejected
        let crazyHighSession = ChargingSession(
            energyAdded: 200.0,
            startPercentage: 10.0,
            endPercentage: 20.0, // 200 kWh for 10% delta implies 2000 kWh pack
            chargingType: .dc
        )
        XCTAssertNil(service.evaluateSession(crazyHighSession))
    }

    func testChemistrySpecificBenchmarks() {
        // LFP
        let lfp = BatteryChemistry.lfp
        XCTAssertEqual(lfp.defaultCycleLife, 3000.0)
        XCTAssertEqual(lfp.badgeTitle, "LFP")
        XCTAssertTrue(lfp.recommendedDailyTarget.contains("100%"))
        XCTAssertTrue(lfp.careAdvice.contains("Lithium Iron Phosphate"))

        // NMC
        let nmc = BatteryChemistry.nmc
        XCTAssertEqual(nmc.defaultCycleLife, 1500.0)
        XCTAssertEqual(nmc.badgeTitle, "NMC")
        XCTAssertTrue(nmc.recommendedDailyTarget.contains("80%"))
        XCTAssertTrue(nmc.careAdvice.contains("Nickel Manganese Cobalt"))

        // NCA
        let nca = BatteryChemistry.nca
        XCTAssertEqual(nca.defaultCycleLife, 1500.0)
        XCTAssertEqual(nca.badgeTitle, "NCA")
        XCTAssertTrue(nca.recommendedDailyTarget.contains("80%"))
        XCTAssertTrue(nca.careAdvice.contains("Nickel Cobalt Aluminum"))

        // Other
        let other = BatteryChemistry.other
        XCTAssertEqual(other.defaultCycleLife, 2000.0)
        XCTAssertEqual(other.badgeTitle, "EV")
    }

    func testBatteryAssessmentClassification() {
        XCTAssertEqual(BatteryHealthSummary.BatteryAssessment.excellent.title, "Excellent Health")
        XCTAssertEqual(BatteryHealthSummary.BatteryAssessment.good.title, "Good Condition")
        XCTAssertEqual(BatteryHealthSummary.BatteryAssessment.normal.title, "Normal Aging")
        XCTAssertEqual(BatteryHealthSummary.BatteryAssessment.degraded.title, "Elevated Degradation")

        let service = BatteryHealthService(nominalCapacityKWh: 60.0, acEfficiency: 0.90)

        // Session yielding ~96% SoH -> Excellent
        // Battery energy = 64.0 * 0.90 = 57.6 kWh -> 57.6 / 60.0 = 96.0% SoH
        let s1 = ChargingSession(
            date: Date(),
            energyAdded: 64.0,
            startPercentage: 0.0,
            endPercentage: 100.0,
            chargingType: .ac
        )
        let summary1 = service.calculateSummary(from: [s1])
        XCTAssertEqual(summary1?.assessment, .excellent)
    }

    func testGaussianSmoothingTrendCalculation() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3)
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Create 3 data points
        let p1 = BatteryHealthDataPoint(
            date: baseDate,
            mileage: 1000,
            startSoC: 20,
            endSoC: 80,
            socDelta: 60,
            energyAdded: 50.2,
            chargingType: .ac,
            estimatedCapacityKWh: 75.3,
            stateOfHealth: 100.0,
            confidence: .high,
            projectedFullRangeKm: 600
        )
        let p2 = BatteryHealthDataPoint(
            date: baseDate.addingTimeInterval(86400 * 30),
            mileage: 3000,
            startSoC: 20,
            endSoC: 80,
            socDelta: 60,
            energyAdded: 49.2,
            chargingType: .ac,
            estimatedCapacityKWh: 73.8,
            stateOfHealth: 98.0,
            confidence: .high,
            projectedFullRangeKm: 588
        )
        let p3 = BatteryHealthDataPoint(
            date: baseDate.addingTimeInterval(86400 * 60),
            mileage: 5000,
            startSoC: 20,
            endSoC: 80,
            socDelta: 60,
            energyAdded: 48.2,
            chargingType: .ac,
            estimatedCapacityKWh: 72.3,
            stateOfHealth: 96.0,
            confidence: .high,
            projectedFullRangeKm: 576
        )

        let trend = service.calculateTrend(from: [p1, p2, p3])
        XCTAssertEqual(trend.count, 3)
        XCTAssertGreaterThan(trend[0].smoothedSoH, trend[2].smoothedSoH)
        XCTAssertLessThanOrEqual(trend[0].smoothedSoH, 100.0)
    }

    func testLinearRegressionDegradationRates() {
        let service = BatteryHealthService(nominalCapacityKWh: 75.3, nominalRangeKm: 602.0)
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // 5 sessions over 10,000 km and 120 days
        // Degradation is about 1% per 5,000 km -> 2.0% per 10k km
        var sessions: [ChargingSession] = []
        let mileages: [Double] = [1000, 3500, 6000, 8500, 11000]
        let days: [Double] = [0, 30, 60, 90, 120]
        let energyValues: [Double] = [50.2, 49.8, 49.4, 49.0, 48.6] // decreasing energy

        for i in 0..<5 {
            let session = ChargingSession(
                id: "reg_\(i)",
                date: baseDate.addingTimeInterval(days[i] * 86400),
                energyAdded: energyValues[i],
                mileage: mileages[i],
                startPercentage: 20.0,
                endPercentage: 80.0,
                chargingType: .ac
            )
            sessions.append(session)
        }

        let summary = service.calculateSummary(from: sessions)
        XCTAssertNotNil(summary)
        XCTAssertNotNil(summary?.degradationPer10kKm)
        XCTAssertGreaterThan(summary?.degradationPer10kKm ?? 0, 0.0)
        XCTAssertLessThanOrEqual(summary?.degradationPer10kKm ?? 10, 3.5)

        XCTAssertNotNil(summary?.degradationPerYear)
        XCTAssertGreaterThan(summary?.degradationPerYear ?? 0, 0.0)
        XCTAssertLessThanOrEqual(summary?.degradationPerYear ?? 10, 5.0)


        // Imperial unit formatting
        let miRate = summary?.degradationPer10kDistance(unit: .imperial)
        XCTAssertNotNil(miRate)
        XCTAssertEqual(miRate!, (summary!.degradationPer10kKm!) * 1.609344, accuracy: 0.001)

        // EFC and Throughput
        XCTAssertGreaterThan(summary?.totalThroughputKWh ?? 0, 200.0)
        XCTAssertGreaterThan(summary?.equivalentFullCycles ?? 0, 2.5)
        XCTAssertEqual(summary?.reliableSamplesCount, 5)
    }
}
