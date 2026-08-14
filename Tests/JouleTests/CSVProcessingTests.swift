import XCTest
@testable import Joule

final class CSVProcessingTests: XCTestCase {

    func testSanitizedCSVParsingWithEscapesAndQuotes() {
        let csvRaw = """
        "Header 1","Header, with comma","Header with \"\"quotes\"\""
        "Value 1","Value, with comma","Value with \"\"quotes\"\""
        "Line 1
        Line 2","Normal",123.45
        """

        let rows = CSVParser.parseCSV(from: csvRaw)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["Header 1", "Header, with comma", "Header with \"quotes\""])
        XCTAssertEqual(rows[1], ["Value 1", "Value, with comma", "Value with \"quotes\""])
        XCTAssertEqual(rows[2][0], "Line 1\nLine 2")
        XCTAssertEqual(rows[2][1], "Normal")
        XCTAssertEqual(rows[2][2], "123.45")
    }

    func testHeaderMappingFallbackAndCaseInsensitivity() {
        // Headers are shuffled and in mixed case / alternative keywords
        let csvContent = """
        TOTAL COST,VENDOR NAME,LOCATION,DATE,ENERGY,DURATION,START %,END %,SPEED,MILEAGE,NOTES
        ฿450.00,Tesla Supercharger,Central World,2026-08-10 14:30,45.5,35,15,80,78,14500,Super fast charging
        """

        let result = CSVParser.parseSessions(from: csvContent)
        XCTAssertEqual(result.sessions.count, 1)
        XCTAssertEqual(result.skippedRows, 0)

        let session = result.sessions[0]
        XCTAssertEqual(session.locationName, "Central World")
        XCTAssertEqual(session.vendorName, "Tesla Supercharger")
        XCTAssertEqual(session.energyAdded, 45.5)
        XCTAssertEqual(session.duration, 35 * 60)
        XCTAssertEqual(session.startPercentage, 15.0)
        XCTAssertEqual(session.endPercentage, 80.0)
        XCTAssertEqual(session.speed, 78.0)
        XCTAssertEqual(session.totalPrice, 450.0)
        XCTAssertEqual(session.mileage, 14500.0)
        XCTAssertEqual(session.notes, "Super fast charging")
    }

    func testThaiAndEnglishCharacterEncoding() {
        let thaiCSV = """
        Date,Location,Vendor,Energy (kWh),Duration (min),Speed (kW),Charging Fee,Booking Fee,Overtime Fee,Total Cost,Start %,End %,Mileage,Notes
        2026-08-11 18:00,สถานีชาร์จ MEA ปตท. วิภาวดี,การไฟฟ้านครหลวง,30.0,25,72,฿180.00,฿0.00,฿0.00,฿180.00,20,65,15200,ชาร์จก่อนกลับบ้าน รถไม่ติด
        2026-08-12 09:15,Siam Paragon EV Zone,EA Anywhere,22.4,120,11,฿145.50,฿50.00,฿0.00,฿195.50,40,75,15350,ที่จอดรถชั้น B1 สะดวกมาก
        """

        let result = CSVParser.parseSessions(from: thaiCSV)
        XCTAssertEqual(result.sessions.count, 2)
        XCTAssertEqual(result.skippedRows, 0)

        let s1 = result.sessions[0]
        XCTAssertEqual(s1.locationName, "สถานีชาร์จ MEA ปตท. วิภาวดี")
        XCTAssertEqual(s1.vendorName, "การไฟฟ้านครหลวง")
        XCTAssertEqual(s1.notes, "ชาร์จก่อนกลับบ้าน รถไม่ติด")

        let s2 = result.sessions[1]
        XCTAssertEqual(s2.locationName, "Siam Paragon EV Zone")
        XCTAssertEqual(s2.vendorName, "EA Anywhere")
        XCTAssertEqual(s2.bookingFee, 50.0)
        XCTAssertEqual(s2.totalPrice, 195.50)
        XCTAssertEqual(s2.notes, "ที่จอดรถชั้น B1 สะดวกมาก")
    }

    func testEdgeCaseNumbersAndCurrencies() {
        let dirtyNumbersCSV = """
        Date,Location,Energy (kWh),Charging Fee,Total Cost,Mileage
        2026-08-01 10:00,Station A," 45.50 "," ฿1,250.00 "," ฿1,250.00 "," 15,420.5 "
        2026-08-02 11:00,Station B,32.0,$45.75,$45.75,"16,000"
        2026-08-03 12:00,Station C,28.0,€18.50,€18.50,16500
        2026-08-04 13:00,Station D,50.0,"¥1,500","¥1,500",17000
        2026-08-05 14:00,Station E,40.0,£25.00,£25.00,17500
        2026-08-06 15:00,Station F,35.0,CHF 30.00,CHF 30.00,18000
        """

        let result = CSVParser.parseSessions(from: dirtyNumbersCSV)
        XCTAssertEqual(result.sessions.count, 6)

        XCTAssertEqual(result.sessions[0].energyAdded, 45.5)
        XCTAssertEqual(result.sessions[0].chargingFee, 1250.0)
        XCTAssertEqual(result.sessions[0].totalPrice, 1250.0)
        XCTAssertEqual(result.sessions[0].mileage, 15420.5)

        XCTAssertEqual(result.sessions[1].chargingFee, 45.75)
        XCTAssertEqual(result.sessions[1].mileage, 16000.0)

        XCTAssertEqual(result.sessions[2].chargingFee, 18.50)
        XCTAssertEqual(result.sessions[3].chargingFee, 1500.0)
        XCTAssertEqual(result.sessions[4].chargingFee, 25.00)
        XCTAssertEqual(result.sessions[5].chargingFee, 30.00)
    }

    func testSkippedRowsHandling() {
        let invalidDateCSV = """
        Date,Location,Energy
        not-a-date,Invalid Location,30.0
        2026-08-01 10:00,Valid Location,30.0
        ,Missing Date,20.0
        """

        let result = CSVParser.parseSessions(from: invalidDateCSV)
        XCTAssertEqual(result.sessions.count, 1)
        XCTAssertEqual(result.skippedRows, 2)
        XCTAssertEqual(result.sessions[0].locationName, "Valid Location")
    }

    func testRoundTripExportAndImportVerification() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let originalDate1 = formatter.date(from: "2026-08-01 10:30")!
        let originalDate2 = formatter.date(from: "2026-08-02 14:45")!

        let session1 = ChargingSession(
            id: "test-id-1",
            locationName: "สถานีชาร์จ ปตท. \"Super DC\", วิภาวดี",
            vendorName: "EV Station PluZ",
            date: originalDate1,
            duration: 1800, // 30 min
            energyAdded: 42.55,
            speed: 85.10,
            chargingFee: 319.13,
            bookingFee: 20.00,
            overtimeFee: 0.00,
            pricePerUnit: 7.50,
            totalPrice: 339.13,
            mileage: 12500,
            startPercentage: 20,
            endPercentage: 80,
            startRange: 120,
            endRange: 480,
            chargingType: .dc,
            locationType: .publicStation,
            paymentStatus: .paidUpfront,
            notes: "Smooth charging session, highly recommended!"
        )

        let session2 = ChargingSession(
            id: "test-id-2",
            locationName: "Home Wallbox",
            vendorName: nil,
            date: originalDate2,
            duration: 14400, // 240 min
            energyAdded: 28.00,
            speed: 7.00,
            chargingFee: 73.64,
            bookingFee: 0.00,
            overtimeFee: 0.00,
            pricePerUnit: 2.63,
            totalPrice: 73.64,
            mileage: 12650,
            startPercentage: 50,
            endPercentage: 90,
            startRange: 300,
            endRange: 540,
            chargingType: .ac,
            locationType: .home,
            paymentStatus: .deferred,
            notes: "Overnight TOU off-peak charging\nCompleted at 06:00"
        )

        let originalSessions = [session1, session2]

        // 1. Export to CSV string
        let exportedCSV = CSVExporter.generateCSV(from: originalSessions)
        XCTAssertFalse(exportedCSV.isEmpty)

        // 2. Parse back from CSV string
        let importResult = CSVParser.parseSessions(from: exportedCSV)
        XCTAssertEqual(importResult.skippedRows, 0)
        XCTAssertEqual(importResult.sessions.count, 2)

        // Sessions are exported sorted by date desc, so session2 (Aug 2) is first, session1 (Aug 1) is second
        let importedS2 = importResult.sessions[0]
        let importedS1 = importResult.sessions[1]

        XCTAssertEqual(importedS1.id, session1.id)
        XCTAssertEqual(importedS1.locationName, session1.locationName)
        XCTAssertEqual(importedS1.vendorName, session1.vendorName)
        XCTAssertEqual(importedS1.energyAdded, session1.energyAdded, accuracy: 0.01)
        XCTAssertEqual(importedS1.duration, session1.duration)
        XCTAssertEqual(importedS1.speed, session1.speed, accuracy: 0.01)
        XCTAssertEqual(importedS1.chargingFee, session1.chargingFee, accuracy: 0.01)
        XCTAssertEqual(importedS1.bookingFee, session1.bookingFee, accuracy: 0.01)
        XCTAssertEqual(importedS1.totalPrice, session1.totalPrice, accuracy: 0.01)
        XCTAssertEqual(importedS1.mileage, session1.mileage)
        XCTAssertEqual(importedS1.startPercentage, session1.startPercentage)
        XCTAssertEqual(importedS1.endPercentage, session1.endPercentage)
        XCTAssertEqual(importedS1.chargingType, session1.chargingType)
        XCTAssertEqual(importedS1.locationType, session1.locationType)
        XCTAssertEqual(importedS1.paymentStatus, session1.paymentStatus)
        XCTAssertEqual(importedS1.notes, session1.notes)

        XCTAssertEqual(importedS2.id, session2.id)
        XCTAssertEqual(importedS2.locationName, session2.locationName)
        XCTAssertEqual(importedS2.chargingType, .ac)
        XCTAssertEqual(importedS2.locationType, .home)
        XCTAssertEqual(importedS2.paymentStatus, .deferred)
        XCTAssertEqual(importedS2.notes, session2.notes)
    }
}
