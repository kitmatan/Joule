import SwiftUI
import Vision
import PhotosUI

/// Scanned metrics parsed from a charging receipt or dispenser screen photo.
struct ScannedChargingData: Equatable {
    var energyAdded: Double?
    var totalPrice: Double?
    var durationMinutes: Double?
    var startPercentage: Double?
    var endPercentage: Double?
    var speedKW: Double?
    var locationOrVendor: String?
    var rawDetectedText: String = ""

    var hasData: Bool {
        energyAdded != nil || totalPrice != nil || durationMinutes != nil || startPercentage != nil || endPercentage != nil
    }
}

/// A smart camera & photo OCR scanner that parses charging dispenser screens and receipt images into session fields.
struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onApply: (ScannedChargingData) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var scannedData = ScannedChargingData()
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = selectedImage {
                        imagePreviewSection(image: image)
                    } else {
                        emptyPickerState
                    }

                    if isProcessing {
                        ProgressView("Analyzing receipt text…")
                            .padding()
                    } else if scannedData.hasData {
                        scannedResultsCard
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Receipt or Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if scannedData.hasData {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            onApply(scannedData)
                            dismiss()
                        }
                        .bold()
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                loadSelectedPhoto(newItem)
            }
        }
    }

    private var emptyPickerState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Scan Charger Screen or Receipt")
                .font(.headline)

            Text("Select a photo of your EV charger screen, charging app confirmation, or printed receipt to auto-fill session metrics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose Photo from Library", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }

    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Pick Another Photo", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
        }
    }

    private var scannedResultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("Extracted Charging Values")
                    .font(.headline)
                Spacer()
                Text("Review & Apply")
                    .font(.caption2).bold()
                    .foregroundColor(.green)
            }

            Divider()

            VStack(spacing: 10) {
                if let energy = scannedData.energyAdded {
                    ResultRow(title: "Energy Added", value: String(format: "%.2f kWh", energy), icon: "bolt.fill", color: .blue)
                }

                if let cost = scannedData.totalPrice {
                    ResultRow(title: "Total Cost", value: String(format: "%.2f", cost), icon: "creditcard.fill", color: .green)
                }

                if let mins = scannedData.durationMinutes {
                    ResultRow(title: "Duration", value: String(format: "%.0f min", mins), icon: "clock.fill", color: .orange)
                }

                if let start = scannedData.startPercentage, let end = scannedData.endPercentage {
                    ResultRow(title: "State of Charge", value: String(format: "%.0f%% → %.0f%%", start, end), icon: "battery.100", color: .indigo)
                }

                if let speed = scannedData.speedKW {
                    ResultRow(title: "Charging Speed", value: String(format: "%.1f kW", speed), icon: "bolt.badge.clock.fill", color: .cyan)
                }

                if let loc = scannedData.locationOrVendor {
                    ResultRow(title: "Location / Vendor", value: loc, icon: "mappin.and.ellipse", color: .purple)
                }
            }

            Button {
                onApply(scannedData)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                    Text("Apply Extracted Values to Session")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 6)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil
        scannedData = ScannedChargingData()

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = image
                }
                processImageOCR(image: image)
            } else {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Could not load the selected image."
                }
            }
        }
    }

    private func processImageOCR(image: UIImage) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            errorMessage = "Invalid image data."
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "No text recognized."
                }
                return
            }

            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            let fullText = recognizedStrings.joined(separator: "\n")

            let parsed = ReceiptParser.parse(text: fullText)

            DispatchQueue.main.async {
                self.isProcessing = false
                self.scannedData = parsed
                if !parsed.hasData {
                    self.errorMessage = "No charging metrics could be detected in this photo. You can enter values manually."
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

private struct ResultRow: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

/// Intelligent regular expression parser for charging dispenser screens and receipts.
enum ReceiptParser {
    static func parse(text: String) -> ScannedChargingData {
        var data = ScannedChargingData()
        data.rawDetectedText = text

        let cleanText = text.replacingOccurrences(of: "\r", with: "\n")
        let lines = cleanText.components(separatedBy: "\n")

        // 1. Energy Added (kWh)
        // e.g. "45.20 kWh", "Energy: 32.5 kWh", "45.2 หน่วย"
        let energyPatterns = [
            #"(?:Energy|Charged|Total Energy|Delivered|พลังงาน)\s*:?\s*(\d+[\.,]\d+)\s*(?:kWh|KWH|kwh|หน่วย)"#,
            #"(\d+[\.,]\d{1,3})\s*(?:kWh|KWH|kwh|หน่วย)"#
        ]
        data.energyAdded = extractFirstMatch(from: cleanText, patterns: energyPatterns)

        // 2. Total Cost
        // Prioritize explicit Total / Amount keywords and exclude rate lines like "/kWh"
        let explicitTotalPatterns = [
            #"(?:Total\s*Amount|Grand\s*Total|Total\s*Price|Total\s*Cost|Total|ยอดรวม|ชำระ|รวมทั้งสิ้น|Net\s*Amount)\s*:?\s*[฿$€£]?\s*(\d+[\.,]\d{2})\s*(?:THB|USD|EUR|GBP|Baht|บาท)?"#,
            #"(?:Total|ยอดรวม|รวมทั้งสิ้น)\s*:?\s*[฿$€£]\s*(\d+[\.,]\d{2})"#,
            #"[฿$€£]\s*(\d+[\.,]\d{2})(?!\s*\/\s*(?:kWh|hr|min|unit))"#,
            #"(\d+[\.,]\d{2})\s*(?:THB|USD|EUR|GBP|Baht|บาท)(?!\s*\/\s*(?:kWh|hr|min|unit))"#
        ]
        data.totalPrice = extractFirstMatch(from: cleanText, patterns: explicitTotalPatterns)

        // 3. Duration in Minutes
        // e.g. "00:45:00", "Duration: 45 min", "Time: 00:45:00"
        let explicitDurationPatterns = [
            #"(?:Duration|Time|เวลา|Elapsed)\s*:?\s*(\d{1,2}):(\d{2}):(\d{2})"#,
            #"(?:Duration|Time|เวลา|Elapsed)\s*:?\s*(\d{1,3})\s*(?:min|mins|นาที|m\b)"#,
            #"\b(\d{1,2}):(\d{2}):(\d{2})\b"#
        ]
        for pattern in explicitDurationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = cleanText as NSString
                if let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    if match.numberOfRanges == 4 {
                        // HH:MM:SS format
                        let hStr = nsString.substring(with: match.range(at: 1))
                        let mStr = nsString.substring(with: match.range(at: 2))
                        let hours = Double(hStr) ?? 0
                        let mins = Double(mStr) ?? 0
                        data.durationMinutes = (hours * 60) + mins
                        break
                    } else if match.numberOfRanges >= 2 {
                        let mStr = nsString.substring(with: match.range(at: 1))
                        if let mins = Double(mStr), mins > 0 {
                            data.durationMinutes = mins
                            break
                        }
                    }
                }
            }
        }

        // 4. SoC Percentages
        // e.g. "20% -> 80%", "SoC: 30% - 90%", "Start: 25% End: 80%"
        let socDeltaPattern = #"(\d{1,3})%\s*(?:->|→|to|-|~)\s*(\d{1,3})%"#
        if let regex = try? NSRegularExpression(pattern: socDeltaPattern, options: .caseInsensitive) {
            let nsString = cleanText as NSString
            if let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length)), match.numberOfRanges == 3 {
                let startStr = nsString.substring(with: match.range(at: 1))
                let endStr = nsString.substring(with: match.range(at: 2))
                data.startPercentage = Double(startStr)
                data.endPercentage = Double(endStr)
            }
        }

        // 5. Charging Speed (kW)
        let speedPattern = #"(?:Max Speed|Speed|Power|กำลังไฟ)?\s*:?\s*(\d+[\.,]?\d*)\s*(?:kW|KW|kw)\b(?!\s*h)"#
        if let regex = try? NSRegularExpression(pattern: speedPattern, options: .caseInsensitive) {
            let nsString = cleanText as NSString
            if let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length)), match.numberOfRanges >= 2 {
                let spdStr = nsString.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                if let spd = Double(spdStr), spd > 0 && spd < 400 {
                    data.speedKW = spd
                }
            }
        }

        // 6. Known Vendors & Networks
        let knownVendors = ["PEA VOLTA", "EA Anywhere", "EVme", "Tesla Supercharger", "Evolt", "On-ion", "ChargePoint", "Electrify America", "EVgo", "Shell Recharge", "Ionity", "Fastned"]
        for vendor in knownVendors {
            if cleanText.localizedCaseInsensitiveContains(vendor) {
                data.locationOrVendor = vendor
                break
            }
        }

        return data
    }

    private static func extractFirstMatch(from text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges >= 2 {
                    var numStr = nsString.substring(with: match.range(at: 1))
                    numStr = numStr.replacingOccurrences(of: ",", with: ".")
                    if let val = Double(numStr), val > 0 {
                        return val
                    }
                }
            }
        }
        return nil
    }
}
