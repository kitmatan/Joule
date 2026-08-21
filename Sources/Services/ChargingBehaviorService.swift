import Foundation

/// Service responsible for analyzing vehicle charging patterns, evaluating their impact on
/// battery longevity across chemistries (LFP vs. NMC/NCA), and generating actionable recommendations.
struct ChargingBehaviorService {

    /// Analyzes the provided charging sessions for a specific vehicle.
    static func analyze(
        sessions: [ChargingSession],
        vehicle: Vehicle,
        referenceDate: Date = Date()
    ) -> ChargingBehaviorAnalysis {
        let metrics = computeMetrics(from: sessions, vehicle: vehicle, referenceDate: referenceDate)
        
        let speedScore = computeSpeedScore(metrics: metrics)
        let targetSoCScore = computeTargetSoCScore(metrics: metrics, chemistry: vehicle.chemistry)
        let dischargeBufferScore = computeDischargeBufferScore(metrics: metrics)
        let cycleConsistencyScore = computeCycleConsistencyScore(metrics: metrics)
        
        // Weight the dimensions based on electrochemical degradation significance
        let overallScore: Double
        if metrics.totalSessions == 0 {
            overallScore = 100.0 // Default baseline for brand-new profile
        } else {
            overallScore = (speedScore * 0.30) +
                           (targetSoCScore * 0.35) +
                           (dischargeBufferScore * 0.20) +
                           (cycleConsistencyScore * 0.15)
        }
        
        let grade = ChargingBehaviorGrade.grade(for: overallScore)
        let assessment = determineAssessment(score: overallScore, grade: grade)
        let recommendations = generateRecommendations(metrics: metrics, vehicle: vehicle, referenceDate: referenceDate)
        let summaryText = generateSummaryText(
            score: overallScore,
            grade: grade,
            metrics: metrics,
            vehicle: vehicle,
            recommendations: recommendations
        )
        
        return ChargingBehaviorAnalysis(
            vehicleId: vehicle.id,
            vehicleName: vehicle.name,
            chemistry: vehicle.chemistry,
            overallScore: overallScore,
            grade: grade,
            assessment: assessment,
            summaryText: summaryText,
            speedBalanceScore: speedScore,
            targetSoCScore: targetSoCScore,
            dischargeBufferScore: dischargeBufferScore,
            cycleConsistencyScore: cycleConsistencyScore,
            metrics: metrics,
            recommendations: recommendations
        )
    }

    // MARK: - Metrics Computation

