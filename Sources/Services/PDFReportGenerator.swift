import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PDFKit

/// FileDocument wrapper for saving and exporting generated PDF statements.
struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Service for generating employer reimbursement statements and tax expense PDF reports from charging history.
enum PDFReportGenerator {

    static func generatePDF(
        sessions: [ChargingSession],
        vehicle: Vehicle,
        currency: AppCurrency,
        unitSystem: UnitSystem,
        title: String = "EV Charging Expense & Reimbursement Statement",
        dateRangeTitle: String = "All Time"
    ) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Joule EV Charging Tracker",
            kCGPDFContextAuthor: "Joule",
            kCGPDFContextTitle: title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        // Standard A4 Page Size: 595.2 x 841.8 points
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 36.0
        let contentWidth = pageWidth - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let sortedSessions = sessions.sorted { $0.date > $1.date }
        let totalCost = sortedSessions.reduce(0) { $0 + $1.totalPrice }
        let totalEnergy = sortedSessions.reduce(0) { $0 + $1.energyAdded }
        let homeSessions = sortedSessions.filter { $0.locationType == .home || ($0.locationName?.lowercased().contains("home") == true) }
        let homeCost = homeSessions.reduce(0) { $0 + $1.totalPrice }
        let publicCost = totalCost - homeCost

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let data = renderer.pdfData { context in
            var currentPage = 0
            var currentY = margin

            func startNewPage() {
                context.beginPage()
                currentPage += 1
                currentY = margin
                drawHeader(context: context.cgContext, pageRect: pageRect, margin: margin, contentWidth: contentWidth, y: &currentY, title: title, dateRangeTitle: dateRangeTitle, vehicle: vehicle, pageNumber: currentPage)
            }

            startNewPage()

            // Draw Summary Cards Box
            drawSummaryCards(
                context: context.cgContext,
                margin: margin,
                contentWidth: contentWidth,
                y: &currentY,
                totalCost: totalCost,
                totalEnergy: totalEnergy,
                homeCost: homeCost,
                publicCost: publicCost,
                currency: currency,
                sessionCount: sortedSessions.count
            )

            // Table Header
            drawTableHeader(context: context.cgContext, margin: margin, contentWidth: contentWidth, y: &currentY, currency: currency)

            // Rows
            let rowHeight: CGFloat = 22.0
            for session in sortedSessions {
                // Check if row fits on current page (leave room for footer)
                if currentY + rowHeight > pageHeight - 60.0 {
                    startNewPage()
                    drawTableHeader(context: context.cgContext, margin: margin, contentWidth: contentWidth, y: &currentY, currency: currency)
                }

                drawTableRow(
                    context: context.cgContext,
                    margin: margin,
                    contentWidth: contentWidth,
                    y: &currentY,
                    rowHeight: rowHeight,
                    session: session,
                    dateFormatter: dateFormatter,
                    currency: currency
                )
            }

            // Draw Totals & Signature Block
            if currentY + 90.0 > pageHeight - 40.0 {
                startNewPage()
            }
            drawFooterBlock(
                context: context.cgContext,
                margin: margin,
                contentWidth: contentWidth,
                y: &currentY,
                totalCost: totalCost,
                totalEnergy: totalEnergy,
                currency: currency
            )
        }

