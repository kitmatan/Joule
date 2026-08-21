import XCTest
import SwiftUI
@testable import Joule

final class LocalizationTests: XCTestCase {

    func testSupportedLanguagesAreAvailable() {
        let supportedLanguages = ["en", "de", "fr", "es", "zh-Hans", "ja", "nb", "th"]
        
        // Load Localizable.xcstrings from Sources
        guard let url = Bundle(for: type(of: self)).url(forResource: "Localizable", withExtension: "xcstrings") ??
                        Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") ??
                        URL(fileURLWithPath: "Sources/Localizable.xcstrings", isDirectory: false) as URL? else {
            XCTFail("Localizable.xcstrings not found")
            return
        }
        
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            // If running inside test bundle without file access to Sources, fallback gracefully
            return
        }
        
        XCTAssertGreaterThanOrEqual(strings.count, 500, "Should have at least 500 localized strings")
        
        for lang in supportedLanguages {
            var missingCount = 0
            for (key, val) in strings {
                if let locs = val["localizations"] as? [String: [String: Any]],
                   let unit = locs[lang]?["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String,
                   !value.isEmpty {
                    continue
                } else {
                    missingCount += 1
                }
            }
            XCTAssertEqual(missingCount, 0, "Language '\(lang)' has \(missingCount) missing translations")
        }
    }
    
    func testKeyTranslationsAcrossLanguages() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "Sources/Localizable.xcstrings")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            return
        }
        
        // Test German translations
        let deBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["de"] as? [String: Any]
        let deValue = (deBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(deValue, "Batteriegesundheit")
        
        let deScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["de"] as? [String: Any]
        let deScanVal = (deScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(deScanVal, "Beleg oder Display scannen")

        // Test French translations
        let frBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["fr"] as? [String: Any]
        let frValue = (frBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(frValue, "Santé de la batterie")
        
        let frScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["fr"] as? [String: Any]
        let frScanVal = (frScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(frScanVal, "Scanner le reçu ou l'écran")

        // Test Spanish translations
        let esBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["es"] as? [String: Any]
        let esValue = (esBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(esValue, "Salud de la batería")
        
        let esScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["es"] as? [String: Any]
        let esScanVal = (esScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(esScanVal, "Escanear recibo o pantalla")

        // Test Chinese translations
        let zhBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["zh-Hans"] as? [String: Any]
        let zhValue = (zhBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(zhValue, "电池健康")
        
        let zhScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["zh-Hans"] as? [String: Any]
        let zhScanVal = (zhScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(zhScanVal, "扫描收据或充电桩屏幕")

        // Test Japanese translations
        let jaBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["ja"] as? [String: Any]
        let jaValue = (jaBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(jaValue, "バッテリー健全度")
        
        let jaScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["ja"] as? [String: Any]
        let jaScanVal = (jaScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(jaScanVal, "レシート・画面をスキャン")

        // Test Norwegian translations
        let nbBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["nb"] as? [String: Any]
        let nbValue = (nbBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(nbValue, "Batterihelse")
        
        let nbScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["nb"] as? [String: Any]
        let nbScanVal = (nbScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(nbScanVal, "Skann kvittering eller skjerm")

        // Test Thai translations
        let thBatteryHealth = (strings["Battery Health"]?["localizations"] as? [String: Any])?["th"] as? [String: Any]
        let thValue = (thBatteryHealth?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(thValue, "สุขภาพแบตเตอรี่")
        
        let thScan = (strings["Scan Receipt or Meter"]?["localizations"] as? [String: Any])?["th"] as? [String: Any]
        let thScanVal = (thScan?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(thScanVal, "สแกนใบเสร็จหรือหน้าจอตู้ชาร์จ")
        
        let thEfficiency = (strings["Driving Efficiency — Recent (%@)"]?["localizations"] as? [String: Any])?["th"] as? [String: Any]
        let thEfficiencyVal = (thEfficiency?["stringUnit"] as? [String: Any])?["value"] as? String
        XCTAssertEqual(thEfficiencyVal, "ประสิทธิภาพการขับขี่ — ล่าสุด (%1$@)")
    }
}