    private static func computeMetrics(
        from sessions: [ChargingSession],
        vehicle: Vehicle,
        referenceDate: Date
    ) -> ChargingHabitMetrics {
        guard !sessions.isEmpty else {
            return ChargingHabitMetrics(
                totalSessions: 0,
                acSessionsCount: 0,
                dcSessionsCount: 0,
                acEnergyKWh: 0,
                dcEnergyKWh: 0,
                acEnergyRatio: 1.0,
                dcEnergyRatio: 0.0,
                sessionsWithPercentagesCount: 0,
                averageStartSoC: nil,
                averageEndSoC: nil,
                averageDeltaSoC: nil,
                sessionsEndingAt100Count: 0,
                sessionsEndingAt100Percentage: 0,
                sessionsEndingAbove85Count: 0,
                sessionsEndingAbove85Percentage: 0,
                sessionsStartingBelow15Count: 0,
                sessionsStartingBelow15Percentage: 0,
                sessionsStartingBelow10Count: 0,
                sessionsStartingBelow10Percentage: 0,
                daysSinceLastFullCharge: nil,
                lastFullChargeDate: nil
            )
        }

        var acSessions = 0
        var dcSessions = 0
        var acEnergy = 0.0
        var dcEnergy = 0.0

        var validPctSessions: [ChargingSession] = []
        var endAt100Count = 0
        var endAbove85Count = 0
        var startBelow15Count = 0
        var startBelow10Count = 0
        var lastFullChargeDate: Date? = nil

        for s in sessions.sorted(by: { $0.date < $1.date }) {
            let isAC: Bool
            if let type = s.chargingType {
                isAC = (type == .ac)
            } else if s.locationType == .home || (s.speed > 0 && s.speed <= 11.5) {
                isAC = true
            } else {
                isAC = false
            }

            if isAC {
                acSessions += 1
                acEnergy += s.energyAdded
            } else {
                dcSessions += 1
                dcEnergy += s.energyAdded
            }

            if let start = s.startPercentage, let end = s.endPercentage, end > start {
                validPctSessions.append(s)

                if end >= 98.0 {
                    endAt100Count += 1
                    lastFullChargeDate = s.date
                }
                if end > 85.0 {
                    endAbove85Count += 1
                }
                if start < 15.0 {
                    startBelow15Count += 1
                }
                if start < 10.0 {
                    startBelow10Count += 1
                }
            }
        }

        let totalEnergy = acEnergy + dcEnergy
        let acRatio = totalEnergy > 0 ? (acEnergy / totalEnergy) : (sessions.count > 0 ? Double(acSessions) / Double(sessions.count) : 1.0)
        let dcRatio = totalEnergy > 0 ? (dcEnergy / totalEnergy) : (1.0 - acRatio)

        let validCount = validPctSessions.count
        let avgStart: Double? = validCount > 0 ? (validPctSessions.compactMap(\.startPercentage).reduce(0, +) / Double(validCount)) : nil
        let avgEnd: Double? = validCount > 0 ? (validPctSessions.compactMap(\.endPercentage).reduce(0, +) / Double(validCount)) : nil
        let avgDelta: Double? = (avgStart != nil && avgEnd != nil) ? (avgEnd! - avgStart!) : nil

        let endAt100Pct = validCount > 0 ? (Double(endAt100Count) / Double(validCount)) : 0.0
        let endAbove85Pct = validCount > 0 ? (Double(endAbove85Count) / Double(validCount)) : 0.0
        let startBelow15Pct = validCount > 0 ? (Double(startBelow15Count) / Double(validCount)) : 0.0
        let startBelow10Pct = validCount > 0 ? (Double(startBelow10Count) / Double(validCount)) : 0.0

        var daysSinceFull: Int? = nil
        if let lastFull = lastFullChargeDate {
            let diff = referenceDate.timeIntervalSince(lastFull)
            daysSinceFull = max(0, Int(diff / 86400.0))
        }

        return ChargingHabitMetrics(
            totalSessions: sessions.count,
            acSessionsCount: acSessions,
            dcSessionsCount: dcSessions,
            acEnergyKWh: acEnergy,
            dcEnergyKWh: dcEnergy,
            acEnergyRatio: acRatio,
            dcEnergyRatio: dcRatio,
            sessionsWithPercentagesCount: validCount,
            averageStartSoC: avgStart,
            averageEndSoC: avgEnd,
            averageDeltaSoC: avgDelta,
            sessionsEndingAt100Count: endAt100Count,
            sessionsEndingAt100Percentage: endAt100Pct,
            sessionsEndingAbove85Count: endAbove85Count,
            sessionsEndingAbove85Percentage: endAbove85Pct,
            sessionsStartingBelow15Count: startBelow15Count,
            sessionsStartingBelow15Percentage: startBelow15Pct,
            sessionsStartingBelow10Count: startBelow10Count,
            sessionsStartingBelow10Percentage: startBelow10Pct,
            daysSinceLastFullCharge: daysSinceFull,
            lastFullChargeDate: lastFullChargeDate
        )
    }

    // MARK: - Scoring Dimensions

    private static func computeSpeedScore(metrics: ChargingHabitMetrics) -> Double {
        guard metrics.totalSessions > 0 else { return 100.0 }
        
        let acRatio = metrics.acEnergyRatio
        if acRatio >= 0.80 {
            return 100.0
        } else if acRatio >= 0.60 {
            return 85.0 + ((acRatio - 0.60) / 0.20) * 15.0 // 85 to 100
        } else if acRatio >= 0.40 {
            return 65.0 + ((acRatio - 0.40) / 0.20) * 20.0 // 65 to 85
        } else if acRatio >= 0.20 {
            return 45.0 + ((acRatio - 0.20) / 0.20) * 20.0 // 45 to 65
        } else {
            return max(20.0, acRatio * 225.0)
        }
    }