        return data
    }

    // MARK: - Drawing Helpers

    private static func drawHeader(
        context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat,
        y: inout CGFloat,
        title: String,
        dateRangeTitle: String,
        vehicle: Vehicle,
        pageNumber: Int
    ) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let vehicleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
        y += 24.0

        let subtext = "Period: \(dateRangeTitle)  •  Vehicle: \(vehicle.name) (\(vehicle.chemistry.badgeTitle), \(String(format: "%.1f", vehicle.nominalCapacityKWh)) kWh)\(vehicle.licensePlate.map { "  •  Plate: \($0)" } ?? "")"
        subtext.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttributes)
        y += 16.0

        let generatedDateStr = "Generated on \(Date().formatted(.dateTime.year().month(.wide).day().hour().minute().locale(Locale(identifier: "en_US_POSIX"))))  •  Page \(pageNumber)"
        generatedDateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: vehicleAttributes)
        y += 18.0

        // Horizontal Rule
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.8)
        context.beginPath()
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        y += 14.0
    }

    private static func drawSummaryCards(
        context: CGContext,
        margin: CGFloat,
        contentWidth: CGFloat,
        y: inout CGFloat,
        totalCost: Double,
        totalEnergy: Double,
        homeCost: Double,
        publicCost: Double,
        currency: AppCurrency,
        sessionCount: Int
    ) {
        let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 50.0)
        let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 6.0)
        context.setFillColor(UIColor.secondarySystemBackground.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        let colWidth = contentWidth / 4.0
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.label
        ]

        // 1. Total Reimbursement
        String(localized: "TOTAL EXPENSE").draw(at: CGPoint(x: margin + 10, y: y + 8), withAttributes: labelAttr)
        currency.format(totalCost).draw(at: CGPoint(x: margin + 10, y: y + 22), withAttributes: valAttr)

        // 2. Energy
        String(localized: "TOTAL ENERGY").draw(at: CGPoint(x: margin + colWidth + 10, y: y + 8), withAttributes: labelAttr)
        String(format: "%.1f kWh", totalEnergy).draw(at: CGPoint(x: margin + colWidth + 10, y: y + 22), withAttributes: valAttr)

        // 3. Home vs Public
        String(localized: "HOME (OFF-PEAK)").draw(at: CGPoint(x: margin + (colWidth * 2) + 10, y: y + 8), withAttributes: labelAttr)
        currency.format(homeCost).draw(at: CGPoint(x: margin + (colWidth * 2) + 10, y: y + 22), withAttributes: valAttr)

        // 4. Public Fast Charge
        String(localized: "PUBLIC FAST CHARGE").draw(at: CGPoint(x: margin + (colWidth * 3) + 10, y: y + 8), withAttributes: labelAttr)
        currency.format(publicCost).draw(at: CGPoint(x: margin + (colWidth * 3) + 10, y: y + 22), withAttributes: valAttr)

        y += 62.0
    }

    private static func drawTableHeader(
        context: CGContext,
        margin: CGFloat,
        contentWidth: CGFloat,
        y: inout CGFloat,
        currency: AppCurrency
    ) {
        let headerBg = CGRect(x: margin, y: y, width: contentWidth, height: 18.0)
        context.setFillColor(UIColor.tertiarySystemFill.cgColor)
        context.fill(headerBg)

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
            .foregroundColor: UIColor.label
        ]

        String(localized: "DATE & TIME").draw(at: CGPoint(x: margin + 4, y: y + 4), withAttributes: attr)
        String(localized: "LOCATION / VENDOR").draw(at: CGPoint(x: margin + 105, y: y + 4), withAttributes: attr)
        String(localized: "TYPE").draw(at: CGPoint(x: margin + 270, y: y + 4), withAttributes: attr)
        String(localized: "ENERGY").draw(at: CGPoint(x: margin + 320, y: y + 4), withAttributes: attr)
        String(localized: "SoC").draw(at: CGPoint(x: margin + 380, y: y + 4), withAttributes: attr)
        String(localized: "RATE").draw(at: CGPoint(x: margin + 435, y: y + 4), withAttributes: attr)
        String(format: String(localized: "TOTAL (%@)"), currency.code).draw(at: CGPoint(x: margin + contentWidth - 65, y: y + 4), withAttributes: attr)

        y += 20.0
    }

    private static func drawTableRow(
        context: CGContext,
        margin: CGFloat,
        contentWidth: CGFloat,
        y: inout CGFloat,
        rowHeight: CGFloat,
        session: ChargingSession,
        dateFormatter: DateFormatter,
        currency: AppCurrency
    ) {
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let numAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let boldNumAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        let dateStr = dateFormatter.string(from: session.date)
        dateStr.draw(at: CGPoint(x: margin + 4, y: y + 5), withAttributes: numAttr)

        let locStr = (session.locationName ?? session.vendorName ?? "Unknown").prefix(32)
        String(locStr).draw(at: CGPoint(x: margin + 105, y: y + 5), withAttributes: textAttr)

        let typeStr = session.chargingType?.rawValue ?? (session.locationType == .home ? "AC (Home)" : "DC")
        typeStr.draw(at: CGPoint(x: margin + 270, y: y + 5), withAttributes: textAttr)

        String(format: "%.1f kWh", session.energyAdded).draw(at: CGPoint(x: margin + 320, y: y + 5), withAttributes: numAttr)

        let socStr: String
        if let s = session.startPercentage, let e = session.endPercentage {
            socStr = String(format: "%.0f→%.0f%%", s, e)
        } else {
            socStr = "—"
        }
        socStr.draw(at: CGPoint(x: margin + 380, y: y + 5), withAttributes: numAttr)

        let rateStr = session.pricePerUnit > 0 ? String(format: "%.2f", session.pricePerUnit) : "—"
        rateStr.draw(at: CGPoint(x: margin + 435, y: y + 5), withAttributes: numAttr)

        let totalStr = String(format: "%.2f", session.totalPrice)
        totalStr.draw(at: CGPoint(x: margin + contentWidth - 55, y: y + 5), withAttributes: boldNumAttr)

        // Divider line
        context.setStrokeColor(UIColor.separator.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)
        context.beginPath()
        context.move(to: CGPoint(x: margin, y: y + rowHeight))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y + rowHeight))
        context.strokePath()

        y += rowHeight
    }

    private static func drawFooterBlock(
        context: CGContext,
        margin: CGFloat,
        contentWidth: CGFloat,
        y: inout CGFloat,
        totalCost: Double,
        totalEnergy: Double,
        currency: AppCurrency
    ) {
        y += 12.0

        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let regularAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let totalLine = String(format: String(localized: "Grand Total Claim: %1$@  (%2$.2f kWh total)"), currency.format(totalCost), totalEnergy)
        totalLine.draw(at: CGPoint(x: margin + 4, y: y), withAttributes: boldAttr)
        y += 24.0

        // Declaration & Signatures
        let declaration = String(localized: "I certify that the electric vehicle charging expenses itemized above were incurred for vehicle operation and reflect actual electricity and charging fees paid.")
        declaration.draw(at: CGPoint(x: margin + 4, y: y), withAttributes: regularAttr)
        y += 24.0

        // Signature lines
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(0.8)

        // Driver signature
        context.beginPath()
        context.move(to: CGPoint(x: margin + 4, y: y + 14))
        context.addLine(to: CGPoint(x: margin + 180, y: y + 14))
        context.strokePath()
        String(localized: "Driver Signature / Date").draw(at: CGPoint(x: margin + 4, y: y + 18), withAttributes: regularAttr)

        // Manager / Approver signature
        context.beginPath()
        context.move(to: CGPoint(x: margin + contentWidth - 180, y: y + 14))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y + 14))
        context.strokePath()
        String(localized: "Approved by / Date").draw(at: CGPoint(x: margin + contentWidth - 180, y: y + 18), withAttributes: regularAttr)

        y += 36.0
    }
}
