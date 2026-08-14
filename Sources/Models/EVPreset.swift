import Foundation

/// Supported EV battery chemistries with chemistry-specific characteristics.
enum BatteryChemistry: String, CaseIterable, Identifiable, Codable {
    case lfp = "LFP"
    case nmc = "NMC"
    case nca = "NCA"
    case other = "Other"
    
    var id: String { rawValue }
    
    /// User-friendly name and description of the chemistry.
    var fullName: String {
        switch self {
        case .lfp:
            return "Lithium Iron Phosphate (LFP / Blade)"
        case .nmc:
            return "Nickel Manganese Cobalt (NMC / NCM)"
        case .nca:
            return "Nickel Cobalt Aluminum (NCA)"
        case .other:
            return "Other / Custom Chemistry"
        }
    }
    
    /// Short chemistry tag for chips and badges.
    var badgeTitle: String {
        switch self {
        case .lfp: return "LFP"
        case .nmc: return "NMC"
        case .nca: return "NCA"
        case .other: return "EV"
        }
    }
    
    /// Standard theoretical laboratory cycle life to 80% State of Health (SoH).
    var defaultCycleLife: Double {
        switch self {
        case .lfp:
            return 3000.0
        case .nmc, .nca:
            return 1500.0
        case .other:
            return 2000.0
        }
    }
    
    /// Recommended daily state-of-charge charge target.
    var recommendedDailyTarget: String {
        switch self {
        case .lfp:
            return "100% regular charge"
        case .nmc, .nca:
            return "80%–90% daily limit"
        case .other:
            return "Per manufacturer advice"
        }
    }
    
    /// Actionable cell longevity guidance for the user.
    var careAdvice: String {
        switch self {
        case .lfp:
            return "Lithium Iron Phosphate (LFP) chemistry offers superior cycle life and thermal stability. Charge to 100% regularly (at least every 1–2 weeks) so the Battery Management System (BMS) can balance individual cells and accurately calibrate the SoC estimator."
        case .nmc:
            return "Nickel Manganese Cobalt (NMC) chemistry provides high energy density. For daily driving, maintain a charge limit between 80% and 90% to avoid prolonged cathode voltage stress. Charge to 100% only prior to departure on long road trips."
        case .nca:
            return "Nickel Cobalt Aluminum (NCA) chemistry delivers high energy density and power output. Limit daily charging to 80%–90% to prolong cell health, reserving 100% top-offs for immediate road trip departures."
        case .other:
            return "Follow your vehicle manufacturer's recommendations for daily charging targets and periodic cell balancing."
        }
    }
}

/// Official testing standards for EV range ratings.
enum RangeStandard: String, CaseIterable, Identifiable, Codable {
    case wltp = "WLTP"
    case nedc = "NEDC"
    case cltc = "CLTC"
    case epa = "EPA"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var fullName: String {
        switch self {
        case .wltp: return "WLTP (Worldwide Harmonized)"
        case .nedc: return "NEDC (New European Cycle)"
        case .cltc: return "CLTC (China Light-Duty Cycle)"
        case .epa: return "EPA (US Environmental Protection)"
        case .custom: return "Custom Range Standard"
        }
    }
}

/// A structured vehicle preset model.
struct EVPreset: Identifiable, Hashable {
    let id: String
    let brand: String
    let model: String
    let trim: String
    let nominalCapacityKWh: Double
    let nominalRangeKm: Double
    let rangeStandard: RangeStandard
    let chemistry: BatteryChemistry
    let defaultWallChargerKW: Double
    let expectedCycleLife: Double
    
    var displayName: String {
        if trim.isEmpty {
            return "\(brand) \(model)"
        }
        return "\(brand) \(model) \(trim)"
    }
    
