import Foundation

/// Service responsible for calculating battery degradation, State of Health (SoH),
/// confidence-weighted trends, and lifecycle analytics from charging sessions.
struct BatteryHealthService {
    var nominalCapacityKWh: Double
    var nominalRangeKm: Double
    var acEfficiency: Double
    var dcEfficiency: Double
    
    init(
        nominalCapacityKWh: Double = BatteryConstants.defaultNominalCapacityKWh,
        nominalRangeKm: Double = BatteryConstants.defaultNominalRangeKm,
        acEfficiency: Double = BatteryConstants.defaultACEfficiency,
        dcEfficiency: Double = BatteryConstants.defaultDCEfficiency
    ) {
        self.nominalCapacityKWh = nominalCapacityKWh
        self.nominalRangeKm = nominalRangeKm
        self.acEfficiency = acEfficiency
        self.dcEfficiency = dcEfficiency
    }
    
    /// Resolves charging efficiency for a session based on type, location, and speed.
    func efficiency(for session: ChargingSession) -> Double {
        if let type = session.chargingType {
            return type == .ac ? acEfficiency : dcEfficiency
        }
        if session.locationType == .home || (session.speed > 0 && session.speed <= 11.5) {
            return acEfficiency
        }
        return dcEfficiency
    }
    
    /// Evaluates capacity and health for a single charging session.
    func evaluateSession(_ session: ChargingSession) -> BatteryHealthDataPoint? {
        guard let start = session.startPercentage,
              let end = session.endPercentage,
              end > start,
              session.energyAdded > 0 else {
            return nil
        }
        
        let delta = end - start
        guard delta >= 5.0 else { return nil } // Ignore tiny variations below 5%
        
        let eff = efficiency(for: session)
        let batteryEnergy = session.energyAdded * eff
        let estimatedCapacity = batteryEnergy / (delta / 100.0)
        
        // Filter out extreme typos/anomalies outside realistic physics limits (40% to 160% of nominal pack size)
        guard estimatedCapacity >= nominalCapacityKWh * 0.4 && estimatedCapacity <= nominalCapacityKWh * 1.6 else {
            return nil
        }
        
        let soh = (estimatedCapacity / nominalCapacityKWh) * 100.0
        let confidence = BatteryHealthConfidence.evaluate(socDelta: delta)
        
        var projectedRange: Double? = nil
        if let endR = session.endRange, end > 0 {
            projectedRange = endR / (end / 100.0)
        } else if let startR = session.startRange, start > 0 {
            projectedRange = startR / (start / 100.0)
        }
        
        return BatteryHealthDataPoint(
            id: session.id ?? UUID().uuidString,
            sessionID: session.id,
            date: session.date,
            mileage: session.mileage,
            startSoC: start,
            endSoC: end,
            socDelta: delta,
            energyAdded: session.energyAdded,
            chargingType: session.chargingType ?? (eff == acEfficiency ? .ac : .dc),
            estimatedCapacityKWh: estimatedCapacity,
            stateOfHealth: soh,
            confidence: confidence,
            projectedFullRangeKm: projectedRange
        )
    }
    
    /// Computes all historical data points from stored charging sessions.
    func calculateDataPoints(from sessions: [ChargingSession]) -> [BatteryHealthDataPoint] {
        sessions
            .compactMap { evaluateSession($0) }
            .sorted { $0.date < $1.date }
    }
    
