import Foundation

/// The aggregate figures Joule reports for a set of charging sessions.
///
/// These used to live as computed properties on `DashboardView`, which was fine while the
/// dashboard was the only thing displaying them. The widgets and the watch app need the same
/// numbers, and a second implementation of "what did I spend this month" is a defect waiting to
/// happen — the two would drift the first time a rule changed. `DashboardView` and
/// `SnapshotBuilder` both read from here instead.
struct ChargingStatistics {
    /// Sessions for the vehicle in scope, in any order.
    let sessions: [ChargingSession]
    let vehicle: Vehicle
    let currency: AppCurrency
    let unitSystem: UnitSystem
    /// Injected so the month boundary is testable rather than pinned to the wall clock.
    let referenceDate: Date

    init(
        sessions: [ChargingSession],
        vehicle: Vehicle,
        currency: AppCurrency,
        unitSystem: UnitSystem,
        referenceDate: Date = Date()
    ) {
        self.sessions = sessions
        self.vehicle = vehicle
        self.currency = currency
        self.unitSystem = unitSystem
        self.referenceDate = referenceDate
    }

    // MARK: - Totals

    var totalSessions: Int { sessions.count }

    var totalCost: Double {
        sessions.reduce(0) { $0 + $1.totalPrice }
    }

    var totalEnergy: Double {
        sessions.reduce(0) { $0 + $1.energyAdded }
    }

    // MARK: - Driving window

    /// Odometer span, together with the energy and cost that actually powered it.
    ///
    /// Only sessions falling *between* the first and last odometer reading are counted: the
    /// charge that ends the window topped the car up after the final reading, so its energy
    /// hasn't been driven yet and would understate efficiency.
    var drivingWindow: (distance: Double, energy: Double, cost: Double)? {
        let logged = sessions
            .filter { $0.mileage != nil }
            .sorted { $0.date < $1.date }

        guard let firstLogged = logged.first, let lastLogged = logged.last else { return nil }

        let odometers = logged.compactMap(\.mileage)
        guard let startOdo = odometers.min(), let endOdo = odometers.max(), endOdo > startOdo else { return nil }

        let powering = sessions.filter { $0.date >= firstLogged.date && $0.date < lastLogged.date }
        return (
            distance: endOdo - startOdo,
            energy: powering.reduce(0) { $0 + $1.energyAdded },
            cost: powering.reduce(0) { $0 + $1.totalPrice }
        )
    }

    var hasDrivingData: Bool { drivingWindow != nil }

    var totalDistance: Double { drivingWindow?.distance ?? 0 }

    // MARK: - Current month

    var uniqueMonthsCount: Int {
        let uniqueMonths = Set(sessions.map {
            Calendar.current.dateComponents([.year, .month], from: $0.date)
        })
        return max(1, uniqueMonths.count)
    }

    var currentMonthSessions: [ChargingSession] {
        sessions.filter {
            Calendar.current.isDate($0.date, equalTo: referenceDate, toGranularity: .month)
        }
    }

    var currentMonthCost: Double {
        currentMonthSessions.reduce(0) { $0 + $1.totalPrice }
    }

    var currentMonthEnergy: Double {
        currentMonthSessions.reduce(0) { $0 + $1.energyAdded }
    }

    var currentMonthDeferredCost: Double {
        currentMonthSessions
            .filter { $0.paymentStatus == .deferred }
            .reduce(0) { $0 + $1.totalPrice }
    }

    // MARK: - Averages

    var averagePricePerKWh: Double {
        totalEnergy > 0 ? totalCost / totalEnergy : 0
    }

    /// Driving efficiency in km/kWh (metric base regardless of the display unit).
    var energyEfficiency: Double {
        guard let window = drivingWindow, window.energy > 0 else { return 0 }
        return window.distance / window.energy
    }

    /// Cost per distance unit, expressed in the active unit system.
    var costPerDistance: Double {
        guard let window = drivingWindow, window.distance > 0 else { return 0 }
        let convertedDist = unitSystem.convertFromKm(window.distance)
        guard convertedDist > 0 else { return 0 }
        return window.cost / convertedDist
    }

    // MARK: - Gas comparison

    var lifetimeGasSavings: GasSavingsSummary {
        if hasDrivingData {
            return GasComparisonSettings.calculateSavings(
                distanceKm: totalDistance,
                evCost: drivingWindow?.cost ?? totalCost,
                currency: currency,
                unitSystem: unitSystem
            )
        }
        return GasComparisonSettings.calculateSavings(
            energyKWh: totalEnergy,
            evCost: totalCost,
            ratedEfficiencyKmPerKWh: vehicle.ratedEfficiencyKmPerKWh,
            currency: currency,
            unitSystem: unitSystem
        )
    }

    var currentMonthGasSavings: GasSavingsSummary {
        let eff = energyEfficiency > 0 ? energyEfficiency : vehicle.ratedEfficiencyKmPerKWh
        return GasComparisonSettings.calculateSavings(
            energyKWh: currentMonthEnergy,
            evCost: currentMonthCost,
            ratedEfficiencyKmPerKWh: eff,
            currency: currency,
            unitSystem: unitSystem
        )
    }

    // MARK: - Smart Charging & TOU Off-Peak Savings

    struct SmartChargingSavings {
        let homeEnergyKWh: Double
        let actualHomeCost: Double
        let peakEquivalentCost: Double
        let savingsAmount: Double
        let savingsPercentage: Double
        let tariffName: String
        let hasSavings: Bool
    }

    var currentMonthSmartChargingSavings: SmartChargingSavings {
        let homeSessions = currentMonthSessions.filter {
            $0.locationType == .home || ($0.locationName?.localizedCaseInsensitiveContains("home") == true)
        }
        let homeEnergy = homeSessions.reduce(0) { $0 + $1.energyAdded }
        let homeCost = homeSessions.reduce(0) { $0 + $1.totalPrice }

        let peakRate: Double
        switch vehicle.tariffType.region {
        case .thailand:
            peakRate = HomeTariffType.peaTouPeak.defaultRate
        case .unitedStates:
            peakRate = HomeTariffType.usTouPeak.defaultRate
        case .europeUK:
            peakRate = vehicle.tariffType == .ukAgileOffPeak || vehicle.tariffType == .ukStandardFlat
                ? HomeTariffType.ukStandardFlat.defaultRate
                : HomeTariffType.euStandardFlat.defaultRate
        case .custom:
            peakRate = vehicle.effectiveHomeTariff * 1.5
        }

        let peakEquivalent = homeEnergy * peakRate
        let savings = max(0, peakEquivalent - homeCost)
        let savingsPct = peakEquivalent > 0 ? (savings / peakEquivalent) * 100.0 : 0.0

        return SmartChargingSavings(
            homeEnergyKWh: homeEnergy,
            actualHomeCost: homeCost,
            peakEquivalentCost: peakEquivalent,
            savingsAmount: savings,
            savingsPercentage: savingsPct,
            tariffName: vehicle.tariffType.rawValue,
            hasSavings: savings > 1.0 && homeEnergy > 0
        )
    }
}
