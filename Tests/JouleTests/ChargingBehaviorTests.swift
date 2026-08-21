import XCTest
@testable import Joule

final class ChargingBehaviorTests: XCTestCase {

    func testEmptySessionsBaseline() {
        let vehicle = Vehicle(name: "Test Car", chemistry: .lfp)
        let analysis = ChargingBehaviorService.analyze(sessions: [], vehicle: vehicle)

        XCTAssertEqual(analysis.overallScore, 100.0)
        XCTAssertEqual(analysis.grade, .aPlus)
        XCTAssertEqual(analysis.metrics.totalSessions, 0)
        XCTAssertFalse(analysis.recommendations.isEmpty)
    }

    func testSpeedScoreACvsDC() {
        let vehicle = Vehicle(name: "Test Car", chemistry: .nmc)
        let refDate = Date()

        // 1. High AC Charging (85% AC, 15% DC)
        let mostlyACSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 40.0, speed: 7.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 2), energyAdded: 45.0, speed: 7.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 15.0, speed: 100.0, chargingType: .dc)
        ]
        let acAnalysis = ChargingBehaviorService.analyze(sessions: mostlyACSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(acAnalysis.metrics.acEnergyRatio, 85.0 / 100.0, accuracy: 0.01)
        XCTAssertEqual(acAnalysis.speedBalanceScore, 100.0, accuracy: 1.0)
        XCTAssertTrue(acAnalysis.recommendations.contains { $0.category == .chargingSpeed && $0.level == .positive })

        // 2. High DC Fast Charging (80% DC, 20% AC)
        let mostlyDCSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 10.0, speed: 7.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 2), energyAdded: 40.0, speed: 120.0, chargingType: .dc),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 40.0, speed: 120.0, chargingType: .dc)
        ]
        let dcAnalysis = ChargingBehaviorService.analyze(sessions: mostlyDCSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(dcAnalysis.metrics.dcEnergyRatio, 80.0 / 90.0, accuracy: 0.01)
        XCTAssertLessThan(dcAnalysis.speedBalanceScore, 65.0)
        XCTAssertTrue(dcAnalysis.recommendations.contains { $0.category == .chargingSpeed && $0.level == .caution })
    }

    func testTargetSoCScoreForLFPCalibration() {
        let vehicle = Vehicle(name: "Aion V LFP", chemistry: .lfp)
        let refDate = Date()

        // 1. Regular 100% Calibration (last full charge 3 days ago)
        let healthyLFPSessions = [
            ChargingSession(
                date: refDate.addingTimeInterval(-86400 * 3),
                energyAdded: 45.0,
                startPercentage: 30.0,
                endPercentage: 100.0,
                chargingType: .ac
            ),
            ChargingSession(
                date: refDate.addingTimeInterval(-86400 * 1),
                energyAdded: 25.0,
                startPercentage: 40.0,
                endPercentage: 80.0,
                chargingType: .ac
            )
        ]
        let healthyLFP = ChargingBehaviorService.analyze(sessions: healthyLFPSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(healthyLFP.metrics.daysSinceLastFullCharge, 3)
        XCTAssertEqual(healthyLFP.targetSoCScore, 100.0)
        XCTAssertTrue(healthyLFP.recommendations.contains { $0.category == .bmsCalibration && $0.level == .positive })

        // 2. Overdue 100% Calibration (last full charge 35 days ago)
        let overdueLFPSessions = [
            ChargingSession(
                date: refDate.addingTimeInterval(-86400 * 35),
                energyAdded: 45.0,
                startPercentage: 20.0,
                endPercentage: 100.0,
                chargingType: .ac
            ),
            ChargingSession(
                date: refDate.addingTimeInterval(-86400 * 10),
                energyAdded: 30.0,
                startPercentage: 30.0,
                endPercentage: 80.0,
                chargingType: .ac
            ),
            ChargingSession(
                date: refDate.addingTimeInterval(-86400 * 2),
                energyAdded: 30.0,
                startPercentage: 30.0,
                endPercentage: 80.0,
                chargingType: .ac
            )
        ]
        let overdueLFP = ChargingBehaviorService.analyze(sessions: overdueLFPSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(overdueLFP.metrics.daysSinceLastFullCharge, 35)
        XCTAssertLessThan(overdueLFP.targetSoCScore, 70.0)
        XCTAssertTrue(overdueLFP.recommendations.contains { $0.category == .bmsCalibration && $0.level == .caution })
    }

    func testTargetSoCScoreForNMCDailyCeiling() {
        let vehicle = Vehicle(name: "Tesla Model 3 LR", chemistry: .nmc)
        let refDate = Date()

        // 1. Healthy NMC Routine: charges to 80% daily
        let healthyNMCSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 5), energyAdded: 35.0, startPercentage: 30.0, endPercentage: 80.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 35.0, startPercentage: 30.0, endPercentage: 80.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 35.0, startPercentage: 30.0, endPercentage: 80.0, chargingType: .ac)
        ]
        let healthyNMC = ChargingBehaviorService.analyze(sessions: healthyNMCSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(healthyNMC.metrics.sessionsEndingAt100Percentage, 0.0)
        XCTAssertEqual(healthyNMC.targetSoCScore, 100.0)
        XCTAssertTrue(healthyNMC.recommendations.contains { $0.category == .targetSoC && $0.level == .positive })

        // 2. High-Stress NMC Routine: charges to 100% every single day
        let stressfulNMCSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 5), energyAdded: 45.0, startPercentage: 30.0, endPercentage: 100.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 45.0, startPercentage: 30.0, endPercentage: 100.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 45.0, startPercentage: 30.0, endPercentage: 100.0, chargingType: .ac)
        ]
        let stressfulNMC = ChargingBehaviorService.analyze(sessions: stressfulNMCSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(stressfulNMC.metrics.sessionsEndingAt100Percentage, 1.0)
        XCTAssertLessThan(stressfulNMC.targetSoCScore, 50.0)
        XCTAssertTrue(stressfulNMC.recommendations.contains { $0.category == .targetSoC && $0.level == .caution })
    }

    func testDischargeBufferScore() {
        let vehicle = Vehicle(name: "Test Car", chemistry: .nmc)
        let refDate = Date()

        // 1. Healthy Buffer (Starts >= 20%)
        let healthyBufferSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 30.0, startPercentage: 25.0, endPercentage: 80.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 30.0, startPercentage: 30.0, endPercentage: 80.0, chargingType: .ac)
        ]
        let healthyBuffer = ChargingBehaviorService.analyze(sessions: healthyBufferSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(healthyBuffer.dischargeBufferScore, 100.0)
        XCTAssertTrue(healthyBuffer.recommendations.contains { $0.category == .deepDischarge && $0.level == .positive })

        // 2. Deep Discharges (< 10%)
        let deepDischargeSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 3), energyAdded: 50.0, startPercentage: 5.0, endPercentage: 80.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 50.0, startPercentage: 8.0, endPercentage: 80.0, chargingType: .ac)
        ]
        let deepBuffer = ChargingBehaviorService.analyze(sessions: deepDischargeSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(deepBuffer.metrics.sessionsStartingBelow10Percentage, 1.0)
        XCTAssertLessThan(deepBuffer.dischargeBufferScore, 50.0)
        XCTAssertTrue(deepBuffer.recommendations.contains { $0.category == .deepDischarge && $0.level == .caution })
    }

    func testCycleConsistencyScore() {
        let vehicle = Vehicle(name: "Test Car", chemistry: .lfp)
        let refDate = Date()

        // Moderate depth of discharge (ΔSoC = 45%)
        let moderateSessions = [
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 2), energyAdded: 30.0, startPercentage: 35.0, endPercentage: 80.0, chargingType: .ac),
            ChargingSession(date: refDate.addingTimeInterval(-86400 * 1), energyAdded: 30.0, startPercentage: 35.0, endPercentage: 80.0, chargingType: .ac)
        ]
        let moderateAnalysis = ChargingBehaviorService.analyze(sessions: moderateSessions, vehicle: vehicle, referenceDate: refDate)
        XCTAssertEqual(moderateAnalysis.cycleConsistencyScore, 100.0)
    }

    func testChargingBehaviorGradesAndOrdering() {
        XCTAssertEqual(ChargingBehaviorGrade.grade(for: 95.0), .aPlus)
        XCTAssertEqual(ChargingBehaviorGrade.grade(for: 90.0), .a)
        XCTAssertEqual(ChargingBehaviorGrade.grade(for: 78.0), .b)
        XCTAssertEqual(ChargingBehaviorGrade.grade(for: 60.0), .c)
        XCTAssertEqual(ChargingBehaviorGrade.grade(for: 40.0), .d)

        XCTAssertTrue(ChargingBehaviorGrade.d < ChargingBehaviorGrade.c)
        XCTAssertTrue(ChargingBehaviorGrade.c < ChargingBehaviorGrade.b)
        XCTAssertTrue(ChargingBehaviorGrade.b < ChargingBehaviorGrade.a)
        XCTAssertTrue(ChargingBehaviorGrade.a < ChargingBehaviorGrade.aPlus)
    }

    func testUniversalBestPracticesList() {
        let practices = ChargingBestPracticeItem.universalBestPractices
        XCTAssertFalse(practices.isEmpty)

        for p in practices {
            XCTAssertFalse(p.id.isEmpty)
            XCTAssertFalse(p.title.isEmpty)
            XCTAssertFalse(p.summary.isEmpty)
            XCTAssertFalse(p.bullets.isEmpty)
        }

        // Verify key categories exist
        XCTAssertTrue(practices.contains { $0.chemistryApplicability == .lfpOnly })
        XCTAssertTrue(practices.contains { $0.chemistryApplicability == .nmcNcaOnly })
        XCTAssertTrue(practices.contains { $0.category == "AC vs. DC Speed" })
        XCTAssertTrue(practices.contains { $0.category == "Thermal Management" })
        XCTAssertTrue(practices.contains { $0.category == "Storage & Inactivity" })
    }
}
