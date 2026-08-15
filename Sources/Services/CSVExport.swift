import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

enum CSVExporter {
    static func generateCSV(from sessions: [ChargingSession], vehicles: [Vehicle] = []) -> String {
        var csv = "ID,Date,Location,Vendor,Mileage (km),Duration (min),Energy Added (kWh),Average Speed (kW),Start SoC (%),End SoC (%),Start Range (km),End Range (km),Charging Fee,Booking Fee,Overtime Fee,Price Per Unit,Total Price,Notes,Type,LocationType,PaymentStatus,Vehicle\n"

        let formatter = DateFormatter()
        // Fixed-format dates must not be written through the user's calendar: under a Buddhist-era
        // locale `yyyy` would emit 2569 for 2026, leaving a file no other tool can read. Must stay
        // in step with `CSVParser`.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let idStr = session.id ?? ""
            let dateStr = formatter.string(from: session.date)
            let mileage = session.mileage.map { String(format: "%.0f", $0) } ?? ""
            let duration = String(format: "%.0f", session.duration / 60)
            let energy = String(format: "%.2f", session.energyAdded)
            let speed = String(format: "%.2f", session.speed)
            let startSoC = session.startPercentage.map { String(format: "%.0f", $0) } ?? ""
            let endSoC = session.endPercentage.map { String(format: "%.0f", $0) } ?? ""
            let startR = session.startRange.map { String(format: "%.0f", $0) } ?? ""
            let endR = session.endRange.map { String(format: "%.0f", $0) } ?? ""
            let cFee = String(format: "%.2f", session.chargingFee)
            let bFee = String(format: "%.2f", session.bookingFee)
            let oFee = String(format: "%.2f", session.overtimeFee)
            let ppu = String(format: "%.2f", session.pricePerUnit)
            let total = String(format: "%.2f", session.totalPrice)
            let typeStr = session.chargingType?.rawValue ?? ""
            let locTypeStr = session.locationType?.rawValue ?? ""
            let payStatStr = session.paymentStatus?.rawValue ?? ""
            
            var vehicleName = ""
            if let vId = session.vehicleId, !vId.isEmpty {
                if let matched = vehicles.first(where: { $0.id == vId }) {
                    vehicleName = matched.name
                } else {
                    vehicleName = vId
                }
            }

            let row = [
                escapeCSV(idStr),
                dateStr,
                escapeCSV(session.locationName),
                escapeCSV(session.vendorName),
                mileage,
                duration,
                energy,
                speed,
                startSoC,
                endSoC,
                startR,
                endR,
                cFee,
                bFee,
                oFee,
                ppu,
                total,
                escapeCSV(session.notes),
                escapeCSV(typeStr),
                escapeCSV(locTypeStr),
                escapeCSV(payStatStr),
                escapeCSV(vehicleName)
            ].joined(separator: ",") + "\n"

            csv.append(row)
        }
        return csv
    }

    private static func escapeCSV(_ string: String?) -> String {
        guard let string = string else { return "" }
        // A bare carriage return has to be quoted too — the parser treats it as a row terminator,
        // so an unquoted one splits the row and corrupts everything after it.
        if string.contains(",") || string.contains("\"") || string.contains("\n") || string.contains("\r") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}