    /// Generates a smoothed longitudinal trend using confidence-weighted Gaussian moving averages.
    func calculateTrend(from points: [BatteryHealthDataPoint]) -> [BatteryHealthTrendPoint] {
        let reliablePoints = points.filter { $0.confidence != .unreliable }
        guard !reliablePoints.isEmpty else { return [] }
        
        if reliablePoints.count <= 2 {
            return reliablePoints.map {
                BatteryHealthTrendPoint(
                    date: $0.date,
                    mileage: $0.mileage,
                    smoothedSoH: $0.stateOfHealth,
                    smoothedCapacityKWh: $0.estimatedCapacityKWh,
                    projectedFullRangeKm: $0.projectedFullRangeKm
                )
            }
        }
        
        let totalSpanDays = max(30.0, (reliablePoints.last!.date.timeIntervalSince(reliablePoints.first!.date)) / 86400.0)
        let sigma = max(15.0, min(60.0, totalSpanDays / 6.0))
        
        var trendPoints: [BatteryHealthTrendPoint] = []
        
        for (_, current) in reliablePoints.enumerated() {
            var weightedSoHSum = 0.0
            var weightedCapSum = 0.0
            var weightedRangeSum = 0.0
            var rangeWeightSum = 0.0
            var totalWeight = 0.0
            
            // Window around the point for local regression smoothing
            for j in 0..<reliablePoints.count {
                let neighbor = reliablePoints[j]
                let dayDiff = abs(neighbor.date.timeIntervalSince(current.date)) / 86400.0
                
                // Adaptive Gaussian time kernel with confidence weighting
                let timeKernel = exp(-pow(dayDiff / sigma, 2) / 2.0)
                let weight = neighbor.confidence.weight * timeKernel
                
                guard weight > 0.001 else { continue }
                
                weightedSoHSum += neighbor.stateOfHealth * weight
                weightedCapSum += neighbor.estimatedCapacityKWh * weight
                totalWeight += weight
                
                if let range = neighbor.projectedFullRangeKm {
                    weightedRangeSum += range * weight
                    rangeWeightSum += weight
                }
            }
            
            let smoothedSoH = totalWeight > 0 ? (weightedSoHSum / totalWeight) : current.stateOfHealth
            let smoothedCap = totalWeight > 0 ? (weightedCapSum / totalWeight) : current.estimatedCapacityKWh
            let smoothedRange = rangeWeightSum > 0 ? (weightedRangeSum / rangeWeightSum) : current.projectedFullRangeKm
            
            trendPoints.append(BatteryHealthTrendPoint(
                date: current.date,
                mileage: current.mileage,
                smoothedSoH: min(100.0, max(50.0, smoothedSoH)),
                smoothedCapacityKWh: min(nominalCapacityKWh, max(nominalCapacityKWh * 0.4, smoothedCap)),
                projectedFullRangeKm: smoothedRange
            ))
        }
        
        return trendPoints
    }
    
