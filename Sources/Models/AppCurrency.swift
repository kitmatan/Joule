import Foundation

/// Supported currencies in Joule with localized formatting support.
enum AppCurrency: String, CaseIterable, Identifiable, Codable {
    case thb = "THB"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case cny = "CNY"
    case krw = "KRW"
    case sgd = "SGD"
    case chf = "CHF"
    case sek = "SEK"
    case nok = "NOK"
    case inr = "INR"
    
    var id: String { rawValue }
    var code: String { rawValue }
    
    /// Currency symbol representation.
    var symbol: String {
        switch self {
        case .thb: return "฿"
        case .usd, .cad, .aud, .sgd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy, .cny: return "¥"
        case .krw: return "₩"
        case .chf: return "CHF"
        case .sek, .nok: return "kr"
        case .inr: return "₹"
        }
    }
    
    /// Display name shown in Pickers and Settings.
    var displayName: String {
        switch self {
        case .thb: return "฿ THB — Thai Baht"
        case .usd: return "$ USD — US Dollar"
        case .eur: return "€ EUR — Euro"
        case .gbp: return "£ GBP — British Pound"
        case .jpy: return "¥ JPY — Japanese Yen"
        case .cad: return "$ CAD — Canadian Dollar"
        case .aud: return "$ AUD — Australian Dollar"
        case .cny: return "¥ CNY — Chinese Yuan"
        case .krw: return "₩ KRW — Korean Won"
        case .sgd: return "$ SGD — Singapore Dollar"
        case .chf: return "CHF — Swiss Franc"
        case .sek: return "kr SEK — Swedish Krona"
        case .nok: return "kr NOK — Norwegian Krone"
        case .inr: return "₹ INR — Indian Rupee"
        }
    }
    
    /// Recommended default decimal digits for currency amounts.
    var decimalDigits: Int {
        switch self {
        case .jpy, .krw: return 0
        default: return 2
        }
    }
    
    /// Formats a monetary total using standard system currency rules.
    func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: code).presentation(.narrow))
    }
    
    /// Formats a unit rate (e.g. "฿4.90/kWh", "$0.16/kWh", "€0.28/kWh").
    func formatRate(_ rate: Double, unit: String = "kWh") -> String {
        String(format: "%@%.2f/%@", symbol, rate, unit)
    }
    
    /// Formats a unit rate with spaces (e.g. "฿4.90 / kWh").
    func formatRateSpaced(_ rate: Double, unit: String = "kWh") -> String {
        String(format: "%@%.2f / %@", symbol, rate, unit)
    }
    
    /// Formats driving cost per distance unit (e.g. "฿0.75/km", "$0.04/mi").
    func formatCostPerDistance(cost: Double, distanceUnit: String) -> String {
        String(format: "%@%.2f/%@", symbol, cost, distanceUnit)
    }
    
    /// Rate input placeholder or suffix (e.g. "฿/kWh", "$/kWh").
    var rateUnitSuffix: String {
        "\(symbol)/kWh"
    }
    
    /// Lookup from raw string code with safe fallback.
    static func from(code: String) -> AppCurrency {
        AppCurrency(rawValue: code.uppercased()) ?? .thb
    }
}
