import XCTest
@testable import Joule

final class DeduplicationTests: XCTestCase {

    func testHomeChargingDuplicateDetection() {
        let baseDate = Date(timeIntervalSince1970: 1786598400) // 2026-08-11 10:00:00 UTC

        let homeSession1 = ChargingSession(
            id: "home-doc-1",
            locationName: "Home",
            vendorName: nil,
            date: baseDate,
            duration: 14400,
            energyAdded: 28.5,
            speed: 7.1,
            chargingFee: 75.0,
            bookingFee: 0,
            overtimeFee: 0,
            pricePerUnit: 2.63,
            totalPrice: 75.0,
            mileage: 15200,
            startPercentage: 40,
            endPercentage: 80,
            chargingType: .ac,
            locationType: .home,
            paymentStatus: .deferred,
            notes: "Night charging"
        )

        // Exact duplicate with different ID (e.g. from re-import or local vs cloud ID)
        let homeSession2 = ChargingSession(
            id: "local-uuid-999",
            locationName: "Home",
            vendorName: nil,
            date: baseDate.addingTimeInterval(60), // 1 minute later
            duration: 14400,
            energyAdded: 28.52,
            speed: 7.1,
            chargingFee: 75.0,
            bookingFee: 0,
            overtimeFee: 0,
            pricePerUnit: 2.63,
            totalPrice: 75.0,
            mileage: 15200,
            startPercentage: 40,
            endPercentage: 80,
            chargingType: .ac,
            locationType: .home,
            paymentStatus: .deferred,
            notes: nil
        )

        XCTAssertTrue(homeSession1.isDuplicate(of: homeSession2))
        XCTAssertTrue(homeSession2.isDuplicate(of: homeSession1))
    }

    func testDifferentDaysAreNotDuplicates() {
        let baseDate = Date(timeIntervalSince1970: 1786598400) // Day 1

        let day1Session = ChargingSession(
            id: "day-1",
            locationName: "Home",
            date: baseDate,
            energyAdded: 25.0,
            locationType: .home
        )

        let day2Session = ChargingSession(
            id: "day-2",
            locationName: "Home",
            date: baseDate.addingTimeInterval(86400), // Day 2 (24 hours later)
            energyAdded: 25.0,
            locationType: .home
        )

        XCTAssertFalse(day1Session.isDuplicate(of: day2Session))
        XCTAssertFalse(day2Session.isDuplicate(of: day1Session))
    }

    func testMetadataMergingKeepsRicherData() {
        let baseDate = Date(timeIntervalSince1970: 1786598400)

        let sparseSession = ChargingSession(
            id: "cloud-doc-123",
            locationName: "Home",
            date: baseDate,
            energyAdded: 30.0,
            totalPrice: 80.0,
            locationType: .home
        )

        let richSession = ChargingSession(
            id: nil,
            locationName: "Home",
            date: baseDate.addingTimeInterval(30),
            duration: 15000,
            energyAdded: 30.0,
            speed: 7.2,
            totalPrice: 80.0,
            mileage: 18500,
            startPercentage: 30,
            endPercentage: 75,
            chargingType: .ac,
            locationType: .home,
            paymentStatus: .deferred,
            notes: "Charged during TOU off-peak hours"
        )

        let merged = sparseSession.merged(with: richSession)

        XCTAssertEqual(merged.id, "cloud-doc-123") // Preserves existing ID
        XCTAssertEqual(merged.mileage, 18500)
        XCTAssertEqual(merged.startPercentage, 30)
        XCTAssertEqual(merged.endPercentage, 75)
        XCTAssertEqual(merged.duration, 15000)
        XCTAssertEqual(merged.speed, 7.2)
        XCTAssertEqual(merged.notes, "Charged during TOU off-peak hours")
        XCTAssertEqual(merged.chargingType, .ac)
        XCTAssertEqual(merged.paymentStatus, .deferred)
    }

    func testFindDuplicatesDeduplicationEngine() {
        let baseDate1 = Date(timeIntervalSince1970: 1786598400)
        let baseDate2 = Date(timeIntervalSince1970: 1786684800) // Next day

        let s1 = ChargingSession(id: "s1", locationName: "Home", date: baseDate1, energyAdded: 20.0, locationType: .home)
        let s1_dup1 = ChargingSession(id: "s1_dup1", locationName: "Home", date: baseDate1.addingTimeInterval(45), energyAdded: 20.05, locationType: .home)
        let s1_dup2 = ChargingSession(id: "s1_dup2", locationName: "Home", date: baseDate1.addingTimeInterval(120), energyAdded: 20.0, locationType: .home)

        let s2 = ChargingSession(id: "s2", locationName: "Home", date: baseDate2, energyAdded: 22.0, locationType: .home)
        let s2_dup = ChargingSession(id: "s2_dup", locationName: "Home", date: baseDate2.addingTimeInterval(30), energyAdded: 22.0, locationType: .home)

        let allSessions = [s1, s1_dup1, s1_dup2, s2, s2_dup]

        let (unique, duplicates) = SessionStore.findDuplicates(in: allSessions)

        XCTAssertEqual(unique.count, 2)
        XCTAssertEqual(duplicates.count, 3)
    }

    func testCSVImportWithDuplicatesSkipped() {
        let alerts = AlertCenter()
        let store = SessionStore(alerts: alerts)

        let baseDate = Date(timeIntervalSince1970: 1786598400)
        let existingSession = ChargingSession(
            id: "existing-1",
            locationName: "Home",
            date: baseDate,
            energyAdded: 35.0,
            locationType: .home
        )
        store.sessions = [existingSession]

        // Import list containing 1 duplicate of existing, 1 new unique session, and 1 duplicate within the batch
        let newDate = Date(timeIntervalSince1970: 1786771200)
        let imported = [
            ChargingSession(locationName: "Home", date: baseDate.addingTimeInterval(60), energyAdded: 35.0, locationType: .home), // Dup of existing
            ChargingSession(locationName: "Central World", date: newDate, energyAdded: 45.0, locationType: .publicStation),      // Unique
            ChargingSession(locationName: "Central World", date: newDate.addingTimeInterval(30), energyAdded: 45.0, locationType: .publicStation) // Dup of previous
        ]

        store.importSessions(imported)

        // Total sessions should now be 2 (existing 1 + 1 new unique)
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertTrue(store.sessions.contains(where: { $0.locationName == "Central World" }))
    }
}