    /// Computes full summary diagnostics and degradation rates.
    func calculateSummary(from sessions: [ChargingSession]) -> BatteryHealthSummary? {
        let points = calculateDataPoints(from: sessions)
        guard !points.isEmpty else { return nil }
        
        let trend = calculateTrend(from: points)
        
        // Current SoH and capacity are derived from the latest smoothed trend or last reliable points
        let currentSoH: Double
        let currentCapacity: Double
        let currentProjectedRange: Double?
        
        if let latestTrend = trend.last {
            currentSoH = latestTrend.smoothedSoH
            currentCapacity = latestTrend.smoothedCapacityKWh
            currentProjectedRange = latestTrend.projectedFullRangeKm
        } else {
            // Weighted average of top 3 latest points
            let recent = Array(points.filter { $0.confidence >= .medium }.suffix(3))
            if !recent.isEmpty {
                let wSum = recent.reduce(0.0) { $0 + $1.stateOfHealth * $1.confidence.weight }
                let tW = recent.reduce(0.0) { $0 + $1.confidence.weight }
                currentSoH = tW > 0 ? (wSum / tW) : recent.last!.stateOfHealth
                currentCapacity = (currentSoH / 100.0) * nominalCapacityKWh
                currentProjectedRange = recent.compactMap(\.projectedFullRangeKm).last
            } else {
                currentSoH = points.last!.stateOfHealth
                currentCapacity = points.last!.estimatedCapacityKWh
                currentProjectedRange = points.last!.projectedFullRangeKm
            }
        }
        
        let capacityLost = max(0, nominalCapacityKWh - currentCapacity)
        let totalDegradation = max(0, 100.0 - currentSoH)
        
        // Throughput and Equivalent Full Cycles (EFC)
        var totalThroughput = 0.0
        var acEnergy = 0.0
        var dcEnergy = 0.0
        
        for s in sessions {
            let eff = efficiency(for: s)
            let batteryKWh = s.energyAdded * eff
            totalThroughput += batteryKWh
            if s.chargingType == .ac || (s.chargingType == nil && eff == acEfficiency) {
                acEnergy += s.energyAdded
            } else {
                dcEnergy += s.energyAdded
            }
        }
        
        let totalEnergy = acEnergy + dcEnergy
        let acRatio = totalEnergy > 0 ? (acEnergy / totalEnergy) : 0.5
        let dcRatio = totalEnergy > 0 ? (dcEnergy / totalEnergy) : 0.5
        let efc = nominalCapacityKWh > 0 ? (totalThroughput / nominalCapacityKWh) : 0
        
        // Degradation rate vs Mileage using robust confidence-weighted least-squares linear regression
        var degradationPer10kKm: Double? = nil
        let mileagePoints = points.filter { $0.mileage != nil && $0.confidence >= .medium }
        if mileagePoints.count >= 4 {
            let mileages = mileagePoints.compactMap(\.mileage)
            let minM = mileages.min() ?? 0
            let maxM = mileages.max() ?? 0
            
            // Require at least 2,500 km of driving baseline to avoid multiplying short-term noise
            if maxM - minM >= 2500.0 {
                let totalWeight = mileagePoints.reduce(0.0) { $0 + $1.confidence.weight }
                let weightedMeanM = mileagePoints.reduce(0.0) { $0 + $1.mileage! * $1.confidence.weight } / totalWeight
                let weightedMeanSoH = mileagePoints.reduce(0.0) { $0 + min(100.0, $1.stateOfHealth) * $1.confidence.weight } / totalWeight
                
                var numerator = 0.0
                var denominator = 0.0
                for p in mileagePoints {
                    let w = p.confidence.weight
                    let diffM = p.mileage! - weightedMeanM
                    let diffSoH = min(100.0, p.stateOfHealth) - weightedMeanSoH
                    numerator += w * diffM * diffSoH
                    denominator += w * diffM * diffM
                }
                
                if denominator > 0 {
                    let slope = numerator / denominator // % SoH per km
                    if slope < 0 {
                        // Bounded to physically plausible EV degradation limits (max 3.5% / 10k km)
                        let rawRate = -slope * 10000.0
                        degradationPer10kKm = min(3.5, rawRate)
                    } else {
                        degradationPer10kKm = 0.0
                    }
                }
            }
        }
        
        // Degradation rate vs Time using confidence-weighted linear regression across observed timeline
        var degradationPerYear: Double? = nil
        let reliablePoints = points.filter { $0.confidence >= .medium }
        if reliablePoints.count >= 4,
           let firstDate = reliablePoints.first?.date,
           let lastDate = reliablePoints.last?.date {
            let days = lastDate.timeIntervalSince(firstDate) / 86400.0
            
            // Require at least 60 days of historical baseline to calculate an annual degradation rate
            if days >= 60.0 {
                let refDate = firstDate
                let times = reliablePoints.map { $0.date.timeIntervalSince(refDate) / (86400.0 * 365.25) }
                let totalWeight = reliablePoints.reduce(0.0) { $0 + $1.confidence.weight }
                let weightedMeanT = zip(times, reliablePoints).reduce(0.0) { $0 + $1.0 * $1.1.confidence.weight } / totalWeight
                let weightedMeanSoH = reliablePoints.reduce(0.0) { $0 + min(100.0, $1.stateOfHealth) * $1.confidence.weight } / totalWeight
                
                var numerator = 0.0
                var denominator = 0.0
                for i in 0..<reliablePoints.count {
                    let w = reliablePoints[i].confidence.weight
                    let diffT = times[i] - weightedMeanT
                    let diffSoH = min(100.0, reliablePoints[i].stateOfHealth) - weightedMeanSoH
                    numerator += w * diffT * diffSoH
                    denominator += w * diffT * diffT
                }
                
                if denominator > 0 {
                    let slope = numerator / denominator // % SoH change per year
                    if slope < 0 {
                        // Bounded to physically plausible EV degradation limits (max 5.0% / yr)
                        let rawRate = -slope
                        degradationPerYear = min(5.0, rawRate)
                    } else {
                        degradationPerYear = 0.0
                    }
                }
            }
        }
        
        let rangeLost = currentProjectedRange.map { max(0, nominalRangeKm - $0) }
        
        // Assessment rating
        let assessment: BatteryHealthSummary.BatteryAssessment
        if currentSoH >= 95.0 {
            assessment = .excellent
        } else if currentSoH >= 90.0 {
            assessment = .good
        } else if currentSoH >= 82.0 {
            assessment = .normal
        } else {
            assessment = .degraded
        }
        
        return BatteryHealthSummary(
            currentSoH: currentSoH,
            currentCapacityKWh: currentCapacity,
            nominalCapacityKWh: nominalCapacityKWh,
            capacityLostKWh: capacityLost,
            totalDegradationPercentage: totalDegradation,
            degradationPer10kKm: degradationPer10kKm,
            degradationPerYear: degradationPerYear,
            totalThroughputKWh: totalThroughput,
            equivalentFullCycles: efc,
            currentProjectedRangeKm: currentProjectedRange,
            nominalRangeKm: nominalRangeKm,
            rangeLostKm: rangeLost,
            totalSamplesCount: points.count,
            reliableSamplesCount: points.filter { $0.confidence >= .medium }.count,
            acEnergyRatio: acRatio,
            dcEnergyRatio: dcRatio,
            assessment: assessment
        )
    }
}
