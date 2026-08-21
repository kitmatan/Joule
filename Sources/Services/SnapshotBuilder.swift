import Foundation

/// Turns the app's live session data into the flat `JouleSnapshot` the extensions consume.
enum SnapshotBuilder {
    /// How many sessions the watch list shows. The watch is a glance surface — anything longer
    /// belongs in the phone's History tab, and every extra row inflates the `WCSession` payload.
    static let recentSessionLimit = 12

    /// Months of cost history kept for the widget sparkline.
    static let monthlyHistoryLimit = 6

    static func build(
        sessions: [ChargingSession],
        vehicle: Vehicle,
        vehicleCount: Int,
        currency: AppCurrency,
        unitSystem: UnitSystem,
        referenceDate: Date = Date()
    ) -> JouleSnapshot {
        let stats = ChargingStatistics(
            sessions: sessions,
            vehicle: vehicle,
            currency: currency,
            unitSystem: unitSystem,
            referenceDate: referenceDate
        )

        let health = BatteryHealthService(vehicle: vehicle).calculateSummary(from: sessions)
        let sortedByDateDescending = sessions.sorted { $0.date > $1.date }

        return JouleSnapshot(
            generatedAt: referenceDate,
            vehicleName: vehicle.name,
            vehicleCount: vehicleCount,
            chemistry: vehicle.chemistry.rawValue,
            nominalCapacityKWh: vehicle.nominalCapacityKWh,
            currencyCode: currency.code,
            unitSystemRaw: unitSystem.rawValue,
            monthCost: stats.currentMonthCost,
            monthEnergy: stats.currentMonthEnergy,
            monthSessionCount: stats.currentMonthSessions.count,
            monthSavings: stats.currentMonthGasSavings.netSavings,
            totalCost: stats.totalCost,
            totalEnergy: stats.totalEnergy,
            totalSessionCount: stats.totalSessions,
            lifetimeSavings: stats.lifetimeGasSavings.netSavings,
            averagePricePerKWh: stats.averagePricePerKWh,
            efficiencyKmPerKWh: stats.energyEfficiency,
            costPerDistance: stats.costPerDistance,
            hasDrivingData: stats.hasDrivingData,
            batteryHealth: health.map(healthSnapshot),
            lastSession: sortedByDateDescending.first.map(sessionSnapshot),
            recentSessions: sortedByDateDescending.prefix(recentSessionLimit).map(sessionSnapshot),
            monthlyCosts: monthlyCosts(from: sessions, referenceDate: referenceDate)
        )
    }

    // MARK: - Mapping

    private static func healthSnapshot(_ summary: BatteryHealthSummary) -> JouleSnapshot.BatteryHealthSnapshot {
        JouleSnapshot.BatteryHealthSnapshot(
            stateOfHealth: summary.currentSoH,
            capacityKWh: summary.currentCapacityKWh,
            assessmentTitle: summary.assessment.title,
            projectedRangeKm: summary.currentProjectedRangeKm,
            equivalentFullCycles: summary.equivalentFullCycles,
            isCalibrated: summary.degradationPer10kKm != nil || summary.degradationPerYear != nil
        )
    }

    private static func sessionSnapshot(_ session: ChargingSession) -> JouleSnapshot.SessionSnapshot {
        // A session that reached the snapshot without an ID came from local-only storage before it
        // was persisted. Deriving a stable key from the timestamp keeps SwiftUI's list diffing
        // steady across refreshes, where a fresh UUID each build would animate rows for no reason.
        let identifier = session.id ?? "local-\(session.date.timeIntervalSince1970)"

        return JouleSnapshot.SessionSnapshot(
            id: identifier,
            date: session.date,
            locationName: session.locationName,
            energyAdded: session.energyAdded,
            totalPrice: session.totalPrice,
            endPercentage: session.endPercentage,
            isDC: resolvedIsDC(session)
        )
    }

    /// Mirrors `BatteryHealthService.efficiency(for:)`: an untyped session is treated as AC when it
    /// happened at home or drew a wallbox-plausible rate.
    private static func resolvedIsDC(_ session: ChargingSession) -> Bool {
        if let type = session.chargingType { return type == .dc }
        if session.locationType == .home || (session.speed > 0 && session.speed <= 11.5) { return false }
        return true
    }

    private static func monthlyCosts(from sessions: [ChargingSession], referenceDate: Date) -> [JouleSnapshot.MonthlyCostSnapshot] {
        let calendar = Calendar.current
        let thisMonth = calendar.startOfMonth(for: referenceDate)
        guard let cutoff = calendar.date(byAdding: .month, value: -(monthlyHistoryLimit - 1), to: thisMonth) else {
            return []
        }

        // Seed every month in range so a month with no charging renders as a gap in the sparkline
        // rather than silently collapsing the axis.
        var byMonth: [Date: JouleSnapshot.MonthlyCostSnapshot] = [:]
        for offset in 0..<monthlyHistoryLimit {
            guard let month = calendar.date(byAdding: .month, value: offset, to: cutoff) else { continue }
            byMonth[month] = JouleSnapshot.MonthlyCostSnapshot(month: month, cost: 0, energy: 0)
        }

        for session in sessions where session.date >= cutoff {
            let month = calendar.startOfMonth(for: session.date)
            guard var stat = byMonth[month] else { continue }
            stat.cost += session.totalPrice
            stat.energy += session.energyAdded
            byMonth[month] = stat
        }

        return byMonth.values.sorted { $0.month < $1.month }
    }
}
