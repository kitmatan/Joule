import SwiftUI

/// A formatted, exportable Battery Health Certificate for vehicle resale, insurance, and maintenance auditing.
struct BatteryHealthCertificateView: View {
    let vehicle: Vehicle
    let summary: BatteryHealthSummary
    let behavior: ChargingBehaviorAnalysis?
    let unitSystem: UnitSystem
    let currency: AppCurrency
    let totalSessions: Int

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var isExporting = false

    private var certificateDate: String {
        Date().formatted(.dateTime.year().month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    certificateCard
                        .padding()

                    // Action buttons
                    HStack(spacing: 16) {
                        ShareLink(
                            item: renderCertificateImage(),
                            preview: SharePreview("Joule Battery Health Certificate - \(vehicle.name)", image: renderCertificateImage())
                        ) {
                            Label("Share Certificate", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Battery Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var certificateCard: some View {
        VStack(spacing: 20) {
            // Certificate Header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("JOULE BATTERY HEALTH CERTIFICATE")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .tracking(1.5)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("VERIFIED")
                        .font(.caption2).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                Divider()
            }

            // Vehicle Title
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(vehicle.chemistry.fullName))
                            .font(.subheadline)
                            .foregroundColor(.blue)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(String(format: String(localized: "Nominal: %.1f kWh"), vehicle.nominalCapacityKWh))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let plate = vehicle.licensePlate, !plate.isEmpty {
                        Text(String(format: String(localized: "Plate / VIN: %@"), plate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Big SoH Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", summary.currentSoH))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(summary.currentSoH >= 90 ? .green : (summary.currentSoH >= 80 ? .orange : .red))

                    Text("State of Health")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            // Metrics Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CertStatBox(
                        title: "Usable Capacity",
                        value: String(format: "%.1f kWh", summary.currentCapacityKWh),
                        subtext: String(format: "%.1f kWh nominal", summary.nominalCapacityKWh),
                        icon: "bolt.batteryblock.fill",
                        color: .blue
                    )

                    CertStatBox(
                        title: "Full Cycles",
                        value: String(format: "%.1f", summary.equivalentFullCycles),
                        subtext: "Equivalent 100% cycles",
                        icon: "arrow.triangle.2.circlepath",
                        color: .indigo
                    )
                }

                HStack(spacing: 12) {
                    CertStatBox(
                        title: "Degradation Rate",
                        value: summary.formattedDegradationRate(unit: unitSystem),
                        subtext: summary.degradationPerYear.map { String(format: "-%.2f%% / year", $0) } ?? "Regression model",
                        icon: "chart.line.downtrend.xyaxis",
                        color: .orange
                    )

                    CertStatBox(
                        title: "Fast Charge Ratio",
                        value: String(format: "%.0f%% AC / %.0f%% DC", summary.acEnergyRatio * 100, summary.dcEnergyRatio * 100),
                        subtext: String(format: String(localized: "%lld charging sessions"), Int64(summary.totalSamplesCount)),
                        icon: "powerplug.fill",
                        color: .purple
                    )
                }
            }

            // Longevity Rating & Behavior Grade
            if let behavior = behavior {
                HStack(spacing: 14) {
                    Text(behavior.grade.rawValue)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .frame(width: 44, height: 44)
                        .background(behavior.grade.color.opacity(0.15))
                        .foregroundColor(behavior.grade.color)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: String(localized: "Battery Care Grade: %@"), behavior.assessment.rawValue))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Calculated from depth of discharge, charging speeds, and target SoC consistency.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
            }

            // Footer Stamp
            VStack(spacing: 6) {
                Divider()
                HStack {
                    Text(String(format: String(localized: "Generated on %@"), certificateDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Joule EV Battery Analytics")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    @MainActor
    private func renderCertificateImage() -> Image {
        let renderer = ImageRenderer(content: certificateCard.frame(width: 400).padding(10))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "bolt.shield")
    }
}

private struct CertStatBox: View {
    let title: LocalizedStringKey
    let value: String
    let subtext: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(LocalizedStringKey(subtext))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
    }
}