    init(
        id: String,
        brand: String,
        model: String,
        trim: String = "",
        nominalCapacityKWh: Double,
        nominalRangeKm: Double,
        rangeStandard: RangeStandard,
        chemistry: BatteryChemistry,
        defaultWallChargerKW: Double = 7.0,
        expectedCycleLife: Double? = nil
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.trim = trim
        self.nominalCapacityKWh = nominalCapacityKWh
        self.nominalRangeKm = nominalRangeKm
        self.rangeStandard = rangeStandard
        self.chemistry = chemistry
        self.defaultWallChargerKW = defaultWallChargerKW
        self.expectedCycleLife = expectedCycleLife ?? chemistry.defaultCycleLife
    }
}

/// Built-in database of popular EV specifications across manufacturers.
struct EVPresetCatalog {
    static let defaultPresetId = "gac_aion_v_602"
    
    static let allPresets: [EVPreset] = [
        // MARK: - GAC AION
        EVPreset(
            id: "gac_aion_v_602",
            brand: "GAC AION",
            model: "AION V",
            trim: "602 Luxury",
            nominalCapacityKWh: 75.3,
            nominalRangeKm: 602.0,
            rangeStandard: .cltc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "gac_aion_y_plus_490",
            brand: "GAC AION",
            model: "AION Y Plus",
            trim: "490 Elite / Premium",
            nominalCapacityKWh: 63.2,
            nominalRangeKm: 490.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "gac_aion_es_442",
            brand: "GAC AION",
            model: "AION ES",
            trim: "442",
            nominalCapacityKWh: 55.2,
            nominalRangeKm: 442.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 6.6,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "gac_aion_ut_420",
            brand: "GAC AION",
            model: "AION UT",
            trim: "420",
            nominalCapacityKWh: 44.1,
            nominalRangeKm: 420.0,
            rangeStandard: .cltc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "gac_hyper_ht_670",
            brand: "GAC AION",
            model: "Hyper HT",
            trim: "670 Premium",
            nominalCapacityKWh: 80.0,
            nominalRangeKm: 670.0,
            rangeStandard: .cltc,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),

        // MARK: - BYD
        EVPreset(
            id: "byd_atto_3_std",
            brand: "BYD",
            model: "Atto 3",
            trim: "Standard Range",
            nominalCapacityKWh: 49.92,
            nominalRangeKm: 410.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_atto_3_ext",
            brand: "BYD",
            model: "Atto 3",
            trim: "Extended Range",
            nominalCapacityKWh: 60.48,
            nominalRangeKm: 480.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_dolphin_std",
            brand: "BYD",
            model: "Dolphin",
            trim: "Standard Range",
            nominalCapacityKWh: 44.9,
            nominalRangeKm: 410.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_dolphin_ext",
            brand: "BYD",
            model: "Dolphin",
            trim: "Extended Range",
            nominalCapacityKWh: 60.48,
            nominalRangeKm: 490.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_seal_dynamic",
            brand: "BYD",
            model: "Seal",
            trim: "Dynamic RWD",
            nominalCapacityKWh: 61.44,
            nominalRangeKm: 510.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_seal_premium",
            brand: "BYD",
            model: "Seal",
            trim: "Premium / Performance",
            nominalCapacityKWh: 82.56,
            nominalRangeKm: 580.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_sealion_6",
            brand: "BYD",
            model: "Sealion 6",
            trim: "DM-i / EV",
            nominalCapacityKWh: 82.5,
            nominalRangeKm: 520.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "byd_sealion_7",
            brand: "BYD",
            model: "Sealion 7",
            trim: "AWD / RWD",
            nominalCapacityKWh: 82.56,
            nominalRangeKm: 542.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),

        // MARK: - Tesla
        EVPreset(
            id: "tesla_m3_rwd",
            brand: "Tesla",
            model: "Model 3",
            trim: "Rear-Wheel Drive (LFP)",
            nominalCapacityKWh: 60.0,
            nominalRangeKm: 513.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "tesla_m3_lr",
            brand: "Tesla",
            model: "Model 3",
            trim: "Long Range AWD",
            nominalCapacityKWh: 78.1,
            nominalRangeKm: 629.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "tesla_m3_perf",
            brand: "Tesla",
            model: "Model 3",
            trim: "Performance AWD",
            nominalCapacityKWh: 78.1,
            nominalRangeKm: 528.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "tesla_my_rwd",
            brand: "Tesla",
            model: "Model Y",
            trim: "Rear-Wheel Drive (LFP)",
            nominalCapacityKWh: 60.0,
            nominalRangeKm: 455.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "tesla_my_lr",
            brand: "Tesla",
            model: "Model Y",
            trim: "Long Range AWD",
            nominalCapacityKWh: 78.1,
            nominalRangeKm: 533.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "tesla_my_perf",
            brand: "Tesla",
            model: "Model Y",
            trim: "Performance AWD",
            nominalCapacityKWh: 78.1,
            nominalRangeKm: 514.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),

        // MARK: - MG
        EVPreset(
            id: "mg_4_std",
            brand: "MG",
            model: "MG4 Electric",
            trim: "Standard (51 kWh)",
            nominalCapacityKWh: 51.0,
            nominalRangeKm: 350.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 6.6,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "mg_4_lr",
            brand: "MG",
            model: "MG4 Electric",
            trim: "Long Range (64 kWh)",
            nominalCapacityKWh: 64.0,
            nominalRangeKm: 450.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "mg_4_xpower",
            brand: "MG",
            model: "MG4 Electric",
            trim: "XPOWER AWD",
            nominalCapacityKWh: 64.0,
            nominalRangeKm: 385.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "mg_zs_ev",
            brand: "MG",
            model: "ZS EV",
            trim: "50.3 kWh",
            nominalCapacityKWh: 50.3,
            nominalRangeKm: 320.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 6.6,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "mg_maxus_7",
            brand: "MG",
            model: "Maxus 7",
            trim: "Luxury MPV",
            nominalCapacityKWh: 90.0,
            nominalRangeKm: 540.0,
            rangeStandard: .nedc,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),

        // MARK: - Hyundai & Kia
        EVPreset(
            id: "hyundai_ioniq5_std",
            brand: "Hyundai",
            model: "Ioniq 5",
            trim: "Standard Range (58 kWh)",
            nominalCapacityKWh: 58.0,
            nominalRangeKm: 384.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "hyundai_ioniq5_lr",
            brand: "Hyundai",
            model: "Ioniq 5",
            trim: "Long Range (77.4 kWh)",
            nominalCapacityKWh: 77.4,
            nominalRangeKm: 507.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "hyundai_ioniq6_lr",
            brand: "Hyundai",
            model: "Ioniq 6",
            trim: "Long Range (77.4 kWh)",
            nominalCapacityKWh: 77.4,
            nominalRangeKm: 614.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "kia_ev6_lr",
            brand: "Kia",
            model: "EV6",
            trim: "Long Range (77.4 kWh)",
            nominalCapacityKWh: 77.4,
            nominalRangeKm: 528.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "kia_ev5_std",
            brand: "Kia",
            model: "EV5",
            trim: "Standard (64.2 kWh)",
            nominalCapacityKWh: 64.2,
            nominalRangeKm: 490.0,
            rangeStandard: .cltc,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "kia_ev5_lr",
            brand: "Kia",
            model: "EV5",
            trim: "Long Range (88.1 kWh)",
            nominalCapacityKWh: 88.1,
            nominalRangeKm: 720.0,
            rangeStandard: .cltc,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),

        // MARK: - Deepal & Changan
        EVPreset(
            id: "deepal_s07_std",
            brand: "Deepal",
            model: "S07",
            trim: "Standard (66.8 kWh)",
            nominalCapacityKWh: 66.8,
            nominalRangeKm: 485.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "deepal_s07_lr",
            brand: "Deepal",
            model: "S07",
            trim: "Long Range (79.97 kWh)",
            nominalCapacityKWh: 79.97,
            nominalRangeKm: 560.0,
            rangeStandard: .nedc,
            chemistry: .nmc,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "deepal_l07",
            brand: "Deepal",
            model: "L07",
            trim: "66.8 kWh",
            nominalCapacityKWh: 66.8,
            nominalRangeKm: 475.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 7.0,
            expectedCycleLife: 3000.0
        ),

        // MARK: - Volvo & Polestar
        EVPreset(
            id: "volvo_ex30_single",
            brand: "Volvo",
            model: "EX30",
            trim: "Single Motor (51 kWh)",
            nominalCapacityKWh: 51.0,
            nominalRangeKm: 344.0,
            rangeStandard: .wltp,
            chemistry: .lfp,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "volvo_ex30_twin",
            brand: "Volvo",
            model: "EX30",
            trim: "Twin Motor / Ultra (69 kWh)",
            nominalCapacityKWh: 69.0,
            nominalRangeKm: 476.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "volvo_ex40_recharge",
            brand: "Volvo",
            model: "EX40",
            trim: "Recharge (82 kWh)",
            nominalCapacityKWh: 82.0,
            nominalRangeKm: 570.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "polestar_2_lr",
            brand: "Polestar",
            model: "Polestar 2",
            trim: "Long Range Single Motor",
            nominalCapacityKWh: 82.0,
            nominalRangeKm: 654.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),

        // MARK: - ORA / GWM
        EVPreset(
            id: "ora_good_cat_400",
            brand: "ORA",
            model: "Good Cat",
            trim: "400 PRO",
            nominalCapacityKWh: 47.8,
            nominalRangeKm: 400.0,
            rangeStandard: .nedc,
            chemistry: .lfp,
            defaultWallChargerKW: 6.6,
            expectedCycleLife: 3000.0
        ),
        EVPreset(
            id: "ora_good_cat_500",
            brand: "ORA",
            model: "Good Cat",
            trim: "500 ULTRA",
            nominalCapacityKWh: 63.1,
            nominalRangeKm: 500.0,
            rangeStandard: .nedc,
            chemistry: .nmc,
            defaultWallChargerKW: 6.6,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "ora_07_lr",
            brand: "ORA",
            model: "07 (Grand Cat)",
            trim: "Long Range (83.5 kWh)",
            nominalCapacityKWh: 83.5,
            nominalRangeKm: 640.0,
            rangeStandard: .nedc,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),

        // MARK: - BMW
        EVPreset(
            id: "bmw_i4_edrive40",
            brand: "BMW",
            model: "i4",
            trim: "eDrive40 (83.9 kWh)",
            nominalCapacityKWh: 83.9,
            nominalRangeKm: 590.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "bmw_ix3",
            brand: "BMW",
            model: "iX3",
            trim: "M Sport (80 kWh)",
            nominalCapacityKWh: 80.0,
            nominalRangeKm: 460.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        ),
        EVPreset(
            id: "bmw_ix1_xdrive30",
            brand: "BMW",
            model: "iX1",
            trim: "xDrive30 (66.5 kWh)",
            nominalCapacityKWh: 66.5,
            nominalRangeKm: 440.0,
            rangeStandard: .wltp,
            chemistry: .nmc,
            defaultWallChargerKW: 11.0,
            expectedCycleLife: 1500.0
        )
    ]
    
    /// Ordered list of unique automotive brands available in the preset catalog.
    static var brands: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for preset in allPresets {
            if !seen.contains(preset.brand) {
                seen.insert(preset.brand)
                result.append(preset.brand)
            }
        }
        return result
    }
    
    /// Presets belonging to a specific brand.
    static func presets(forBrand brand: String) -> [EVPreset] {
        allPresets.filter { $0.brand == brand }
    }
    
    /// Look up preset by ID.
    static func preset(forId id: String) -> EVPreset? {
        allPresets.first { $0.id == id }
    }
    
    /// Default preset (GAC AION V 602).
    static var defaultPreset: EVPreset {
        preset(forId: defaultPresetId) ?? allPresets[0]
    }
}