    private static func computeTargetSoCScore(metrics: ChargingHabitMetrics, chemistry: BatteryChemistry) -> Double {
        guard metrics.sessionsWithPercentagesCount > 0 else { return 95.0 }

        switch chemistry {
        case .lfp:
            // LFP needs periodic 100% calibration for BMS cell balancing.
            if let days = metrics.daysSinceLastFullCharge {
                if days <= 14 {
                    return 100.0
                } else if days <= 28 {
                    return 90.0 - (Double(days - 14) / 14.0) * 15.0 // 75 to 90
                } else if days <= 60 {
                    return 60.0 - (Double(days - 28) / 32.0) * 20.0 // 40 to 60
                } else {
                    return 35.0
                }
            } else {
                // No full charge logged yet
                if metrics.sessionsEndingAt100Percentage >= 0.20 {
                    return 100.0
                } else if metrics.sessionsEndingAt100Percentage > 0 {
                    return 80.0
                } else {
                    return 50.0 // Needs a 100% charge for calibration
                }
            }

        case .nmc, .nca:
            // NMC / NCA: Holding at 100% creates high cathode voltage stress.
            // Ideally <= 15% of charges reach 100% (saved for road trips).
            let fullPct = metrics.sessionsEndingAt100Percentage
            if fullPct <= 0.15 {
                return 100.0
            } else if fullPct <= 0.35 {
                return 85.0 - ((fullPct - 0.15) / 0.20) * 15.0 // 70 to 85
            } else if fullPct <= 0.60 {
                return 70.0 - ((fullPct - 0.35) / 0.25) * 25.0 // 45 to 70
            } else {
                return max(20.0, 45.0 - ((fullPct - 0.60) / 0.40) * 25.0)
            }

        case .other:
            return 85.0
        }
    }

    private static func computeDischargeBufferScore(metrics: ChargingHabitMetrics) -> Double {
        guard metrics.sessionsWithPercentagesCount > 0 else { return 100.0 }

        let below10Pct = metrics.sessionsStartingBelow10Percentage
        let below15Pct = metrics.sessionsStartingBelow15Percentage

        var penalty = 0.0
        // Heavy penalty for dropping below 10% (copper dissolution & cell strain)
        penalty += below10Pct * 60.0
        // Moderate penalty for dropping below 15%
        penalty += (below15Pct - below10Pct) * 30.0

        return max(20.0, 100.0 - penalty)
    }

    private static func computeCycleConsistencyScore(metrics: ChargingHabitMetrics) -> Double {
        guard let avgDelta = metrics.averageDeltaSoC else { return 90.0 }

        // Moderate depth of discharge (ΔSoC between 25% and 65%) is ideal for Li-ion cycle life
        if avgDelta >= 25.0 && avgDelta <= 65.0 {
            return 100.0
        } else if avgDelta > 65.0 && avgDelta <= 80.0 {
            return 90.0 - ((avgDelta - 65.0) / 15.0) * 15.0 // 75 to 90
        } else if avgDelta > 80.0 {
            return max(50.0, 75.0 - ((avgDelta - 80.0) / 20.0) * 25.0) // Deep full cycles
        } else {
            // Very shallow charges (< 25% delta)
            return 92.0
        }
    }

    private static func determineAssessment(score: Double, grade: ChargingBehaviorGrade) -> ChargingLongevityAssessment {
        switch grade {
        case .aPlus:
            return .optimal
        case .a, .b:
            return .good
        case .c:
            return .moderateWear
        case .d:
            return .highWear
        }
    }

    // MARK: - Actionable Recommendations Generator

