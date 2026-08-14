import Foundation

/// Outcome of reading a CSV file: the sessions that could be understood, plus a count of the rows
/// that could not, so the import can tell the user what it dropped instead of doing so silently.
struct CSVImportResult {
    var sessions: [ChargingSession] = []
    var skippedRows: Int = 0
}

struct CSVParser {

    static func parseCSV(from string: String) -> [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let characters = Array(string)
        var i = 0

        while i < characters.count {
            let char = characters[i]

            if char == "\"" {
                if insideQuotes, i + 1 < characters.count, characters[i + 1] == "\"" {
                    // Escaped quote
                    currentField.append("\"")
                    i += 1
                } else {
                    // Toggle quotes
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // End of field
                currentRow.append(currentField)
                currentField = ""
            } else if (char == "\n" || char == "\r") && !insideQuotes {
                // End of row
                if char == "\r", i + 1 < characters.count, characters[i + 1] == "\n" {
                    i += 1
                }
                currentRow.append(currentField)
                result.append(currentRow)
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }

            i += 1
        }

        // Append last field and row if not empty
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            result.append(currentRow)
        }

        return result
    }

    static func parseSessions(from string: String) -> CSVImportResult {
        let rows = parseCSV(from: string)
        guard rows.count > 1 else { return CSVImportResult() }

        let headerRow = rows[0].map { trimmed($0).lowercased() }
        let dataRows = rows.dropFirst()

        // Build header index map if headers are recognized
        func colIndex(_ keywords: [String], fallback: Int) -> Int {
            for (idx, h) in headerRow.enumerated() {
                for kw in keywords {
                    if h.contains(kw) { return idx }
                }
            }
            return fallback
        }

        let idIdx = colIndex(["id"], fallback: 0)
        let dateIdx = colIndex(["date"], fallback: 1)
        let locIdx = colIndex(["location"], fallback: 2)
        let vendorIdx = colIndex(["vendor"], fallback: 3)
        let mileageIdx = colIndex(["mileage"], fallback: 4)
        let durationIdx = colIndex(["duration"], fallback: 5)
        let energyIdx = colIndex(["energy"], fallback: 6)
        let speedIdx = colIndex(["speed"], fallback: 7)
        let startSoCIdx = colIndex(["start soc", "start %", "start percentage"], fallback: 8)
        let endSoCIdx = colIndex(["end soc", "end %", "end percentage"], fallback: 9)
        let startRIdx = colIndex(["start range"], fallback: 10)
        let endRIdx = colIndex(["end range"], fallback: 11)
        let cFeeIdx = colIndex(["charging fee"], fallback: 12)
        let bFeeIdx = colIndex(["booking fee"], fallback: 13)
        let oFeeIdx = colIndex(["overtime fee"], fallback: 14)
        let ppuIdx = colIndex(["price per unit", "unit price"], fallback: 15)
        let totalIdx = colIndex(["total price", "total cost", "total"], fallback: 16)
        let notesIdx = colIndex(["notes", "note"], fallback: 17)
        let typeIdx = colIndex(["type"], fallback: 18)
        let locTypeIdx = colIndex(["locationtype", "location type"], fallback: 19)
        let payStatIdx = colIndex(["paymentstatus", "payment status", "payment"], fallback: 20)

        var result = CSVImportResult()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Secondary fallback formatter for ISO8601 or simple dates
        let isoFormatter = ISO8601DateFormatter()

        for row in dataRows {
            guard row.contains(where: { !trimmed($0).isEmpty }) else { continue }

            guard dateIdx < row.count else {
                result.skippedRows += 1
                continue
            }

            let dateRaw = trimmed(row[dateIdx])
            guard let date = formatter.date(from: dateRaw) ?? isoFormatter.date(from: dateRaw) else {
                result.skippedRows += 1
                continue
            }

            func valAt(_ idx: Int) -> String {
                idx < row.count ? row[idx] : ""
            }

            let id = optional(valAt(idIdx))
            let locationName = optional(valAt(locIdx))
            let vendorName = optional(valAt(vendorIdx))
            let mileage = number(valAt(mileageIdx))
            let duration = (number(valAt(durationIdx)) ?? 0) * 60
            let energyAdded = number(valAt(energyIdx)) ?? 0
            let speed = number(valAt(speedIdx)) ?? 0
            let startSoC = number(valAt(startSoCIdx))
            let endSoC = number(valAt(endSoCIdx))
            let startR = number(valAt(startRIdx))
            let endR = number(valAt(endRIdx))
            let cFee = number(valAt(cFeeIdx)) ?? 0
            let bFee = number(valAt(bFeeIdx)) ?? 0
            let oFee = number(valAt(oFeeIdx)) ?? 0
            let ppu = number(valAt(ppuIdx)) ?? 0
            let total = number(valAt(totalIdx)) ?? 0
            let notes = optional(valAt(notesIdx))

            let chargingType = ChargingType(rawValue: trimmed(valAt(typeIdx)))
            let locationType = LocationType(rawValue: trimmed(valAt(locTypeIdx)))
            let paymentStatus = PaymentStatus(rawValue: trimmed(valAt(payStatIdx)))

            let session = ChargingSession(
                id: id,
                locationName: locationName,
                vendorName: vendorName,
                date: date,
                duration: duration,
                energyAdded: energyAdded,
                speed: speed,
                chargingFee: cFee,
                bookingFee: bFee,
                overtimeFee: oFee,
                pricePerUnit: ppu,
                totalPrice: total,
                mileage: mileage,
                startPercentage: startSoC,
                endPercentage: endSoC,
                startRange: startR,
                endRange: endR,
                chargingType: chargingType,
                locationType: locationType,
                paymentStatus: paymentStatus,
                notes: notes
            )

            result.sessions.append(session)
        }

        return result
    }

    // MARK: - Field helpers
    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func optional(_ value: String) -> String? {
        let value = trimmed(value)
        return value.isEmpty ? nil : value
    }

    private static func number(_ value: String) -> Double? {
        var clean = trimmed(value)
        guard !clean.isEmpty else { return nil }
        clean = clean.replacingOccurrences(of: ",", with: "")
        // Strip common currency symbols
        let currencySymbols = ["฿", "$", "€", "£", "¥", "₩", "₹", "kr", "CHF"]
        for sym in currencySymbols {
            clean = clean.replacingOccurrences(of: sym, with: "")
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean)
    }
}
