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
}