    private static func generateRecommendations(
        metrics: ChargingHabitMetrics,
        vehicle: Vehicle,
        referenceDate: Date
    ) -> [ChargingRecommendation] {
        guard metrics.totalSessions > 0 else {
            return [
                ChargingRecommendation(
                    category: .generalCare,
                    level: .tip,
                    title: "Start Logging Sessions",
                    summary: "Log your AC and DC charging sessions with start and end battery percentages to unlock detailed battery health insights.",
                    impactDescription: "Real-world charging habits directly dictate long-term capacity retention and resale value.",
                    actionableAdvice: "Enter charging sessions whenever you top up.",
                    observedMetricFormatted: "0 sessions"
                )
            ]
        }

        var list: [ChargingRecommendation] = []

        // 1. AC vs. DC Speed Recommendations
        if metrics.acEnergyRatio >= 0.75 {
            list.append(ChargingRecommendation(
                category: .chargingSpeed,
                level: .positive,
                title: "Excellent AC / DC Ratio",
                summary: "You primarily use gentle AC slow charging, keeping cell temperatures low and protecting the Solid Electrolyte Interphase (SEI) layer.",
                impactDescription: "Minimizes internal thermal stress and reduces lithium dendrite plating risk.",
                actionableAdvice: "Continue using AC home/work chargers for regular daily commutes.",
                observedMetricFormatted: String(format: "%.0f%% AC / %.0f%% DC", metrics.acEnergyRatio * 100, metrics.dcEnergyRatio * 100)
            ))
        } else if metrics.dcEnergyRatio >= 0.45 {
            list.append(ChargingRecommendation(
                category: .chargingSpeed,
                level: .caution,
                title: "High DC Fast Charging Frequency",
                summary: "A significant portion of your energy comes from high-power DC fast charging.",
                impactDescription: "Frequent rapid charging accelerates heat buildup and cyclic degradation in lithium cells.",
                actionableAdvice: "Prioritize AC slow charging at home or destination chargers whenever feasible, reserving DC fast charging for long-distance trips.",
                observedMetricFormatted: String(format: "%.0f%% DC Fast Charge", metrics.dcEnergyRatio * 100)
            ))
        } else {
            list.append(ChargingRecommendation(
                category: .chargingSpeed,
                level: .tip,
                title: "Balanced Charging Speeds",
                summary: "Good mix of AC daily charging and occasional DC road trip fast charging.",
                impactDescription: "Provides convenient road-trip speed while maintaining solid pack longevity.",
                actionableAdvice: "Maintain current balance by keeping DC rapid charges below 30% of lifetime energy.",
                observedMetricFormatted: String(format: "%.0f%% AC / %.0f%% DC", metrics.acEnergyRatio * 100, metrics.dcEnergyRatio * 100)
            ))
        }

        // 2. Target SoC & Chemistry-Specific Recommendations
        switch vehicle.chemistry {
        case .lfp:
            if let days = metrics.daysSinceLastFullCharge {
                if days <= 14 {
                    list.append(ChargingRecommendation(
                        category: .bmsCalibration,
                        level: .positive,
                        title: "BMS Well Calibrated (100% LFP Routine)",
                        summary: "You regularly charge your LFP battery to 100%, enabling the Battery Management System to balance cell voltages.",
                        impactDescription: "LFP has a flat voltage curve; 100% calibration prevents State of Charge estimation drift and ensures full usable range.",
                        actionableAdvice: "Keep charging to 100% every 1–2 weeks.",
                        observedMetricFormatted: "Last 100%: \(days) \(days == 1 ? "day" : "days") ago"
                    ))
                } else if days > 28 {
                    list.append(ChargingRecommendation(
                        category: .bmsCalibration,
                        level: .caution,
                        title: "100% LFP Top-Off Recommended",
                        summary: "It has been over \(days) days since your last 100% charge.",
                        impactDescription: "Without periodic 100% calibration, LFP cell voltages can drift apart and cause inaccurate remaining range readings.",
                        actionableAdvice: "Plug into an AC charger and charge to 100% soon to let the BMS balance cells.",
                        observedMetricFormatted: "Last 100%: \(days) days ago"
                    ))
                } else {
                    list.append(ChargingRecommendation(
                        category: .bmsCalibration,
                        level: .tip,
                        title: "Schedule Periodic 100% Charge",
                        summary: "Your LFP pack was last charged to 100% \(days) days ago.",
                        impactDescription: "LFP chemistry benefits from a 100% top-off every 1 to 2 weeks for optimal cell balancing.",
                        actionableAdvice: "Plan a 100% AC top-off in the coming week.",
                        observedMetricFormatted: "Last 100%: \(days) days ago"
                    ))
                }
            } else if metrics.sessionsEndingAt100Count > 0 {
                list.append(ChargingRecommendation(
                    category: .bmsCalibration,
                    level: .positive,
                    title: "Regular 100% LFP Calibration",
                    summary: "You regularly charge to 100%, keeping your LFP battery cells balanced.",
                    impactDescription: "Prevents BMS drift and maintains accurate range prediction.",
                    actionableAdvice: "Continue regular 100% charges on your LFP pack.",
                    observedMetricFormatted: String(format: "%.0f%% sessions reached 100%%", metrics.sessionsEndingAt100Percentage * 100)
                ))
            } else {
                list.append(ChargingRecommendation(
                    category: .bmsCalibration,
                    level: .caution,
                    title: "Calibrate LFP Battery to 100%",
                    summary: "None of your logged sessions reached 100% SoC.",
                    impactDescription: "LFP chemistry requires periodic 100% top-offs so the BMS can balance cells and accurately estimate capacity.",
                    actionableAdvice: "Perform an AC slow charge to 100% at least once every 1–2 weeks.",
                    observedMetricFormatted: "0% charges reached 100%"
                ))
            }

        case .nmc, .nca:
            if metrics.sessionsEndingAt100Percentage > 0.40 {
                list.append(ChargingRecommendation(
                    category: .targetSoC,
                    level: .caution,
                    title: "Lower Daily Limit to 80%–90%",
                    summary: String(format: "%.0f%% of your charging sessions ended at 100%%.", metrics.sessionsEndingAt100Percentage * 100),
                    impactDescription: "Holding NMC/NCA chemistry at 100% increases cathode voltage stress and accelerates capacity fade.",
                    actionableAdvice: "Set your vehicle charge limit to 80% (or 90%) for daily driving, reserving 100% only for long road trips.",
                    observedMetricFormatted: String(format: "%.0f%% ended at 100%%", metrics.sessionsEndingAt100Percentage * 100)
                ))
            } else {
                list.append(ChargingRecommendation(
                    category: .targetSoC,
                    level: .positive,
                    title: "Healthy Daily SoC Limit",
                    summary: "You avoid charging to 100% on everyday commutes, protecting your NMC/NCA battery from high-voltage stress.",
                    impactDescription: "Significantly extends cycle life and minimizes irreversible chemical degradation.",
                    actionableAdvice: "Continue keeping daily limits between 80% and 90%.",
                    observedMetricFormatted: String(format: "Only %.0f%% reached 100%%", metrics.sessionsEndingAt100Percentage * 100)
                ))
            }

        case .other:
            break
        }

        // 3. Discharge Buffer Recommendations
        if metrics.sessionsStartingBelow10Percentage > 0.15 {
            list.append(ChargingRecommendation(
                category: .deepDischarge,
                level: .caution,
                title: "Avoid Deep Discharges Below 10%",
                summary: String(format: "%.0f%% of charges started below 10%% SoC.", metrics.sessionsStartingBelow10Percentage * 100),
                impactDescription: "Deep discharges below 10% increase internal resistance and risk copper dissolution at the anode.",
                actionableAdvice: "Aim to plug in before dropping below 15%–20% State of Charge.",
                observedMetricFormatted: String(format: "%.0f%% started < 10%%", metrics.sessionsStartingBelow10Percentage * 100)
            ))
        } else if metrics.sessionsStartingBelow15Percentage > 0.25 {
            list.append(ChargingRecommendation(
                category: .deepDischarge,
                level: .tip,
                title: "Plug In Earlier for Better Buffer",
                summary: "Several charges started below 15% State of Charge.",
                impactDescription: "Keeping a 15%–20% floor reduces cell stress and leaves emergency range reserve.",
                actionableAdvice: "Top up when reaching ~20% during normal commuting routines.",
                observedMetricFormatted: String(format: "%.0f%% started < 15%%", metrics.sessionsStartingBelow15Percentage * 100)
            ))
        } else {
            list.append(ChargingRecommendation(
                category: .deepDischarge,
                level: .positive,
                title: "Healthy Lower SoC Buffer",
                summary: "You consistently recharge before your battery drops into deep discharge territory.",
                impactDescription: "Protects negative electrode current collectors and avoids high-resistance low voltage operation.",
                actionableAdvice: "Continue maintaining a 15%+ discharge cushion.",
                observedMetricFormatted: metrics.averageStartSoC != nil ? String(format: "Avg start: %.0f%% SoC", metrics.averageStartSoC!) : "Well protected"
            ))
        }

        return list.sorted(by: { $0.level > $1.level })
    }

