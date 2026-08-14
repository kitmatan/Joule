import Foundation
import FirebaseFirestore

enum ChargingType: String, Codable, CaseIterable, Identifiable {
    case ac = "AC"
    case dc = "DC"
    
    var id: String { rawValue }
}

enum LocationType: String, Codable, CaseIterable, Identifiable {
    case publicStation = "Public Station"
    case home = "Home"
    case work = "Work"
    
    var id: String { rawValue }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case paidUpfront = "Paid Upfront"
    case deferred = "Deferred to Bill"
    case free = "Free"
    
    var id: String { rawValue }
}

struct ChargingSession: Identifiable, Codable {
    @DocumentID var id: String?
    var locationName: String?
    var vendorName: String?
    var date: Date
    var duration: Double // in seconds
    var energyAdded: Double
    var speed: Double
    var chargingFee: Double
    var bookingFee: Double
    var overtimeFee: Double
    var pricePerUnit: Double
    var totalPrice: Double
    var mileage: Double?
    var startPercentage: Double?
    var endPercentage: Double?
    var startRange: Double?
    var endRange: Double?
    var chargingType: ChargingType?
    var locationType: LocationType?
    var paymentStatus: PaymentStatus?
    var notes: String?
    
    init(
        id: String? = nil,
        locationName: String? = nil,
        vendorName: String? = nil,
        date: Date = Date(),
        duration: Double = 0,
        energyAdded: Double = 0,
        speed: Double = 0,
        chargingFee: Double = 0,
        bookingFee: Double = 0,
        overtimeFee: Double = 0,
        pricePerUnit: Double = 0,
        totalPrice: Double = 0,
        mileage: Double? = nil,
        startPercentage: Double? = nil,
        endPercentage: Double? = nil,
        startRange: Double? = nil,
        endRange: Double? = nil,
        chargingType: ChargingType? = nil,
        locationType: LocationType? = nil,
        paymentStatus: PaymentStatus? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.locationName = locationName
        self.vendorName = vendorName
        self.date = date
        self.duration = duration
        self.energyAdded = energyAdded
        self.speed = speed
        self.chargingFee = chargingFee
        self.bookingFee = bookingFee
        self.overtimeFee = overtimeFee
        self.pricePerUnit = pricePerUnit
        self.totalPrice = totalPrice
        self.mileage = mileage
        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
        self.startRange = startRange
        self.endRange = endRange
        self.chargingType = chargingType
        self.locationType = locationType
        self.paymentStatus = paymentStatus
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case locationName
        case vendorName
        case date
        case duration
        case energyAdded
        case speed
        case chargingFee
        case bookingFee
        case overtimeFee
        case pricePerUnit
        case totalPrice
        case mileage
        case startPercentage
        case endPercentage
        case startRange
        case endRange
        case chargingType
        case locationType
        case paymentStatus
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        self.vendorName = try container.decodeIfPresent(String.self, forKey: .vendorName)
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        self.energyAdded = try container.decodeIfPresent(Double.self, forKey: .energyAdded) ?? 0
        self.speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 0
        self.chargingFee = try container.decodeIfPresent(Double.self, forKey: .chargingFee) ?? 0
        self.bookingFee = try container.decodeIfPresent(Double.self, forKey: .bookingFee) ?? 0
        self.overtimeFee = try container.decodeIfPresent(Double.self, forKey: .overtimeFee) ?? 0
        self.pricePerUnit = try container.decodeIfPresent(Double.self, forKey: .pricePerUnit) ?? 0
        self.totalPrice = try container.decodeIfPresent(Double.self, forKey: .totalPrice) ?? 0
        self.mileage = try container.decodeIfPresent(Double.self, forKey: .mileage)
        self.startPercentage = try container.decodeIfPresent(Double.self, forKey: .startPercentage)
        self.endPercentage = try container.decodeIfPresent(Double.self, forKey: .endPercentage)
        self.startRange = try container.decodeIfPresent(Double.self, forKey: .startRange)
        self.endRange = try container.decodeIfPresent(Double.self, forKey: .endRange)
        self.chargingType = try container.decodeIfPresent(ChargingType.self, forKey: .chargingType)
        self.locationType = try container.decodeIfPresent(LocationType.self, forKey: .locationType)
        self.paymentStatus = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encodeIfPresent(vendorName, forKey: .vendorName)
        try container.encode(date, forKey: .date)
        try container.encode(duration, forKey: .duration)
        try container.encode(energyAdded, forKey: .energyAdded)
        try container.encode(speed, forKey: .speed)
        try container.encode(chargingFee, forKey: .chargingFee)
        try container.encode(bookingFee, forKey: .bookingFee)
        try container.encode(overtimeFee, forKey: .overtimeFee)
        try container.encode(pricePerUnit, forKey: .pricePerUnit)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encodeIfPresent(mileage, forKey: .mileage)
        try container.encodeIfPresent(startPercentage, forKey: .startPercentage)
        try container.encodeIfPresent(endPercentage, forKey: .endPercentage)
        try container.encodeIfPresent(startRange, forKey: .startRange)
        try container.encodeIfPresent(endRange, forKey: .endRange)
        try container.encodeIfPresent(chargingType, forKey: .chargingType)
        try container.encodeIfPresent(locationType, forKey: .locationType)
        try container.encodeIfPresent(paymentStatus, forKey: .paymentStatus)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    // MARK: - Duplicate Detection & Merging

    /// Returns true if this session represents the same physical charging event as `other`.
    func isDuplicate(of other: ChargingSession, timeToleranceSeconds: TimeInterval = 300) -> Bool {
        // 1. Explicit ID match (if both non-empty)
        if let id1 = self.id, let id2 = other.id, !id1.isEmpty, !id2.isEmpty, id1 == id2 {
            return true
        }

        // 2. Timestamp proximity check (default within 5 minutes)
        let timeDiff = abs(self.date.timeIntervalSince(other.date))
        guard timeDiff <= timeToleranceSeconds else { return false }

        // 3. Location match:
        // - Both are home charging
        // - Both have matching non-empty location names (case-insensitive)
        // - Or both have matching location types
        let isBothHome = (self.locationType == .home || self.locationName?.lowercased().contains("home") == true) &&
                         (other.locationType == .home || other.locationName?.lowercased().contains("home") == true)

        let locName1 = self.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let locName2 = other.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let isSameLocName = !locName1.isEmpty && !locName2.isEmpty && locName1 == locName2

        let isSameLocType = self.locationType != nil && self.locationType == other.locationType

        guard isBothHome || isSameLocName || isSameLocType || (locName1.isEmpty && locName2.isEmpty) else {
            return false
        }

        // 4. Energy added matching (within 0.15 kWh tolerance)
        let energyDiff = abs(self.energyAdded - other.energyAdded)
        if energyDiff <= 0.15 {
            return true
        }

        // 5. SoC delta matching if energy numbers differ slightly (e.g. meter rounding differences)
        if let s1 = self.startPercentage, let s2 = other.startPercentage,
           let e1 = self.endPercentage, let e2 = other.endPercentage,
           abs(s1 - s2) <= 1.0, abs(e1 - e2) <= 1.0 {
            return true
        }

        // 6. If duration is non-trivial and matches closely (within 3 minutes)
        if self.duration > 0 && other.duration > 0 && abs(self.duration - other.duration) <= 180 && energyDiff <= 0.5 {
            return true
        }

        return false
    }

    /// Merges details from another duplicate session into this one, preserving the richest data.
    func merged(with other: ChargingSession) -> ChargingSession {
        var result = self

        // Prefer non-empty ID (prefer Firestore-style document IDs over local UUIDs if possible)
        if result.id == nil || result.id?.isEmpty == true {
            result.id = other.id
        }

        // Location & Vendor
        if (result.locationName == nil || result.locationName?.isEmpty == true) && other.locationName != nil {
            result.locationName = other.locationName
        }
        if (result.vendorName == nil || result.vendorName?.isEmpty == true) && other.vendorName != nil {
            result.vendorName = other.vendorName
        }

        // Numbers: Prefer non-zero values
        if result.energyAdded == 0 && other.energyAdded > 0 { result.energyAdded = other.energyAdded }
        if result.duration == 0 && other.duration > 0 { result.duration = other.duration }
        if result.speed == 0 && other.speed > 0 { result.speed = other.speed }
        if result.totalPrice == 0 && other.totalPrice > 0 { result.totalPrice = other.totalPrice }
        if result.chargingFee == 0 && other.chargingFee > 0 { result.chargingFee = other.chargingFee }
        if result.bookingFee == 0 && other.bookingFee > 0 { result.bookingFee = other.bookingFee }
        if result.overtimeFee == 0 && other.overtimeFee > 0 { result.overtimeFee = other.overtimeFee }
        if result.pricePerUnit == 0 && other.pricePerUnit > 0 { result.pricePerUnit = other.pricePerUnit }

        // Optional fields: Prefer existing values from other if nil in self
        if result.mileage == nil { result.mileage = other.mileage }
        if result.startPercentage == nil { result.startPercentage = other.startPercentage }
        if result.endPercentage == nil { result.endPercentage = other.endPercentage }
        if result.startRange == nil { result.startRange = other.startRange }
        if result.endRange == nil { result.endRange = other.endRange }
        if result.chargingType == nil { result.chargingType = other.chargingType }
        if result.locationType == nil { result.locationType = other.locationType }
        if result.paymentStatus == nil { result.paymentStatus = other.paymentStatus }

        // Notes: Combine or preserve longest notes
        if let n1 = result.notes, let n2 = other.notes, !n1.isEmpty, !n2.isEmpty {
            if !n1.contains(n2) && !n2.contains(n1) {
                result.notes = "\(n1)\n\(n2)"
            } else if n2.count > n1.count {
                result.notes = n2
            }
        } else if result.notes == nil || result.notes?.isEmpty == true {
            result.notes = other.notes
        }

        return result
    }
}

