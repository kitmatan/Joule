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
}