    // MARK: - Summary Text Synthesis

    private static func generateSummaryText(
        score: Double,
        grade: ChargingBehaviorGrade,
        metrics: ChargingHabitMetrics,
        vehicle: Vehicle,
        recommendations: [ChargingRecommendation]
    ) -> String {
        guard metrics.totalSessions > 0 else {
            return "Log charging sessions to analyze your charging habits and receive personalized battery longevity recommendations."
        }

        var parts: [String] = []

        if score >= 90.0 {
            parts.append("Your charging behavior is exceptionally gentle on your \(vehicle.name)'s \(vehicle.chemistry.rawValue) battery pack.")
        } else if score >= 75.0 {
            parts.append("Your charging habits are generally healthy with solid battery preservation.")
        } else if score >= 55.0 {
            parts.append("Your charging routine causes moderate thermal or voltage stress on your battery pack.")
        } else {
            parts.append("Frequent high-stress charging patterns detected that may accelerate battery degradation.")
        }

        // Chemistry specific context
        if vehicle.chemistry == .lfp {
            if let days = metrics.daysSinceLastFullCharge, days > 28 {
                parts.append("Your LFP battery is overdue for a 100% AC calibration charge to balance cell voltages.")
            } else {
                parts.append("Regular AC charging and periodic 100% calibration will keep your LFP cells balanced.")
            }
        } else if vehicle.chemistry == .nmc || vehicle.chemistry == .nca {
            if metrics.sessionsEndingAt100Percentage > 0.35 {
                parts.append("Setting an 80%–90% daily charge limit will significantly reduce high-voltage cathode stress.")
            } else {
                parts.append("Maintaining an 80% daily charge ceiling keeps your NMC/NCA cells in the optimal longevity window.")
            }
        }

        return parts.joined(separator: " ")
    }
}
